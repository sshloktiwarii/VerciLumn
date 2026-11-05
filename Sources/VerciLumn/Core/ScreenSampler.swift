import Foundation
import CoreGraphics
import IOSurface
import SwiftUI
import Combine

/// Hardware-accelerated screen edge sampler powered by `CGDisplayStream` and `IOSurface`.
/// Captures a downscaled 128x72 stream at 30 FPS directly from the GPU, extracts edge border colors,
/// and feeds them into `BezelGlowView` for a dynamic Ambilight experience.
public final class ScreenSampler: ObservableObject {
    public static let shared = ScreenSampler()
    
    // Sampled Edge Colors
    @Published public private(set) var topColor: Color = Color.clear
    @Published public private(set) var bottomColor: Color = Color.clear
    @Published public private(set) var leftColor: Color = Color.clear
    @Published public private(set) var rightColor: Color = Color.clear
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var hasScreenCapturePermission: Bool = true
    
    // Downscale Resolution: 128x72 yields sub-millisecond GPU sampling with near-zero CPU/memory footprint
    public static let targetWidth = 128
    public static let targetHeight = 72
    public static let targetFps = 30
    
    private var displayStream: CGDisplayStream?
    private let samplerQueue = DispatchQueue(label: "com.vercilumn.screensampler", qos: .userInteractive)
    private var lastPublishTime: CFAbsoluteTime = 0
    private let minPublishInterval: CFAbsoluteTime = 1.0 / 30.0 // Cap UI dispatch to 30 FPS
    
    private init() {}
    
    deinit {
        stop()
    }
    
    // MARK: - Lifecycle Management
    
