import SwiftUI

public struct BezelGlowView: View {
    @ObservedObject var audioEngine = AudioBeatEngine.shared
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var screenSampler = ScreenSampler.shared
    
    var isEnabled: Bool = true
    var glowIntensityMultiplier: CGFloat = 1.0
    
    public init(isEnabled: Bool = true, glowIntensityMultiplier: CGFloat = 1.0) {
        self.isEnabled = isEnabled
        self.glowIntensityMultiplier = glowIntensityMultiplier
    }
    
    public var body: some View {
        GeometryReader { geo in
            // Strict thermal guard: 0% GPU when disabled or (in audio mode and paused)
            let isAmbilight = settings.bezelSourceMode == .screenSampling
            let shouldGlow = isEnabled && (isAmbilight ? screenSampler.isRunning : playback.currentTrack.isPlaying)
            
            if shouldGlow {
                let palette = theme.activePalette
                let bands = spectrum.bands
                let mult = (glowIntensityMultiplier.isNaN || glowIntensityMultiplier.isInfinite) ? 1.0 : max(0.0, glowIntensityMultiplier)
                
                // Color & Pulse resolution: Either from ScreenSampler or Audio FFT
                let (bottomColor, leftColor, rightColor, topColor, bottomPulse, leftPulse, rightPulse, topPulse): (Color, Color, Color, Color, CGFloat, CGFloat, CGFloat, CGFloat) = {
                    if isAmbilight {
                        // Hardware-accelerated Ambilight projection from ScreenSampler
                        let baseIntensity = min(1.0, max(0.2, 0.7 * mult))
                        return (
                            screenSampler.bottomColor,
                            screenSampler.leftColor,
                            screenSampler.rightColor,
                            screenSampler.topColor,
                            baseIntensity,
                            baseIntensity,
                            baseIntensity,
                            baseIntensity
                        )
                    } else {
                        // Discrete multi-zone frequency mapping from hardware vDSP FFT:
                        // 1. Sub-bass & Bass (Bands 0 & 1) -> Bottom Edge
                        let b0 = bands.indices.contains(0) ? CGFloat(bands[0]) : 0.05
                        let b1 = bands.indices.contains(1) ? CGFloat(bands[1]) : 0.05
                        let bPulse = min(1.0, max(0.0, (b0 * 0.75 + b1 * 0.25) * mult))
                        
                        // 2. Low-Mid & Mid Vocals (Bands 2 & 3) -> Left Edge
                        let b2 = bands.indices.contains(2) ? CGFloat(bands[2]) : 0.05
                        let b3 = bands.indices.contains(3) ? CGFloat(bands[3]) : 0.05
                        let lPulse = min(1.0, max(0.0, (b2 * 0.5 + b3 * 0.5) * mult))
                        
                        // 3. High-Mid & Presence Percussion (Bands 4 & 5) -> Right Edge
                        let b4 = bands.indices.contains(4) ? CGFloat(bands[4]) : 0.05
                        let b5 = bands.indices.contains(5) ? CGFloat(bands[5]) : 0.05
                        let rPulse = min(1.0, max(0.0, (b4 * 0.5 + b5 * 0.5) * mult))
                        
                        // 4. Brilliance & Air Treble (Bands 6 & 7) -> Top Edge
                        let b6 = bands.indices.contains(6) ? CGFloat(bands[6]) : 0.05
                        let b7 = bands.indices.contains(7) ? CGFloat(bands[7]) : 0.05
                        let tPulse = min(1.0, max(0.0, (b6 * 0.5 + b7 * 0.5) * mult))
                        
                        let colors: (Color, Color, Color, Color) = {
                            if palette.isRainbow {
                                return (
                                    Color(red: 1.0, green: 0.2, blue: 0.25),   // Warm Sub-Bass Red
                                    Color(red: 0.2, green: 0.9, blue: 0.5),   // Midrange Emerald
                                    Color(red: 0.2, green: 0.5, blue: 1.0),   // Presence Royal Blue
                                    Color(red: 0.85, green: 0.35, blue: 1.0)  // Treble Air Violet
                                )
                            } else {
                                return (
                                    palette.highlightAccent,
                                    palette.secondaryGlow,
                                    palette.secondaryGlow.opacity(0.9),
                                    palette.highlightAccent.opacity(0.85)
                                )
                            }
                        }()
                        
                        return (colors.0, colors.1, colors.2, colors.3, bPulse, lPulse, rPulse, tPulse)
                    }
                }()
                
                let maxPulse = max(bottomPulse, max(leftPulse, max(rightPulse, topPulse)))
                
                ZStack {
                    // MARK: - Multi-Zone Edge Bloom Gradients (Diffuse Ambilight Projection)
                    // Bottom: Sub-bass bloom
                    if bottomPulse > 0.06 {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                bottomColor.opacity(Double(bottomPulse) * 0.7),
                                bottomColor.opacity(Double(bottomPulse) * 0.25),
                                Color.clear
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: max(20, 70 * bottomPulse))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .blur(radius: 14 + 10 * bottomPulse)
                        .transition(.opacity)
                    }
                    
                    // Top: Treble shimmer bloom
                    if topPulse > 0.06 {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                topColor.opacity(Double(topPulse) * 0.65),
                                topColor.opacity(Double(topPulse) * 0.2),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: max(16, 55 * topPulse))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .blur(radius: 12 + 8 * topPulse)
                        .transition(.opacity)
                    }
                    
                    // Left: Mids / Vocals bloom
                    if leftPulse > 0.06 {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                leftColor.opacity(Double(leftPulse) * 0.65),
                                leftColor.opacity(Double(leftPulse) * 0.2),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(16, 55 * leftPulse))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .blur(radius: 12 + 8 * leftPulse)
                        .transition(.opacity)
                    }
                    
                    // Right: High-mid percussion bloom
                    if rightPulse > 0.06 {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                rightColor.opacity(Double(rightPulse) * 0.65),
                                rightColor.opacity(Double(rightPulse) * 0.2),
                                Color.clear
                            ]),
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                        .frame(width: max(16, 55 * rightPulse))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .blur(radius: 12 + 8 * rightPulse)
                        .transition(.opacity)
                    }
                    
                    // MARK: - Perimeter Bezel Precision Stroke
                    if maxPulse > 0.05 {
                        let strokeWidth = 2.0 + (maxPulse * 4.5)
                        let opacity = min(1.0, maxPulse * 0.9)
                        
                        // Angular gradient blending all 4 zones around the screen perimeter:
                        // Top (air) -> Right (presence) -> Bottom (sub-bass) -> Left (mids) -> Top
                        let perimeterGradient = AngularGradient(
                            stops: [
                                .init(color: topColor.opacity(Double(topPulse)), location: 0.0),
                                .init(color: rightColor.opacity(Double(rightPulse)), location: 0.25),
                                .init(color: bottomColor.opacity(Double(bottomPulse)), location: 0.5),
                                .init(color: leftColor.opacity(Double(leftPulse)), location: 0.75),
                                .init(color: topColor.opacity(Double(topPulse)), location: 1.0)
                            ],
                            center: .center
                        )
                        
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(perimeterGradient, lineWidth: strokeWidth)
                            .shadow(color: bottomColor.opacity(Double(bottomPulse) * 0.5), radius: 6 + (bottomPulse * 8), x: 0, y: 4)
                            .shadow(color: topColor.opacity(Double(topPulse) * 0.4), radius: 6 + (topPulse * 8), x: 0, y: -3)
                            .opacity(opacity)
                            .padding(2)
                            .ignoresSafeArea()
                    }
                }
                .animation(.easeOut(duration: 0.1), value: maxPulse)
                .allowsHitTesting(false)
            }
        }
    }
}
