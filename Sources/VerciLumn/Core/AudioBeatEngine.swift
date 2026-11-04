import Foundation
@preconcurrency import ScreenCaptureKit
import Accelerate
import CoreMedia
import Combine

public final class AudioBeatEngine: NSObject, ObservableObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    public static let shared = AudioBeatEngine()
    
    @Published public private(set) var beatIntensity: Float = 0.0
    @Published public private(set) var isCapturing: Bool = false
    @Published public private(set) var isHardwareCaptureActive: Bool = false
    
    public var onBeatPulse: ((Float) -> Void)?
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.vercilumn.audio.beat", qos: .userInteractive)
    private var simulatedTimer: AnyCancellable?
    
    private var lastPublishTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 1.0 / 45.0 // 45 FPS max update rate
    
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
                    self.isHardwareCaptureActive = true
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
            self.isHardwareCaptureActive = false
            self.beatIntensity = 0.0
        }
    }
    
    private func startSimulatedFallback() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCapturing = true
            self.isHardwareCaptureActive = false
            var phase: Float = 0.0
            self.simulatedTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    // Freeze updates when no track is playing to keep CPU at 0% and MacBook cool
                    guard PlaybackManager.shared.currentTrack.isPlaying else {
                        if self.beatIntensity > 0 {
                            self.beatIntensity = 0
                            self.onBeatPulse?(0)
                        }
                        return
                    }
                    phase += 0.06
                    let raw = (sin(phase) + sin(phase * 2.3) + 2.0) / 4.0
                    let pulse = max(0.0, (raw - 0.45) * 1.5)
                    self.beatIntensity = pulse
                    self.onBeatPulse?(pulse)
                }
        }
    }

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
        
        // Inspect format description to safely extract float vs int samples
        var samples: [Float] = []
        if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
            let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
            let bytesPerSample = Int(asbd.mBitsPerChannel / 8)
            
            if isFloat && bytesPerSample == MemoryLayout<Float>.size {
                let floatCount = length / MemoryLayout<Float>.size
                samples = data.withMemoryRebound(to: Float.self, capacity: floatCount) {
                    Array(UnsafeBufferPointer(start: $0, count: floatCount))
                }
            } else if !isFloat && bytesPerSample == 2 {
                // 16-bit signed integer PCM -> Float conversion
                let int16Count = length / 2
                let int16Samples = data.withMemoryRebound(to: Int16.self, capacity: int16Count) {
                    Array(UnsafeBufferPointer(start: $0, count: int16Count))
                }
                samples = [Float](repeating: 0, count: int16Count)
                var scale: Float = 1.0 / 32768.0
                vDSP_vflt16(int16Samples, 1, &samples, 1, vDSP_Length(int16Count))
                vDSP_vsmul(samples, 1, &scale, &samples, 1, vDSP_Length(int16Count))
            }
        }
        
        // Fallback if format description was missing
        if samples.isEmpty {
            let floatCount = length / MemoryLayout<Float>.size
            guard floatCount > 0 else { return }
            samples = data.withMemoryRebound(to: Float.self, capacity: floatCount) {
                Array(UnsafeBufferPointer(start: $0, count: floatCount))
            }
        }
        
        guard !samples.isEmpty else { return }
        
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
