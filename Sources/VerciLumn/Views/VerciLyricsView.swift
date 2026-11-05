import SwiftUI

public enum LyricStyle: String, CaseIterable, Identifiable {
    case verciReel = "Verci Kinetic Reel (Official)"
    case turntable = "3D Holographic Vinyl Turntable"
    case neonHorizon = "Neon Horizon (3D Perspective)"
    case cyberpunk = "Cyberpunk Telemetry"
    case cinematicStack = "Cinematic Crossfade Stack"
    
    public var id: String { self.rawValue }
}

public struct VerciLyricsView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    var style: LyricStyle = .verciReel
    var timingOffset: Double = 0.0
    var textScale: Double = 1.0
    
    @State private var hoveredLineIdx: Int? = nil
    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    
    public init(style: LyricStyle = .verciReel, timingOffset: Double = 0.0, textScale: Double = 1.0) {
        self.style = style
        self.timingOffset = timingOffset
        self.textScale = textScale
    }
    
    public var body: some View {
        let currentTime = playback.currentTrack.exactPosition(withOffset: timingOffset)
        let lines = lyrics.currentLyrics.lines
        let activeLineIndex = lyrics.currentLyrics.activeLineIndex(at: currentTime) ?? 0
        let activeColor = theme.activePalette.highlightAccent
        
        GeometryReader { geo in
            ZStack(alignment: .center) {
                // Main Lyric Visual Presentation
                Group {
                    if style == .turntable {
                        turntableModeView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                    } else if lines.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 48 * textScale))
                                .foregroundColor(activeColor.opacity(0.4))
                            Text(lyrics.isLoading ? "Fetching synchronized lyrics..." : (playback.currentTrack.isPlaying ? "Instrumental or lyrics unavailable" : "Play music in Spotify or Apple Music"))
                                .font(.system(size: 20 * textScale, weight: .medium, design: theme.currentTypography.design))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    } else {
                        switch style {
                        case .verciReel:
                            verciKineticReelView(lines: lines, activeLineIdx: activeLineIndex, currentTime: currentTime)
                        case .turntable:
                            EmptyView()
                        case .neonHorizon:
                            neonHorizonView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                        case .cyberpunk:
                            cyberpunkView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                        case .cinematicStack:
                            cinematicStackView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                        }
                    }
                }
                .modifier(
                    FisheyeModifier(
                        isEnabled: settings.isFisheyeShaderEnabled,
                        isPlaying: playback.currentTrack.isPlaying,
                        center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                        radius: 260 * Float(textScale),
                        strength: 0.8
                    )
                )
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .padding(.horizontal, 32)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let clamped = min(seconds, 359999)
        let mins = Int(clamped) / 60
        let secs = Int(clamped) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Style 1: Verci Kinetic Reel (Official Reel with Interactive Lines & Semantic Word VFX)
    private func verciKineticReelView(lines: [LyricLine], activeLineIdx: Int, currentTime: TimeInterval) -> some View {
        guard !lines.isEmpty, activeLineIdx >= 0, activeLineIdx < lines.count else {
            return AnyView(EmptyView())
        }
        
        let currentLine = lines[activeLineIdx]
        let prevLine = activeLineIdx > 0 ? lines[activeLineIdx - 1] : nil
        let nextLine = (activeLineIdx + 1 < lines.count) ? lines[activeLineIdx + 1] : nil
        
        let activeFontSize = min(56.0 * textScale, 72.0)
        let secondaryFontSize = min(22.0 * textScale, 28.0)
        let activeColor = theme.activePalette.highlightAccent
        
        return AnyView(
            ZStack {
                // Lightweight ambient ring with zero GPU canvas churn
                Circle()
                    .stroke(activeColor.opacity(0.15), lineWidth: 1.5)
                    .frame(width: min(320 * textScale, 400), height: min(320 * textScale, 400))
                    .allowsHitTesting(false)
                
                VStack(spacing: 16 * textScale) {
                    // 1. Previous Line (Click to Rewind)
                    if let prev = prevLine {
                        Button {
                            if settings.isInteractiveSeekEnabled {
                                playback.seekTo(seconds: prev.timestamp)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gobackward.5")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(hoveredLineIdx == -1 ? activeColor : activeColor.opacity(0.45))
                                
                                Text(prev.fullText)
                                    .font(.system(size: secondaryFontSize, weight: .medium, design: theme.currentTypography.design))
                                    .foregroundColor(hoveredLineIdx == -1 ? Color.white : activeColor.opacity(0.45))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(hoveredLineIdx == -1 ? Color.white.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            hoveredLineIdx = isHovered ? -1 : nil
                            if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        .help("Click to rewind to this line (\(formatTime(prev.timestamp)))")
                    } else {
                        // Maintain vertical balance if at song start
                        Spacer().frame(height: secondaryFontSize + 12)
                    }
                    
                    // 2. Active Singing Line (Center Stage with Word Highlighting & VFX)
                    if !currentLine.words.isEmpty {
                        HStack(spacing: 10 * textScale) {
                            ForEach(currentLine.words) { word in
                                let isCurrentWord = (currentTime >= word.timestamp && currentTime < word.timestamp + word.duration)
                                let isPastWord = currentTime >= word.timestamp + word.duration
                                
                                Button {
                                    if settings.isInteractiveSeekEnabled {
                                        playback.seekTo(seconds: word.timestamp)
                                    }
                                } label: {
                                    if isCurrentWord && WordSemanticEngine.shared.isEnabled {
                                        SemanticWordView(
                                            word: word.text,
                                            fontSize: activeFontSize,
                                            accentColor: activeColor,
                                            beatIntensity: audio.beatIntensity,
                                            cachedStyle: word.semanticStyle,
                                            cachedIcon: word.iconSymbol,
                                            onTap: {
                                                if settings.isInteractiveSeekEnabled {
                                                    playback.seekTo(seconds: word.timestamp)
                                                }
                                            }
                                        )
                                    } else {
                                        Text(word.text)
                                            .font(.system(
                                                size: isCurrentWord ? activeFontSize : activeFontSize * 0.92,
                                                weight: isCurrentWord ? .black : (isPastWord ? .bold : .medium),
                                                design: theme.currentTypography.design
                                            ))
                                            .foregroundColor(isCurrentWord ? activeColor : (isPastWord ? Color.white : Color.white.opacity(0.38)))
                                            .shadow(color: isCurrentWord ? activeColor.opacity(0.8) : .clear, radius: 14)
                                    }
                                }
                                .buttonStyle(.plain)
                                .onHover { isHovered in
                                    if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Plain line fallback if word timestamps are unassigned
                        Button {
                            if settings.isInteractiveSeekEnabled {
                                playback.seekTo(seconds: currentLine.timestamp)
                            }
                        } label: {
                            Text(currentLine.fullText)
                                .font(.system(size: activeFontSize, weight: .black, design: theme.currentTypography.design))
                                .foregroundColor(activeColor)
                                .shadow(color: activeColor.opacity(0.7), radius: 16)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 3. Next Line (Click to Skip Forward)
                    if let next = nextLine {
                        Button {
                            if settings.isInteractiveSeekEnabled {
                                playback.seekTo(seconds: next.timestamp)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(next.fullText)
                                    .font(.system(size: secondaryFontSize, weight: .medium, design: theme.currentTypography.design))
                                    .foregroundColor(hoveredLineIdx == 1 ? Color.white : activeColor.opacity(0.4))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                
                                Image(systemName: "goforward.5")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(hoveredLineIdx == 1 ? activeColor : activeColor.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(hoveredLineIdx == 1 ? Color.white.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            hoveredLineIdx = isHovered ? 1 : nil
                            if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        .help("Click to skip ahead to this line (\(formatTime(next.timestamp)))")
                    } else {
                        // Maintain vertical balance if at song end
                        Spacer().frame(height: secondaryFontSize + 12)
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: activeLineIdx)
            }
        )
    }
    
    // MARK: - Style 2: 3D Holographic Vinyl Turntable Mode
    private func turntableModeView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VinylTurntableView(size: min(520 * textScale, 680))
    }
    
    // MARK: - Style 3: Neon Horizon (3D Perspective)
    private func neonHorizonView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        let baseFontSize = 46.0 * textScale
        let activeColor = theme.activePalette.highlightAccent
        
        return VStack(spacing: 28 * textScale) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 3), id: \.self) { idx in
                let line = lines[idx]
                let distance = idx - activeIndex
                let isActive = distance == 0
                let isHovered = hoveredLineIdx == idx
                
                Button {
                    if settings.isInteractiveSeekEnabled {
                        playback.seekTo(seconds: line.timestamp)
                    }
                } label: {
                    Text(line.fullText)
                        .font(.system(size: baseFontSize, weight: isActive ? .black : .bold, design: theme.currentTypography.design))
                        .foregroundColor(isActive ? activeColor : (isHovered ? .white.opacity(0.65) : .white.opacity(0.25)))
                        .shadow(color: isActive ? activeColor.opacity(0.7) : (isHovered ? activeColor.opacity(0.3) : .clear), radius: 20 * textScale)
                        .rotation3DEffect(
                            .degrees(Double(distance) * -16),
                            axis: (x: 1.0, y: 0.0, z: 0.0),
                            anchor: .center,
                            perspective: 0.5
                        )
                        .opacity(max(0.12, 1.0 - (abs(Double(distance)) * 0.28)))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredLineIdx = hovering ? idx : nil
                }
                .animation(.easeInOut(duration: 0.3), value: activeIndex)
            }
        }
    }
    
    // MARK: - Style 4: Cyberpunk Telemetry
    private func cyberpunkView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        let currentLine = lines[activeIndex]
        let activeFontSize = 50.0 * textScale
        let activeColor = theme.activePalette.highlightAccent
        
        return VStack(spacing: 20 * textScale) {
            Text("// SYSTEM_AUDIO_SYNC //")
                .font(.system(size: 13 * textScale, weight: .bold, design: .monospaced))
                .foregroundColor(theme.activePalette.secondaryGlow.opacity(0.7))
                .tracking(4)
            
            Button {
                if settings.isInteractiveSeekEnabled {
                    playback.seekTo(seconds: currentLine.timestamp)
                }
            } label: {
                HStack(spacing: 12) {
                    Text("[")
                        .font(.system(size: activeFontSize, weight: .black, design: .monospaced))
                        .foregroundColor(activeColor)
                    
                    Text(currentLine.fullText.uppercased())
                        .font(.system(size: activeFontSize, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .shadow(color: activeColor.opacity(0.7), radius: 15)
                    
                    Text("]")
                        .font(.system(size: activeFontSize, weight: .black, design: .monospaced))
                        .foregroundColor(activeColor)
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeIndex)
        }
    }
    
    // MARK: - Style 5: Cinematic Crossfade Stack
    private func cinematicStackView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        let baseFontSize = 48.0 * textScale
        let activeColor = theme.activePalette.highlightAccent
        
        return VStack(spacing: 28 * textScale) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                let isHovered = hoveredLineIdx == idx
                
                Button {
                    if settings.isInteractiveSeekEnabled {
                        playback.seekTo(seconds: line.timestamp)
                    }
                } label: {
                    Text(line.fullText)
                        .font(.system(size: isActive ? baseFontSize : baseFontSize * 0.65, weight: isActive ? .heavy : .semibold, design: theme.currentTypography.design))
                        .foregroundColor(isActive ? .white : (isHovered ? .white.opacity(0.65) : .white.opacity(0.28)))
                        .shadow(color: isActive ? activeColor.opacity(0.5) : (isHovered ? activeColor.opacity(0.3) : .clear), radius: 16)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredLineIdx = hovering ? idx : nil
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: activeIndex)
            }
        }
    }
}

// MARK: - Metal Fisheye Shader View Modifier
private struct FisheyeModifier: ViewModifier {
    let isEnabled: Bool
    let isPlaying: Bool
    let center: CGPoint
    let radius: Float
    let strength: Float
    
    func body(content: Content) -> some View {
        if isEnabled && isPlaying {
            content.distortionEffect(
                ShaderLibrary.bundle(.module).fisheyeDistortionEffect(
                    .float2(Float(center.x), Float(center.y)),
                    .float(radius),
                    .float(strength)
                ),
                maxSampleOffset: CGSize(width: 20, height: 20)
            )
        } else {
            content
        }
    }
}
