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
        GeometryReader { geometry in
            if isEnabled {
                let pulse = CGFloat(audioEngine.beatIntensity) * glowIntensityMultiplier
                let strokeWidth = 3.0 + (pulse * 8.0)
                let blurRadius = 8.0 + (pulse * 24.0)
                let opacity = 0.35 + (pulse * 0.65)
                
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
                
                ZStack {
                    // Outer diffuse bloom
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(gradient, lineWidth: strokeWidth * 1.8)
                        .blur(radius: blurRadius * 1.5)
                        .opacity(opacity * 0.7)
                    
                    // Sharp internal rim glow
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(gradient, lineWidth: strokeWidth)
                        .blur(radius: blurRadius * 0.4)
                        .opacity(opacity)
                }
                .padding(2)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.08), value: pulse)
            }
        }
    }
}
