import Foundation
import Metal
import MetalKit

public final class MetalShaderRenderer: @unchecked Sendable {
    public static let shared = MetalShaderRenderer()
    
    public let device: MTLDevice?
    public let commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    
    /// Global render loop suspension flag (e.g. Low Power Mode, battery preservation)
    public var isSuspended: Bool = false
    
    /// Ambient frame rate limiter (30 FPS max: 1.0 / 30.0 = 0.0333s)
    private var lastRenderTime: TimeInterval = 0
    private let minimumFrameInterval: TimeInterval = 1.0 / 30.0
    
    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        setupPipeline()
    }
    
    private func setupPipeline() {
        guard let device = device else { return }
        
        // 1. Try compiled metallib in bundle
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.module),
           let kernelFunction = library.makeFunction(name: "fisheyeDistortion") {
            self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
            return
        }
        
        // 2. Try compiling shader source at runtime (GPU driver JIT)
        if let shaderURL = Bundle.module.url(forResource: "FisheyeShader", withExtension: "metal"),
           let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8),
           let library = try? device.makeLibrary(source: shaderSource, options: nil),
           let kernelFunction = library.makeFunction(name: "fisheyeDistortion") {
            self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
            return
        }
        
        // 3. Fallback to system default library
        if let library = device.makeDefaultLibrary(),
           let kernelFunction = library.makeFunction(name: "fisheyeDistortion") {
            self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
        }
    }
    
    public func applyFisheye(
        source: MTLTexture,
        destination: MTLTexture,
        center: SIMD2<Float>,
        radius: Float,
        strength: Float
    ) {
        // Immediate thermal guard: when paused, suspended, or in low power mode, drop GPU to 0%
        guard !isSuspended, PlaybackManager.shared.currentTrack.isPlaying else {
            return
        }
        
        let now = CACurrentMediaTime()
        guard now - lastRenderTime >= minimumFrameInterval else {
            return
        }
        lastRenderTime = now
        
        guard let commandQueue = commandQueue,
              let pipelineState = computePipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        var centerMut = center
        var radiusMut = radius
        var strengthMut = strength
        encoder.setBytes(&centerMut, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
        encoder.setBytes(&radiusMut, length: MemoryLayout<Float>.size, index: 1)
        encoder.setBytes(&strengthMut, length: MemoryLayout<Float>.size, index: 2)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (source.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (source.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
    }
}
