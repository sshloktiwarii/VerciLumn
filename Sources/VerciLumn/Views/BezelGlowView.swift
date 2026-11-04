import SwiftUI

public struct BezelGlowView: View {
    @ObservedObject var audioEngine = AudioBeatEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playback = PlaybackManager.shared
    
    var isEnabled: Bool = true
    var glowIntensityMultiplier: CGFloat = 1.0
    
    public init(isEnabled: Bool = true, glowIntensityMultiplier: CGFloat = 1.0) {
        self.isEnabled = isEnabled
        self.glowIntensityMultiplier = glowIntensityMultiplier
    }
    
    public var body: some View {
        GeometryReader { _ in
            if isEnabled && playback.currentTrack.isPlaying {
                let palette = theme.activePalette
                let pulse = CGFloat(audioEngine.beatIntensity) * glowIntensityMultiplier
                
                if pulse > 0.05 {
                    let strokeWidth = 2.0 + (pulse * 5.0)
                    let opacity = min(1.0, pulse * 0.85)
                    
                    let gradientColors: [Color] = palette.isRainbow ? palette.rainbowGradient : [
                        palette.highlightAccent,
                        palette.secondaryGlow,
                        palette.highlightAccent.opacity(0.8),
                        palette.secondaryGlow.opacity(0.9),
                        palette.highlightAccent
                    ]
                    
                    let gradient = AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center
                    )
                    
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(gradient, lineWidth: strokeWidth)
                        .shadow(color: palette.highlightAccent.opacity(opacity * 0.7), radius: 8 + (pulse * 10))
                        .opacity(opacity)
                        .padding(2)
                        .ignoresSafeArea()
                        .animation(.easeOut(duration: 0.1), value: pulse)
                }
            }
        }
    }
}

