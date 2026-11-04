import SwiftUI

public struct BezelGlowView: View {
    @ObservedObject var audioEngine = AudioBeatEngine.shared
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    
    var isEnabled: Bool = true
    var glowIntensityMultiplier: CGFloat = 1.0
    
    public init(isEnabled: Bool = true, glowIntensityMultiplier: CGFloat = 1.0) {
        self.isEnabled = isEnabled
        self.glowIntensityMultiplier = glowIntensityMultiplier
    }
    
    public var body: some View {
        GeometryReader { _ in
            if isEnabled {
                let pulse = CGFloat(audioEngine.beatIntensity) * glowIntensityMultiplier
                let strokeWidth = 3.0 + (pulse * 6.0)
                let opacity = 0.4 + (pulse * 0.6)
                
                let gradient = AngularGradient(
                    gradient: Gradient(colors: [
                        paletteManager.currentPalette.highlightAccent,
                        paletteManager.currentPalette.secondaryGlow,
                        paletteManager.currentPalette.highlightAccent.opacity(0.8),
                        paletteManager.currentPalette.secondaryGlow.opacity(0.9),
                        paletteManager.currentPalette.highlightAccent
                    ]),
                    center: .center
                )
                
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(gradient, lineWidth: strokeWidth)
                    .shadow(color: paletteManager.currentPalette.highlightAccent.opacity(opacity * 0.7), radius: 12 + (pulse * 10))
                    .padding(2)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.1), value: pulse)
            }
        }
    }
}
