import SwiftUI

final class ContinuousTunnelPhase {
    var accumulatedPhase: Double = 0.0
    var lastTimestamp: Double = 0.0
    
    func advance(time: Double, beat: Double, energy: Double) -> (phase: Double, rotation: Double) {
        guard !time.isNaN && !time.isInfinite else { return (accumulatedPhase, accumulatedPhase * 0.05) }
        let safeBeat = (!beat.isNaN && !beat.isInfinite) ? max(0.0, beat) : 0.0
        let safeEnergy = (!energy.isNaN && !energy.isInfinite) ? max(0.0, energy) : 0.0
        
        if lastTimestamp == 0.0 {
            lastTimestamp = time
        }
        let dt = min(max(time - lastTimestamp, 0.0), 0.05)
        lastTimestamp = time
        
        // Dynamic BPM-reactive forward rush:
        // Base cruise speed 1.35 + accelerates up to 3.8 on kicks, bass drops & high audio energy
        let speed = 1.35 + (safeBeat * 2.0) + (safeEnergy * 0.9)
        accumulatedPhase += dt * speed
        
        // Bounded float protection for multi-day uninterrupted playback
        if accumulatedPhase > 100_000.0 {
            accumulatedPhase = accumulatedPhase.truncatingRemainder(dividingBy: 10_000.0)
        }
        
        let rotation = accumulatedPhase * 0.05
        return (accumulatedPhase, rotation)
    }
}

public struct InfiniteZoomTunnelView: View {
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var phaseTracker = ContinuousTunnelPhase()
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            TimelineView(
                .animation(paused: !playback.currentTrack.isPlaying)
            ) { timeline in
                Canvas { context, size in
                    guard playback.currentTrack.isPlaying else { return }
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let beat = Double(audio.beatIntensity)
                    let energy = Double(spectrum.overallEnergy)
                    
                    let (phase, rotation) = phaseTracker.advance(time: now, beat: beat, energy: energy)
                    drawTunnel(
                        context: context,
                        size: size,
                        phase: phase,
                        rotation: rotation,
                        beat: CGFloat(beat),
                        energy: CGFloat(energy)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .background(Color.clear)
    }
    
    private func drawTunnel(
        context: GraphicsContext,
        size: CGSize,
        phase: Double,
        rotation: Double,
        beat: CGFloat,
        energy: CGFloat
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = max(size.width, size.height) * 0.95
        
        let palette = theme.activePalette
        let primaryColor = palette.highlightAccent
        let secondaryColor = palette.secondaryGlow
        let beatPulse = 1.0 + (beat * 0.08)
        
        // 1. Draw 8 Sacred Perspective Velocity Rays (Vanishing Point outward)
        var rayPath = Path()
        let rayAlpha = Double(0.12 + (beat * 0.22) + (energy * 0.12))
        for rIdx in 0..<8 {
            let angle = rotation + (Double(rIdx) / 8.0 * 2.0 * .pi)
            let endX = center.x + maxRadius * CGFloat(cos(angle))
            let endY = center.y + maxRadius * CGFloat(sin(angle))
            rayPath.move(to: center)
            rayPath.addLine(to: CGPoint(x: endX, y: endY))
        }
        context.stroke(
            rayPath,
            with: .color(secondaryColor.opacity(rayAlpha)),
            lineWidth: 1.0 + (beat * 1.5)
        )
        
        // 2. Dense Continuous Sacred Octagonal Rings (Tight Logarithmic Flow)
        // 24 concentric layers with 1.28 ratio eliminate discrete steps and create continuous warp velocity
        let layerCount = 24
        let zoomBase: Double = 1.28
        let loopProgress = phase.truncatingRemainder(dividingBy: 1.0)
        
        for i in 0..<layerCount {
            let depth = Double(i) + loopProgress
            let rawScale = pow(zoomBase, depth) * 4.5 * Double(beatPulse)
            let scale = CGFloat(rawScale)
            
            guard scale > 6 && scale < maxRadius * 2.2 else { continue }
            
            let norm = CGFloat(scale / maxRadius)
            
            // Seamless hermite fade envelope: zero pop-in at vanishing center, gentle dissolve at perimeter
            let centerFade = min(max((scale - 8) / 45.0, 0.0), 1.0)
            let edgeFade = max(0.0, 1.0 - pow(norm / 1.55, 2.0))
            let envelopeAlpha = Double(centerFade * edgeFade)
            
            let finalAlpha = envelopeAlpha * (0.32 + Double(beat) * 0.42 + Double(energy) * 0.2)
            guard finalAlpha > 0.01 else { continue }
            
            // Choose color from theme palette
            let strokeColor: Color
            if palette.isRainbow {
                let colorIdx = (i + Int(phase * 0.8)) % palette.rainbowGradient.count
                strokeColor = palette.rainbowGradient[colorIdx]
            } else {
                strokeColor = (i % 2 == 0) ? primaryColor : secondaryColor
            }
            
            let strokeWidth: CGFloat = 1.2 + (beat * 2.2) + (norm * 1.6)
            
            // Symmetric Regular Octagon Ring
            let octagon = regularPolygonPath(center: center, radius: scale, sides: 8, rotation: rotation)
            context.stroke(
                octagon,
                with: .color(strokeColor.opacity(finalAlpha)),
                lineWidth: strokeWidth
            )
            
            // Inscribed Diamond Lattice Ring (Sacred geometric depth & cross-facets)
            if scale > 24 && i % 2 == 0 {
                let diamondScale = scale * 0.7071
                let diamond = regularPolygonPath(center: center, radius: diamondScale, sides: 8, rotation: rotation + (.pi / 8.0))
                context.stroke(
                    diamond,
                    with: .color(secondaryColor.opacity(finalAlpha * 0.5)),
                    lineWidth: max(0.8, strokeWidth * 0.55)
                )
            }
            
            // Luminous Node Gemstones at Octagonal Vertices on Major Rings
            if scale > 40 && scale < maxRadius * 1.1 && i % 2 == 0 {
                let gemRadius = CGFloat(1.5 + (beat * 2.2))
                for v in 0..<8 {
                    let vAngle = rotation + (Double(v) / 8.0 * 2.0 * .pi)
                    let vx = center.x + scale * CGFloat(cos(vAngle))
                    let vy = center.y + scale * CGFloat(sin(vAngle))
                    let gemRect = CGRect(x: vx - gemRadius, y: vy - gemRadius, width: gemRadius * 2, height: gemRadius * 2)
                    context.fill(
                        Circle().path(in: gemRect),
                        with: .color(primaryColor.opacity(finalAlpha * 0.9))
                    )
                }
            }
        }
    }
    
    // MARK: - Regular Polygon Generator
    private func regularPolygonPath(center: CGPoint, radius: CGFloat, sides: Int, rotation: Double) -> Path {
        var path = Path()
        guard sides >= 3 else { return path }
        
        for i in 0..<sides {
            let angle = rotation + (Double(i) / Double(sides) * 2.0 * .pi)
            let x = center.x + radius * CGFloat(cos(angle))
            let y = center.y + radius * CGFloat(sin(angle))
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}