    public func start() {
        samplerQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.displayStream == nil else { return }
            
            let mainDisplay = CGMainDisplayID()
            guard mainDisplay != 0 else {
                DispatchQueue.main.async { self.isRunning = false }
                return
            }
            
            // BGRA 32-bit pixel format
            let pixelFormat = Int32(kCVPixelFormatType_32BGRA)
            
            let properties: [CFString: Any] = [
                CGDisplayStream.colorSpace: CGColorSpaceCreateDeviceRGB(),
                CGDisplayStream.showCursor: false
            ]
            
            let stream = CGDisplayStream(
                dispatchQueueDisplay: mainDisplay,
                outputWidth: Self.targetWidth,
                outputHeight: Self.targetHeight,
                pixelFormat: pixelFormat,
                properties: properties as CFDictionary,
                queue: self.samplerQueue
            ) { [weak self] status, displayTime, surfaceRef, updateRef in
                guard let self = self else { return }
                guard status == .frameComplete, let surface = surfaceRef else { return }
                self.processFrame(surface: surface)
            }
            
            guard let activeStream = stream else {
                DispatchQueue.main.async {
                    self.hasScreenCapturePermission = false
                    self.isRunning = false
                }
                return
            }
            
            let result = activeStream.start()
            if result == .success {
                self.displayStream = activeStream
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.hasScreenCapturePermission = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    public func stop() {
        samplerQueue.async { [weak self] in
            guard let self = self else { return }
            if let stream = self.displayStream {
                stream.stop()
                self.displayStream = nil
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
    
    // MARK: - Safe IOSurface Frame Processing
    
    private func processFrame(surface: IOSurfaceRef) {
        // Enforce lock and guaranteed defer unlock to eliminate any IOSurfaceRef memory leaks
        let lockResult = IOSurfaceLock(surface, .readOnly, nil)
        guard lockResult == kIOReturnSuccess else { return }
        defer {
            IOSurfaceUnlock(surface, .readOnly, nil)
        }
        
        let baseAddress = IOSurfaceGetBaseAddress(surface)
        let width = IOSurfaceGetWidth(surface)
        let height = IOSurfaceGetHeight(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        
        guard width > 0 && height > 0 && bytesPerRow >= width * 4 else { return }
        
        // Compute edge border averages
        let edges = Self.computeEdgeColors(
            baseAddress: baseAddress,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        )
        
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPublishTime >= minPublishInterval else { return }
        lastPublishTime = now
        
        let tColor = Color(red: edges.top.r, green: edges.top.g, blue: edges.top.b)
        let bColor = Color(red: edges.bottom.r, green: edges.bottom.g, blue: edges.bottom.b)
        let lColor = Color(red: edges.left.r, green: edges.left.g, blue: edges.left.b)
        let rColor = Color(red: edges.right.r, green: edges.right.g, blue: edges.right.b)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.topColor = tColor
            self.bottomColor = bColor
            self.leftColor = lColor
            self.rightColor = rColor
        }
    }
    
    // MARK: - Pure Border Extraction (Testable)
    
    public struct RGBColor: Equatable {
        public let r: Double
        public let g: Double
        public let b: Double
        
        public init(r: Double, g: Double, b: Double) {
            self.r = (r.isNaN || r.isInfinite) ? 0.0 : max(0.0, min(1.0, r))
            self.g = (g.isNaN || g.isInfinite) ? 0.0 : max(0.0, min(1.0, g))
            self.b = (b.isNaN || b.isInfinite) ? 0.0 : max(0.0, min(1.0, b))
        }
    }
    
    public struct EdgeRGBResult: Equatable {
        public let top: RGBColor
        public let bottom: RGBColor
        public let left: RGBColor
        public let right: RGBColor
    }
    
    /// Extracts the average RGB color along the 1-pixel border of a 32-bit BGRA buffer.
    public static func computeEdgeColors(
        baseAddress: UnsafeRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> EdgeRGBResult {
        guard width >= 2 && height >= 2 else {
            let fallback = RGBColor(r: 0, g: 0, b: 0)
            return EdgeRGBResult(top: fallback, bottom: fallback, left: fallback, right: fallback)
        }
        
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Helper to read pixel RGB from BGRA format
        func readPixel(x: Int, y: Int) -> (r: Double, g: Double, b: Double) {
            let offset = y * bytesPerRow + x * 4
            let b = Double(ptr[offset]) / 255.0
            let g = Double(ptr[offset + 1]) / 255.0
            let r = Double(ptr[offset + 2]) / 255.0
            return (r, g, b)
        }
        
        // 1. Top Edge (row 0)
        var topR = 0.0, topG = 0.0, topB = 0.0
        for x in 0..<width {
            let px = readPixel(x: x, y: 0)
            topR += px.r; topG += px.g; topB += px.b
        }
        let topCount = Double(width)
        let topAvg = RGBColor(r: topR / topCount, g: topG / topCount, b: topB / topCount)
        
        // 2. Bottom Edge (row height - 1)
        var botR = 0.0, botG = 0.0, botB = 0.0
        let lastY = height - 1
        for x in 0..<width {
            let px = readPixel(x: x, y: lastY)
            botR += px.r; botG += px.g; botB += px.b
        }
        let botCount = Double(width)
        let botAvg = RGBColor(r: botR / botCount, g: botG / botCount, b: botB / botCount)
        
        // 3. Left Edge (column 0)
        var leftR = 0.0, leftG = 0.0, leftB = 0.0
        for y in 0..<height {
            let px = readPixel(x: 0, y: y)
            leftR += px.r; leftG += px.g; leftB += px.b
        }
        let leftCount = Double(height)
        let leftAvg = RGBColor(r: leftR / leftCount, g: leftG / leftCount, b: leftB / leftCount)
        
        // 4. Right Edge (column width - 1)
        var rightR = 0.0, rightG = 0.0, rightB = 0.0
        let lastX = width - 1
        for y in 0..<height {
            let px = readPixel(x: lastX, y: y)
            rightR += px.r; rightG += px.g; rightB += px.b
        }
        let rightCount = Double(height)
        let rightAvg = RGBColor(r: rightR / rightCount, g: rightG / rightCount, b: rightB / rightCount)
        
        return EdgeRGBResult(top: topAvg, bottom: botAvg, left: leftAvg, right: rightAvg)
    }
}
