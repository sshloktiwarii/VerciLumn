import Foundation
import CoreImage
import AppKit
import SwiftUI

public struct ColorPalette: Equatable {
    public let background: Color
    public let primaryText: Color
    public let highlightAccent: Color
    public let secondaryGlow: Color
    
    public init(
        background: Color = Color(red: 0.08, green: 0.08, blue: 0.1),
        primaryText: Color = .white,
        highlightAccent: Color = Color(red: 0.95, green: 0.35, blue: 0.6),
        secondaryGlow: Color = Color(red: 0.3, green: 0.6, blue: 0.95)
    ) {
        self.background = background
        self.primaryText = primaryText
        self.highlightAccent = highlightAccent
        self.secondaryGlow = secondaryGlow
    }
}

public final class ColorPaletteManager: ObservableObject {
    public static let shared = ColorPaletteManager()
    
    @Published public private(set) var currentPalette: ColorPalette = ColorPalette()
    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    
    private init() {}
    
    public func updatePalette(from image: NSImage?) {
        guard let image = image else {
            DispatchQueue.main.async {
                self.currentPalette = ColorPalette()
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let palette = self.extractPalette(from: image)
            DispatchQueue.main.async {
                self.currentPalette = palette
            }
        }
    }
    
    public func extractPalette(from image: NSImage) -> ColorPalette {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return ColorPalette()
        }
        
        let filter = CIFilter(name: "CIKMeans")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")
        filter?.setValue(3, forKey: "inputCount")
        filter?.setValue(5, forKey: "inputPasses")
        
        guard let outputImage = filter?.outputImage else {
            return ColorPalette()
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4 * 3)
        let rect = CGRect(x: 0, y: 0, width: 3, height: 1)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4 * 3, bounds: rect, format: .RGBA8, colorSpace: nil)
        
        func makeColor(at index: Int) -> (r: Double, g: Double, b: Double) {
            let offset = index * 4
            let r = Double(bitmap[offset]) / 255.0
            let g = Double(bitmap[offset + 1]) / 255.0
            let b = Double(bitmap[offset + 2]) / 255.0
            return (r, g, b)
        }
        
        let c0 = makeColor(at: 0)
        let c1 = makeColor(at: 1)
        let c2 = makeColor(at: 2)
        
        let bg = Color(red: c0.r * 0.25, green: c0.g * 0.25, blue: c0.b * 0.25)
        let accent = Color(red: max(c1.r, 0.4), green: max(c1.g, 0.4), blue: max(c1.b, 0.4))
        let secondary = Color(red: max(c2.r, 0.3), green: max(c2.g, 0.5), blue: max(c2.b, 0.8))
        
        return ColorPalette(
            background: bg,
            primaryText: .white,
            highlightAccent: accent,
            secondaryGlow: secondary
        )
    }
}

