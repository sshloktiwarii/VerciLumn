import SwiftUI

public struct VinylTurntableView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    
    let size: CGFloat
    
    public init(size: CGFloat = 520) {
        self.size = size
    }
    
    public var body: some View {
        let isPlaying = playback.currentTrack.isPlaying
        let progress = playback.currentTrack.progress
        let discSize = size * 0.92
        
        ZStack {
            // 1. Audio-Reactive Ambient Underglow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            palette.currentPalette.highlightAccent.opacity(0.35 + Double(audio.beatIntensity) * 0.25),
                            palette.currentPalette.secondaryGlow.opacity(0.15),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: discSize * 0.2,
                        endRadius: discSize * 0.65
                    )
                )
                .frame(width: size * 1.25, height: size * 1.25)
                .allowsHitTesting(false)
            
            // 2. Turntable Base Platter with Deep Shadow & Rim
            Circle()
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.9), radius: 36, x: 0, y: 18)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.clear, Color.black.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                )
            
            // 3. Spinning Full-Bleed Album Cover Picture Disc
            TimelineView(.animation(paused: !isPlaying)) { timeline in
                let time = isPlaying ? timeline.date.timeIntervalSinceReferenceDate : 0
                // 33.3 RPM = 0.555 rev/sec -> 360 * 0.555 = 200 deg/sec
                let rotation = (time * 200.0).truncatingRemainder(dividingBy: 360.0)
                
                ZStack {
                    // Full-bleed Album Cover Artwork
                    if let art = playback.currentTrack.artwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: discSize, height: discSize)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [palette.currentPalette.highlightAccent, palette.currentPalette.secondaryGlow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: discSize, height: discSize)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: discSize * 0.25, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            )
                    }
                    
                    // Concentric Micro-Grooves Overlaid on Album Art
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let maxRadius = canvasSize.width * 0.49
                        let minRadius = canvasSize.width * 0.06
                        
                        let grooveCount = 38
                        for i in 0..<grooveCount {
                            let frac = CGFloat(i) / CGFloat(grooveCount)
                            let r = minRadius + frac * (maxRadius - minRadius)
                            let groovePath = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                            
                            let isHighlight = (i % 3 == 0)
                            let alpha = isHighlight ? 0.09 : 0.14
                            let clr = isHighlight ? Color.white : Color.black
                            context.stroke(
                                groovePath,
                                with: .color(clr.opacity(alpha)),
                                lineWidth: 0.9
                            )
                        }
                    }
                    .frame(width: discSize, height: discSize)
                    
                    // Holographic Overhead Vinyl Light Sheen (Two opposing reflection cones)
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.18 + Double(audio.beatIntensity) * 0.1),
                            Color.clear,
                            Color.clear,
                            palette.currentPalette.highlightAccent.opacity(0.22 + Double(audio.beatIntensity) * 0.14),
                            Color.white.opacity(0.14 + Double(audio.beatIntensity) * 0.08),
                            Color.clear
                        ]),
                        center: .center
                    )
                    .clipShape(Circle())
                    .frame(width: discSize, height: discSize)
                    
                    // Outer Beveled Vinyl Edge Rim
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.black.opacity(0.7), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: discSize, height: discSize)
                    
                    // Center Spindle Hole & Brushed Metallic Washer
                    ZStack {
                        // Metallic Washer Ring
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.88), Color(white: 0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: discSize * 0.07, height: discSize * 0.07)
                            .shadow(color: Color.black.opacity(0.7), radius: 3)
                        
                        // Center Hole
                        Circle()
                            .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
                            .frame(width: discSize * 0.042, height: discSize * 0.042)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.75), lineWidth: 1.2)
                            )
                    }
                }
                .rotationEffect(.degrees(rotation))
            }
            .scaleEffect(1.0 + CGFloat(audio.beatIntensity) * 0.015)
            
            // 4. Physical Pivoting Tonearm
            TonearmView(size: size, progress: progress, isPlaying: isPlaying)
        }
        .frame(width: size, height: size)
    }
}

private struct TonearmView: View {
    let size: CGFloat
    let progress: Double
    let isPlaying: Bool
    
    var body: some View {
        // Outer track angle: -18 deg, Inner groove lead-out: +12 deg, Resting: -32 deg
        let armAngle: Double = isPlaying ? (-18.0 + progress * 30.0) : -32.0
        
        ZStack {
            // Tonearm Pivot Base (Top-Right corner of platter)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.35), Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.14, height: size * 0.14)
                .shadow(color: .black.opacity(0.55), radius: 6)
                .position(x: size * 0.88, y: size * 0.16)
            
            // Brushed Aluminum Tonearm Bar & Stylus Head
            VStack(spacing: 0) {
                // Counterweight
                Capsule()
                    .fill(Color(white: 0.25))
                    .frame(width: size * 0.04, height: size * 0.08)
                
                // Chrome Arm
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.92), Color(white: 0.65), Color(white: 0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.016, height: size * 0.48)
                
                // Angled Cartridge / Stylus Head
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.9, green: 0.2, blue: 0.2))
                    .frame(width: size * 0.045, height: size * 0.07)
                    .rotationEffect(.degrees(22))
            }
            .shadow(color: .black.opacity(0.45), radius: 8, x: 5, y: 5)
            .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: 0.5, y: 0.12))
            .position(x: size * 0.88, y: size * 0.16)
            .animation(.spring(response: 0.6, dampingFraction: 0.82), value: armAngle)
        }
    }
}
