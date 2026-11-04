import SwiftUI

public struct LiquidWaveformRingView: View {
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    let size: CGFloat
    
    public init(size: CGFloat = 320) {
        self.size = size
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: false)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let baseRadius = min(canvasSize.width, canvasSize.height) * 0.38
                let bands = spectrum.bands
                
                // Draw multiple layered harmonic ripples
                for ring in 0..<3 {
                    var path = Path()
                    let points = 64
                    let ringOffset = Double(ring) * 1.2
                    let alpha = 0.6 - (Double(ring) * 0.18)
                    
                    for i in 0...points {
                        let angle = (Double(i) / Double(points)) * 2.0 * .pi
                        let bandIndex = Int((Double(i) / Double(points)) * 8.0) % 8
                        let bandVal = Double(bands[bandIndex])
                        
                        let wave = sin(angle * 5.0 + time * 2.5 + ringOffset) * (12.0 + bandVal * 28.0)
                        let r = baseRadius + CGFloat(wave) + CGFloat(ring * 14)
                        
                        let px = center.x + r * CGFloat(cos(angle))
                        let py = center.y + r * CGFloat(sin(angle))
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: px, y: py))
                        } else {
                            path.addLine(to: CGPoint(x: px, y: py))
                        }
                    }
                    path.closeSubpath()
                    
                    let ringColor = (ring == 0) ? palette.currentPalette.highlightAccent : palette.currentPalette.secondaryGlow
                    context.stroke(
                        path,
                        with: .color(ringColor.opacity(alpha)),
                        lineWidth: CGFloat(3 - ring)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

public struct AmbientFloorBarsView: View {
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<32, id: \.self) { idx in
                let bandIdx = (idx * 8) / 32
                let val = CGFloat(spectrum.bands[bandIdx])
                // Add natural arc curve towards center
                let arc = sin(Double(idx) / 31.0 * .pi)
                let barHeight = max(4.0, (val * 70.0 + 8.0) * CGFloat(arc))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.currentPalette.highlightAccent.opacity(0.85),
                                palette.currentPalette.secondaryGlow.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: barHeight)
                    .animation(.spring(response: 0.18, dampingFraction: 0.65), value: spectrum.bands)
            }
        }
        .frame(height: 80)
        .padding(.horizontal, 48)
        .allowsHitTesting(false)
    }
}

