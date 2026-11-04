import SwiftUI

public struct LiquidWaveformRingView: View {
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var settings = AppSettings.shared
    let size: CGFloat
    
    public init(size: CGFloat = 320) {
        self.size = size
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: settings.targetFpsInterval, paused: !playback.currentTrack.isPlaying)) { timeline in
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
                    
                    let ringColor = (ring == 0) ? theme.activePalette.highlightAccent : theme.activePalette.secondaryGlow
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
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playback = PlaybackManager.shared
    
    public init() {}
    
    public var body: some View {
        if playback.currentTrack.isPlaying {
            let palette = theme.activePalette
            let colors: [Color] = palette.isRainbow ? palette.rainbowGradient : [
                palette.highlightAccent.opacity(0.6),
                palette.secondaryGlow.opacity(0.2)
            ]
            
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<48, id: \.self) { idx in
                    let bandIdx = (idx * 8) / 48
                    let val = CGFloat(spectrum.bands[bandIdx])
                    let arc = sin(Double(idx) / 47.0 * .pi)
                    let barHeight = max(2.0, (val * 12.0 + 2.0) * CGFloat(arc))
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: barHeight)
                        .animation(.easeOut(duration: 0.08), value: val)
                }
            }
            .frame(height: 16)
            .opacity(0.4)
            .padding(.horizontal, 60)
            .allowsHitTesting(false)
        }
    }
}

