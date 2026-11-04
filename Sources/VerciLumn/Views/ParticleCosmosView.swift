import SwiftUI

final class ParticleSimulator {
    struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var baseRadius: CGFloat
        var alpha: Double
        var isSecondary: Bool
    }
    
    var particles: [Particle] = []
    private var lastTime: TimeInterval = 0
    private var currentSize: CGSize = .zero
    
    func setup(in size: CGSize, count: Int = 40) {
        guard size.width > 0, size.height > 0 else { return }
        self.currentSize = size
        particles = (0..<count).map { _ in
            let r = CGFloat.random(in: 1.5...3.5)
            return Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                vx: CGFloat.random(in: -0.2...0.2),
                vy: CGFloat.random(in: -0.2...0.2),
                baseRadius: r,
                alpha: Double.random(in: 0.25...0.7),
                isSecondary: Bool.random()
            )
        }
    }
    
    func step(time: TimeInterval, beat: CGFloat, in size: CGSize) {
        guard !particles.isEmpty, size.width > 0, size.height > 0 else {
            setup(in: size)
            return
        }
        
        let dt = lastTime > 0 ? min(CGFloat(time - lastTime), 0.05) : 0.016
        lastTime = time
        let speed = (1.0 + beat * 2.0) * dt * 60.0
        
        let cx = size.width / 2
        let cy = size.height / 2
        let kick = beat > 0.35 ? (beat * 15.0 * dt) : 0
        
        for i in 0..<particles.count {
            particles[i].x += particles[i].vx * speed
            particles[i].y += particles[i].vy * speed
            
            if kick > 0 {
                let dx = particles[i].x - cx
                let dy = particles[i].y - cy
                let dist = max(sqrt(dx * dx + dy * dy), 1.0)
                particles[i].x += (dx / dist) * kick
                particles[i].y += (dy / dist) * kick
            }
            
            // Screen edge wrap
            if particles[i].x < 0 { particles[i].x = size.width }
            if particles[i].x > size.width { particles[i].x = 0 }
            if particles[i].y < 0 { particles[i].y = size.height }
            if particles[i].y > size.height { particles[i].y = 0 }
        }
    }
}

public struct ParticleCosmosView: View {
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var simulator = ParticleSimulator()
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            TimelineView(
                .animation(
                    minimumInterval: settings.targetFpsInterval,
                    paused: !playback.currentTrack.isPlaying
                )
            ) { timeline in
                Canvas { context, size in
                    guard playback.currentTrack.isPlaying else { return }
                    let beat = CGFloat(audio.beatIntensity)
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    simulator.step(time: time, beat: beat, in: size)
                    
                    let palette = theme.activePalette
                    let primaryColor = palette.highlightAccent
                    let secondaryColor = palette.secondaryGlow
                    
                    // Draw Floating Particles with zero fog/haze
                    for p in simulator.particles {
                        let r = p.baseRadius + (beat * 2.0)
                        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                        let col = (p.isSecondary ? secondaryColor : primaryColor)
                            .opacity(p.alpha * (0.6 + Double(beat) * 0.4))
                        
                        context.fill(Circle().path(in: rect), with: .color(col))
                    }
                }
            }
            .onAppear {
                simulator.setup(in: geometry.size)
            }
        }
        .background(Color.clear)
    }
}
