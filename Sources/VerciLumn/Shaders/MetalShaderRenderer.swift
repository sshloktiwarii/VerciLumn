import Foundation
import Metal
import MetalKit

public final class MetalShaderRenderer {
    public static let shared = MetalShaderRenderer()
    
    public let device: MTLDevice?
    public let commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    
    private init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        setupPipeline()
    }
    
    private func setupPipeline() {
        guard let device = device else { return }
        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle.module)
            if let kernelFunction = library.makeFunction(name: "fisheyeDistortion") {
                self.computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
            }
        } catch {
            // Fallback to system default library if bundle-specific load fails
            if let library = device.makeDefaultLibrary(),
               let kernelFunction = library.makeFunction(name: "fisheyeDistortion") {
                self.computePipelineState = try? device.makeComputePipelineState(function: kernelFunction)
            }
        }
    }
    
    public func applyFisheye(
        source: MTLTexture,
        destination: MTLTexture,
        center: SIMD2<Float>,
        radius: Float,
        strength: Float
    ) {
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
