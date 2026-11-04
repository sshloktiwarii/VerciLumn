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
    
    func setup(in size: CGSize, count: Int = 50) {
        guard size.width > 0, size.height > 0 else { return }
        self.currentSize = size
        particles = (0..<count).map { _ in
            let r = CGFloat.random(in: 2.0...4.5)
            return Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                vx: CGFloat.random(in: -0.25...0.25),
                vy: CGFloat.random(in: -0.25...0.25),
                baseRadius: r,
                alpha: Double.random(in: 0.3...0.85),
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
        let speed = (1.0 + beat * 2.5) * dt * 60.0
        
        let cx = size.width / 2
        let cy = size.height / 2
        let kick = beat > 0.35 ? (beat * 18.0 * dt) : 0
        
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
            
            if particles[i].x < -10 { particles[i].x = size.width + 10 }
            if particles[i].x > size.width + 10 { particles[i].x = -10 }
            if particles[i].y < -10 { particles[i].y = size.height + 10 }
            if particles[i].y > size.height + 10 { particles[i].y = -10 }
        }
    }
}

public struct ParticleCosmosView: View {
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
    // Class instance does NOT trigger SwiftUI body re-evaluations
    @State private var simulator = ParticleSimulator()
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
                Canvas { context, size in
                    let beat = CGFloat(audio.beatIntensity)
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    simulator.step(time: time, beat: beat, in: size)
                    
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    
                    // 1. Soft Radial Ambient Center Pulse (Single hardware accelerated draw)
                    let ambientRadius = min(size.width, size.height) * (0.35 + (beat * 0.15))
                    let ambientRect = CGRect(
                        x: center.x - ambientRadius,
                        y: center.y - ambientRadius,
                        width: ambientRadius * 2,
                        height: ambientRadius * 2
                    )
                    context.fill(
                        Circle().path(in: ambientRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                palette.currentPalette.highlightAccent.opacity(0.12 + Double(beat) * 0.12),
                                palette.currentPalette.secondaryGlow.opacity(0.05),
                                Color.clear
                            ]),
                            center: center,
                            startRadius: 10,
                            endRadius: ambientRadius
                        )
                    )
                    
                    // 2. Optimized Particle Drawing
                    let primaryColor = palette.currentPalette.highlightAccent
                    let secondaryColor = palette.currentPalette.secondaryGlow
                    
                    for p in simulator.particles {
                        let r = p.baseRadius + (beat * 3.0)
                        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                        let col = (p.isSecondary ? secondaryColor : primaryColor)
                            .opacity(p.alpha * (0.7 + Double(beat) * 0.3))
                        
                        context.fill(Circle().path(in: rect), with: .color(col))
                    }
                }
            }
            .onAppear {
                simulator.setup(in: geometry.size)
            }
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.05))
    }
}
