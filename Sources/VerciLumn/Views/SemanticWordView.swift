import SwiftUI

public struct SemanticWordView: View {
    let word: String
    let fontSize: CGFloat
    let accentColor: Color
    let beatIntensity: Float
    let cachedStyle: SemanticStyle?
    let cachedIcon: String?
    var onTap: (() -> Void)? = nil
    
    @ObservedObject var semanticEngine = WordSemanticEngine.shared
    @ObservedObject var playback = PlaybackManager.shared
    @State private var phase: CGFloat = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var isHovered: Bool = false
    
    public init(
        word: String,
        fontSize: CGFloat,
        accentColor: Color,
        beatIntensity: Float = 0.0,
        cachedStyle: SemanticStyle? = nil,
        cachedIcon: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.word = word
        self.fontSize = fontSize
        self.accentColor = accentColor
        self.beatIntensity = beatIntensity
        self.cachedStyle = cachedStyle
        self.cachedIcon = cachedIcon
        self.onTap = onTap
    }
    
    public var body: some View {
        // Zero live NLP: read directly from parse-time cache if available
        let style = cachedStyle ?? semanticEngine.evaluate(word: word)
        let icon = cachedIcon ?? WordIconMapper.shared.symbol(for: word)
        
        ZStack {
            // 1. Localized Micro-Particle Bursts & Auras
            if semanticEngine.isEnabled {
                particleLayer(for: style.particleType)
            }
            
            // 2. Active Word Text with bespoke Badge & Typography
            HStack(spacing: fontSize * 0.15) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: fontSize * 0.65, weight: style.fontWeight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: style.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else if style.mood != .defaultHarmonic {
                    Image(systemName: style.mood.icon)
                        .font(.system(size: fontSize * 0.55, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: style.primaryGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(word)
                    .font(.system(size: fontSize, weight: style.fontWeight, design: style.fontDesign))
                    .italic(style.isItalic)
                    .foregroundStyle(
                        style.mood == .impact ? AnyShapeStyle(Color.black) : AnyShapeStyle(Color.white)
                    )
            }
            .padding(.horizontal, fontSize * 0.42)
            .padding(.vertical, fontSize * 0.16)
            .background(badgeBackground(for: style))
            .offset(x: shakeOffset)
            .scaleEffect((1.0 + (CGFloat(beatIntensity) * 0.05)) * (isHovered ? 1.04 : 1.0))
            .shadow(color: isHovered ? accentColor.opacity(0.6) : .clear, radius: 12)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                onTap?()
            }
        }
        .onAppear {
            if style.shakeIntensity > 0 {
                withAnimation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)) {
                    shakeOffset = style.shakeIntensity
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    shakeOffset = 0
                }
            }
        }
    }
    
    @ViewBuilder
    private func badgeBackground(for style: SemanticStyle) -> some View {
        switch style.borderType {
        case .blazingGlow:
            RoundedRectangle(cornerRadius: fontSize * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.primaryGradient[0].opacity(0.92), style.primaryGradient[1].opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: style.glowColor.opacity(0.8), radius: fontSize * 0.35, x: 0, y: 0)
                
        case .kineticStreak:
            RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.primaryGradient[0].opacity(0.88), style.primaryGradient[1].opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: style.glowColor.opacity(0.7), radius: fontSize * 0.28, x: -6, y: 0)
                
        case .softPill:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [style.primaryGradient[0].opacity(0.9), style.primaryGradient[1].opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: style.glowColor.opacity(0.6), radius: fontSize * 0.25, x: 0, y: 4)
                
        case .frostedGlass:
            RoundedRectangle(cornerRadius: fontSize * 0.2, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: fontSize * 0.2, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white, style.glowColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: style.glowColor.opacity(0.55), radius: fontSize * 0.28, x: 0, y: 0)
                
        case .metallicGold:
            RoundedRectangle(cornerRadius: fontSize * 0.2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.primaryGradient[0], style.primaryGradient[1]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: fontSize * 0.2, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                )
                .shadow(color: style.glowColor.opacity(0.75), radius: fontSize * 0.32, x: 0, y: 4)
                
        case .invertedBlock:
            RoundedRectangle(cornerRadius: fontSize * 0.16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.white.opacity(0.85), radius: fontSize * 0.38, x: 0, y: 0)
                
        case .cosmicAura:
            RoundedRectangle(cornerRadius: fontSize * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.primaryGradient[0].opacity(0.85), style.primaryGradient[1].opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: style.glowColor.opacity(0.8), radius: fontSize * 0.4, x: 0, y: 0)
                
        case .standardAccent:
            let palette = ThemeManager.shared.activePalette
            if palette.isRainbow {
                RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                    .fill(LinearGradient(colors: palette.rainbowGradient, startPoint: .leading, endPoint: .trailing).opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                            .stroke(palette.highlightAccent.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: palette.highlightAccent.opacity(0.35), radius: fontSize * 0.2, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                    .fill(accentColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: fontSize * 0.18, style: .continuous)
                            .stroke(accentColor.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: accentColor.opacity(0.3), radius: fontSize * 0.2, x: 0, y: 2)
            }
        }
    }
    
    @ViewBuilder
    private func particleLayer(for type: ParticleBurstType) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playback.currentTrack.isPlaying)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let count = Int(8 * semanticEngine.intensity)
                let w = size.width
                let h = size.height
                
                switch type {
                case .embers:
                    // Rising flame embers
                    for i in 0..<count {
                        let seed = Double(i)
                        let progress = (time * 1.5 + seed * 0.2).truncatingRemainder(dividingBy: 1.0)
                        let x = (w * 0.2) + (w * 0.6) * CGFloat(sin(seed * 4.3 + time))
                        let y = h - (h * CGFloat(progress) * 1.4)
                        let sz = CGFloat(4 + (i % 5)) * CGFloat(1.0 - progress)
                        
                        let rect = CGRect(x: x, y: y, width: sz, height: sz)
                        let emberColor = Color(red: 1.0, green: 0.35 + 0.4 * progress, blue: 0.05, opacity: 1.0 - progress)
                        context.fill(Path(ellipseIn: rect), with: .color(emberColor))
                    }
                    
                case .speedStreaks:
                    // High-velocity horizontal cyan streaks
                    for i in 0..<count {
                        let seed = Double(i)
                        let progress = (time * 2.2 + seed * 0.25).truncatingRemainder(dividingBy: 1.0)
                        let y = (h * 0.2) + (h * 0.6) * CGFloat(Double(i) / Double(count))
                        let x = w - (w * 1.4 * CGFloat(progress))
                        let len = CGFloat(30 + (i * 8))
                        
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + len, y: y))
                        context.stroke(path, with: .color(Color.cyan.opacity(0.7 * (1.0 - progress))), lineWidth: 2)
                    }
                    
                case .floatingHearts:
                    // Floating micro-hearts or rosy bubbles
                    for i in 0..<count {
                        let seed = Double(i)
                        let progress = (time * 0.9 + seed * 0.3).truncatingRemainder(dividingBy: 1.0)
                        let x = (w * 0.15) + (w * 0.7) * CGFloat((seed * 3.7).truncatingRemainder(dividingBy: 1.0))
                        let y = h - (h * 1.2 * CGFloat(progress))
                        let sz = CGFloat(6 + (i % 4))
                        
                        let rect = CGRect(x: x, y: y, width: sz, height: sz)
                        context.fill(Path(ellipseIn: rect), with: .color(Color.pink.opacity(0.65 * (1.0 - progress))))
                    }
                    
                case .shockwave:
                    // Expanding radial shockwave ring
                    let p = (time * 2.0).truncatingRemainder(dividingBy: 1.0)
                    let radius = (max(w, h) * 0.5) + (CGFloat(p) * 60 * CGFloat(semanticEngine.intensity))
                    let circleRect = CGRect(x: (w / 2) - radius, y: (h / 2) - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: circleRect), with: .color(Color.white.opacity(0.8 * (1.0 - p))), lineWidth: 3 * (1.0 - CGFloat(p)))
                    
                case .goldDust, .iceCrystals, .starTwinkle:
                    // Twinkling glints
                    for i in 0..<count {
                        let seed = Double(i)
                        let twinkle = abs(sin(time * 3.5 + seed * 2.0))
                        let x = (w * 0.1) + (w * 0.8) * CGFloat((seed * 1.9).truncatingRemainder(dividingBy: 1.0))
                        let y = (h * 0.1) + (h * 0.8) * CGFloat((seed * 3.1).truncatingRemainder(dividingBy: 1.0))
                        let sz = CGFloat(4 + (i % 4)) * CGFloat(twinkle)
                        
                        let rect = CGRect(x: x, y: y, width: sz, height: sz)
                        let clr: Color = (type == .goldDust) ? Color(red: 1.0, green: 0.85, blue: 0.2) : (type == .iceCrystals ? Color.cyan : Color.white)
                        context.fill(Path(ellipseIn: rect), with: .color(clr.opacity(0.85 * twinkle)))
                    }
                    
                case .subtleRhythm:
                    break
                }
            }
        }
        .frame(minWidth: fontSize * 3.0, minHeight: fontSize * 1.8)
        .allowsHitTesting(false)
    }
}

