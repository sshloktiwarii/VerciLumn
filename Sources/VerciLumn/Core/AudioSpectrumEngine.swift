import Foundation
import Accelerate
import Combine

public final class AudioSpectrumEngine: ObservableObject, @unchecked Sendable {
    public static let shared = AudioSpectrumEngine()
    
    /// 8 Normalized frequency bands: [Sub-Bass, Bass, Low-Mid, Mid, High-Mid, Presence, Brilliance, Air]
    @Published public private(set) var bands: [Float] = Array(repeating: 0.05, count: 8)
    @Published public private(set) var overallEnergy: Float = 0.0
    
    private let fftSize = 1024
    private let log2n: vDSP_Length
    private let fftSetup: vDSP_DFT_Setup?
    private var simulatedTimer: AnyCancellable?
    private var smoothBands: [Float] = Array(repeating: 0.05, count: 8)
    private var phase: Float = 0.0
    
    private init() {
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        startSimulatedFallback()
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    public func processAudio(samples: [Float]) {
        guard samples.count >= fftSize else { return }
        
        // Windowing with Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))
        
        // Real & Imaginary buffers
        var realIn = windowedSamples
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)
        
        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        }
        
        // Compute Magnitudes safely with persistent buffers
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realOut.withUnsafeMutableBufferPointer { rBuf in
            imagOut.withUnsafeMutableBufferPointer { iBuf in
                guard let rPtr = rBuf.baseAddress, let iPtr = iBuf.baseAddress else { return }
                var complexOut = DSPSplitComplex(realp: rPtr, imagp: iPtr)
                vDSP_zvabs(&complexOut, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }
        
        // Group into 8 logarithmic musical frequency bands
        // Bin ranges (assuming 44100Hz, bin resolution ~43Hz):
        // 1. Sub-bass: bins 1..2 (~40-90Hz)
        // 2. Bass: bins 3..6 (~130-260Hz)
        // 3. Low-mid: bins 7..12 (~300-520Hz)
        // 4. Mid: bins 13..35 (~560-1500Hz)
        // 5. High-mid: bins 36..70 (~1550-3000Hz)
        // 6. Presence: bins 71..140 (~3050-6000Hz)
        // 7. Brilliance: bins 141..280 (~6050-12000Hz)
        // 8. Air: bins 281..511 (~12000-22000Hz)
        let binRanges = [
            1...2,
            3...6,
            7...12,
            13...35,
            36...70,
            71...140,
            141...280,
            281...min(511, magnitudes.count - 1)
        ]
        
        var rawBands = [Float](repeating: 0.0, count: 8)
        for (i, range) in binRanges.enumerated() {
            var sum: Float = 0
            for bin in range {
                sum += magnitudes[bin]
            }
            let avg = sum / Float(range.count)
            // Scaling factor with log compression
            let scaled = min(max(log10(1.0 + avg * 8.0) * 0.4, 0.0), 1.0)
            rawBands[i] = scaled
        }
        
        // Inertia smoothing: snappy attack, smooth decay
        let decay: Float = 0.82
        for i in 0..<8 {
            if rawBands[i] > smoothBands[i] {
                smoothBands[i] = rawBands[i]
            } else {
                smoothBands[i] = smoothBands[i] * decay + rawBands[i] * (1.0 - decay)
            }
        }
        
        let energy = smoothBands.reduce(0, +) / 8.0
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bands = self.smoothBands
            self.overallEnergy = energy
        }
    }
    
    private func startSimulatedFallback() {
        simulatedTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Only run simulation when AudioBeatEngine is not actively feeding live samples
                guard !AudioBeatEngine.shared.isCapturing else { return }
                
                self.phase += 0.08
                var sim = [Float](repeating: 0.0, count: 8)
                for i in 0..<8 {
                    let freq = Float(i + 1) * 0.4
                    let wave = (sin(self.phase * freq) + sin(self.phase * 0.7 + Float(i))) * 0.5
                    sim[i] = min(max(Float(wave * 0.35 + 0.4), 0.05), 0.95)
                }
                self.bands = sim
                self.overallEnergy = sim.reduce(0, +) / 8.0
            }
    }
}
