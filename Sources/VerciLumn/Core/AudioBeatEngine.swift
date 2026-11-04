import Foundation
@preconcurrency import ScreenCaptureKit
import Accelerate
import Combine

public final class AudioBeatEngine: NSObject, ObservableObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    public static let shared = AudioBeatEngine()
    
    @Published public private(set) var beatIntensity: Float = 0.0
    @Published public private(set) var isCapturing: Bool = false
    
    public var onBeatPulse: ((Float) -> Void)?
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.vercilumn.audio.beat", qos: .userInteractive)
    private var simulatedTimer: AnyCancellable?
    
    private override init() {
        super.init()
    }
    
    public func startCapture() {
        guard !isCapturing else { return }
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    self.startSimulatedFallback()
                    return
                }
                
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.sampleRate = 44100
                config.channelCount = 2
                // Minimize video capture overhead since we only analyze audio
                config.width = 2
                config.height = 2
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.audioQueue)
                try await stream.startCapture()
                
                DispatchQueue.main.async {
                    self.stream = stream
                    self.isCapturing = true
                    self.simulatedTimer?.cancel()
                    self.simulatedTimer = nil
                }
            } catch {
                // If ScreenCaptureKit permission is not granted, gracefully run rhythmic beat simulation
                self.startSimulatedFallback()
            }
        }
    }
    
    public func stopCapture() {
        simulatedTimer?.cancel()
        simulatedTimer = nil
        
        if let stream = stream {
            stream.stopCapture { _ in }
            self.stream = nil
        }
        DispatchQueue.main.async {
            self.isCapturing = false
            self.beatIntensity = 0.0
        }
    }
    
    private func startSimulatedFallback() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCapturing = true
            var phase: Float = 0.0
            self.simulatedTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    phase += 0.06
                    let raw = (sin(phase) + sin(phase * 2.3) + 2.0) / 4.0
                    let pulse = max(0.0, (raw - 0.45) * 1.5)
                    self?.beatIntensity = pulse
                    self?.onBeatPulse?(pulse)
                }
        }
    }
    
    private var lastPublishTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 1.0 / 45.0 // 45 FPS max update rate to eliminate CPU burn

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastPublishTime >= throttleInterval else { return }
        lastPublishTime = now
        
        var length = 0
        var dataPtr: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPtr
        )
        guard status == kCMBlockBufferNoErr, let data = dataPtr, length > 0 else { return }
        
        let floatCount = length / MemoryLayout<Float>.size
        guard floatCount > 0 else { return }
        
        let samples = data.withMemoryRebound(to: Float.self, capacity: floatCount) {
            Array(UnsafeBufferPointer(start: $0, count: floatCount))
        }
        
        // Compute RMS of frame buffer using Accelerate vDSP
        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        
        // Scale, clamp and apply non-linear bass thresholding
        let pulse = min(max((rms - 0.03) * 5.0, 0.0), 1.0)
        
        // Pass samples to Multi-Band Spectrum Engine
        AudioSpectrumEngine.shared.processAudio(samples: samples)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.beatIntensity = pulse
            self.onBeatPulse?(pulse)
        }
    }
    
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        startSimulatedFallback()
    }
}
