import SwiftUI

public struct VinylTurntableView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    
    let size: CGFloat
    
    public init(size: CGFloat = 380) {
        self.size = size
    }
    
    public var body: some View {
        let isPlaying = playback.currentTrack.isPlaying
        let progress = playback.currentTrack.progress
        
        ZStack {
            // Turntable Base Platter with Deep Shadow
            Circle()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.85), radius: 30, x: 0, y: 15)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.clear, Color.black.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            // Spinning Grooved Vinyl Disc
            TimelineView(.animation(paused: !isPlaying)) { timeline in
                let time = isPlaying ? timeline.date.timeIntervalSinceReferenceDate : 0
                // 33.3 RPM = 0.555 rev/sec -> 360 * 0.555 = 200 deg/sec
                let rotation = (time * 200.0).truncatingRemainder(dividingBy: 360.0)
                
                ZStack {
                    // Concentric Micro-Grooves
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let maxRadius = canvasSize.width * 0.48
                        let minRadius = canvasSize.width * 0.22
                        
                        let grooveCount = 18
                        for i in 0..<grooveCount {
                            let frac = CGFloat(i) / CGFloat(grooveCount)
                            let r = minRadius + frac * (maxRadius - minRadius)
                            let groovePath = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                            context.stroke(
                                groovePath,
                                with: .color(Color(white: 0.18 + (Double(i % 3) * 0.04))),
                                lineWidth: 1.0
                            )
                        }
                    }
                    .frame(width: size * 0.94, height: size * 0.94)
                    
                    // Holographic Overhead Light Sheen (Two opposing cones of light reflecting off vinyl)
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.12 + Double(audio.beatIntensity) * 0.08),
                            Color.clear,
                            Color.clear,
                            palette.currentPalette.highlightAccent.opacity(0.15 + Double(audio.beatIntensity) * 0.1),
                            Color.clear
                        ]),
                        center: .center
                    )
                    .clipShape(Circle())
                    .frame(width: size * 0.94, height: size * 0.94)
                    
                    // Center Album Art Label
                    ZStack {
                        if let art = playback.currentTrack.artwork {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size * 0.38, height: size * 0.38)
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
                                .frame(width: size * 0.38, height: size * 0.38)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: size * 0.12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        // Center Spindle Hole & Metallic Washer
                        Circle()
                            .fill(Color(white: 0.05))
                            .frame(width: size * 0.07, height: size * 0.07)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                }
                .rotationEffect(.degrees(rotation))
            }
            .scaleEffect(1.0 + CGFloat(audio.beatIntensity) * 0.02)
            
            // Physical Pivoting Tonearm
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
                .shadow(color: .black.opacity(0.5), radius: 6)
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
                            colors: [Color(white: 0.9), Color(white: 0.65), Color(white: 0.45)],
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
            .shadow(color: .black.opacity(0.4), radius: 8, x: 5, y: 5)
            .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: 0.5, y: 0.12))
            .position(x: size * 0.88, y: size * 0.16)
            .animation(.spring(response: 0.6, dampingFraction: 0.82), value: armAngle)
        }
    }
}
