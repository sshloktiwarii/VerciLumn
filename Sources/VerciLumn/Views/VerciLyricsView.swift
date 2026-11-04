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
    
    var style: LyricStyle = .verciReel
    var timingOffset: Double = 0.0
    var textScale: Double = 1.0
    
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
        
        ZStack {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Style 1: Verci Kinetic Reel (Official Reel with Semantic Word VFX)
    private func verciKineticReelView(lines: [LyricLine], activeLineIdx: Int, currentTime: TimeInterval) -> some View {
        let allWords: [WordToken] = lines.flatMap { $0.words }
        guard !allWords.isEmpty else {
            return AnyView(EmptyView())
        }
        
        var low = 0
        var high = allWords.count - 1
        var activeWordIdx = 0
        while low <= high {
            let mid = (low + high) / 2
            if allWords[mid].timestamp <= currentTime {
                activeWordIdx = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        let prevWord = activeWordIdx > 0 ? allWords[activeWordIdx - 1] : nil
        let currentWord = allWords[activeWordIdx]
        let nextWord = (activeWordIdx + 1 < allWords.count) ? allWords[activeWordIdx + 1] : nil
        
        let activeFontSize = 82.0 * textScale
        let secondaryFontSize = 38.0 * textScale
        let activeColor = theme.activePalette.highlightAccent
        
        return AnyView(
            ZStack {
                // Liquid Audio Waveform Ring Pulsing in the background
                LiquidWaveformRingView(size: 380 * textScale)
                    .opacity(0.35)
                
                VStack(spacing: 30 * textScale) {
                    // Previous Word (Fading upward)
                    if let prev = prevWord {
                        Text(prev.text)
                            .font(.system(size: secondaryFontSize, weight: .bold, design: theme.currentTypography.design))
                            .foregroundColor(activeColor.opacity(0.35))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    
                    // Active Semantic Word VFX (Typography, bespoke badge, particle bursts)
                    SemanticWordView(
                        word: currentWord.text,
                        fontSize: activeFontSize,
                        accentColor: activeColor,
                        beatIntensity: audio.beatIntensity
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: currentWord.id)
                    
                    // Next Word (Approaching)
                    if let next = nextWord {
                        HStack(spacing: 10) {
                            if let nextIcon = WordIconMapper.shared.symbol(for: next.text) {
                                Image(systemName: nextIcon)
                                    .font(.system(size: secondaryFontSize * 0.6, weight: .bold))
                                    .foregroundColor(activeColor.opacity(0.3))
                            }
                            Text(next.text)
                                .font(.system(size: secondaryFontSize, weight: .bold, design: theme.currentTypography.design))
                                .foregroundColor(activeColor.opacity(0.35))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: activeWordIdx)
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
                
                Text(line.fullText)
                    .font(.system(size: baseFontSize, weight: isActive ? .black : .bold, design: theme.currentTypography.design))
                    .foregroundColor(isActive ? activeColor : .white.opacity(0.25))
                    .shadow(color: isActive ? activeColor.opacity(0.7) : .clear, radius: 20 * textScale)
                    .rotation3DEffect(
                        .degrees(Double(distance) * -16),
                        axis: (x: 1.0, y: 0.0, z: 0.0),
                        anchor: .center,
                        perspective: 0.5
                    )
                    .opacity(max(0.12, 1.0 - (abs(Double(distance)) * 0.28)))
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
                
                Text(line.fullText)
                    .font(.system(size: isActive ? baseFontSize : baseFontSize * 0.65, weight: isActive ? .heavy : .semibold, design: theme.currentTypography.design))
                    .foregroundColor(isActive ? .white : .white.opacity(0.28))
                    .shadow(color: isActive ? activeColor.opacity(0.5) : .clear, radius: 16)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: activeIndex)
            }
        }
    }
}
