import SwiftUI

public struct ReactiveParticle: Identifiable {
    public let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var baseRadius: CGFloat
    var radius: CGFloat
    var alpha: Double
    var hueShift: Double
    var pulseDecay: CGFloat
}

public struct ParticleCosmosView: View {
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
    @State private var particles: [ReactiveParticle] = []
    @State private var initialized = false
    
    private let particleCount = 120
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let beat = CGFloat(audio.beatIntensity)
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    
                    // 1. Center Ambient Radial Pulse
                    let ambientRadius = 250 + (beat * 180)
                    let ambientRect = CGRect(
                        x: center.x - ambientRadius / 2,
                        y: center.y - ambientRadius / 2,
                        width: ambientRadius,
                        height: ambientRadius
                    )
                    context.fill(
                        Circle().path(in: ambientRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                palette.currentPalette.highlightAccent.opacity(0.18 + Double(beat) * 0.22),
                                palette.currentPalette.secondaryGlow.opacity(0.08 + Double(beat) * 0.1),
                                Color.clear
                            ]),
                            center: center,
                            startRadius: 10,
                            endRadius: ambientRadius / 2
                        )
                    )
                    
                    // 2. Audio-Reactive Shockwave Ring on heavy beats
                    if beat > 0.4 {
                        let ringRadius = (beat * 400) + 100
                        let ringRect = CGRect(
                            x: center.x - ringRadius,
                            y: center.y - ringRadius,
                            width: ringRadius * 2,
                            height: ringRadius * 2
                        )
                        context.stroke(
                            Circle().path(in: ringRect),
                            with: .color(palette.currentPalette.highlightAccent.opacity(Double(1.0 - beat) * 0.4)),
                            lineWidth: 2 + (beat * 3)
                        )
                    }
                    
                    // 3. Render Particles
                    for particle in particles {
                        let currentRadius = particle.baseRadius + (beat * 5.0)
                        let rect = CGRect(
                            x: particle.x - currentRadius,
                            y: particle.y - currentRadius,
                            width: currentRadius * 2,
                            height: currentRadius * 2
                        )
                        
                        let particleColor = (particle.hueShift > 0.5 ? palette.currentPalette.highlightAccent : palette.currentPalette.secondaryGlow)
                            .opacity(particle.alpha * (0.6 + Double(beat) * 0.4))
                        
                        // Particle Bloom
                        context.fill(
                            Circle().path(in: rect.insetBy(dx: -currentRadius * 0.8, dy: -currentRadius * 0.8)),
                            with: .color(particleColor.opacity(0.25))
                        )
                        // Particle Core
                        context.fill(
                            Circle().path(in: rect),
                            with: .color(particleColor)
                        )
                    }
                }
                .onChange(of: timeline.date) { _, _ in
                    updateParticles(in: geometry.size)
                }
            }
            .onAppear {
                initParticles(in: geometry.size)
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
    }
    
    private func initParticles(in size: CGSize) {
        guard !initialized, size.width > 0, size.height > 0 else { return }
        initialized = true
        particles = (0..<particleCount).map { _ in
            makeParticle(in: size)
        }
    }
    
    private func makeParticle(in size: CGSize) -> ReactiveParticle {
        let baseR = CGFloat.random(in: 1.5...4.5)
        return ReactiveParticle(
            x: CGFloat.random(in: 0...size.width),
            y: CGFloat.random(in: 0...size.height),
            vx: CGFloat.random(in: -0.4...0.4),
            vy: CGFloat.random(in: -0.4...0.4),
            baseRadius: baseR,
            radius: baseR,
            alpha: Double.random(in: 0.35...0.9),
            hueShift: Double.random(in: 0...1),
            pulseDecay: CGFloat.random(in: 0.92...0.98)
        )
    }
    
    private func updateParticles(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if particles.isEmpty {
            initParticles(in: size)
            return
        }
        
        let beat = CGFloat(audio.beatIntensity)
        let speedMultiplier = 1.0 + (beat * 3.5)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        for i in 0..<particles.count {
            // Apply drift
            particles[i].x += particles[i].vx * speedMultiplier
            particles[i].y += particles[i].vy * speedMultiplier
            
            // On beat kick, apply subtle radial explosion away from center
            if beat > 0.3 {
                let dx = particles[i].x - center.x
                let dy = particles[i].y - center.y
                let dist = max(sqrt(dx * dx + dy * dy), 1.0)
                let push = (beat * 1.8) / dist * 30.0
                particles[i].x += (dx / dist) * push
                particles[i].y += (dy / dist) * push
            }
            
            // Screen Wrapping
            if particles[i].x < -10 { particles[i].x = size.width + 10 }
            if particles[i].x > size.width + 10 { particles[i].x = -10 }
            if particles[i].y < -10 { particles[i].y = size.height + 10 }
            if particles[i].y > size.height + 10 { particles[i].y = -10 }
        }
    }
}
