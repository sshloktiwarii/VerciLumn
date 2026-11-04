import SwiftUI

public enum LyricStyle: String, CaseIterable, Identifiable {
    case verciReel = "Verci Kinetic Reel (Official)"
    case neonHorizon = "Neon Horizon (3D Perspective)"
    case cyberpunk = "Cyberpunk Telemetry"
    case cinematicStack = "Cinematic Crossfade Stack"
    
    public var id: String { self.rawValue }
}

public struct VerciLyricsView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
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
        
        ZStack {
            if lines.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 48 * textScale))
                        .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.4))
                    Text(lyrics.isLoading ? "Fetching synchronized lyrics..." : (playback.currentTrack.isPlaying ? "Instrumental or lyrics unavailable" : "Play music in Spotify or Apple Music"))
                        .font(.system(size: 20 * textScale, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            } else {
                switch style {
                case .verciReel:
                    verciKineticReelView(lines: lines, activeLineIdx: activeLineIndex, currentTime: currentTime)
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
    
    // MARK: - Style 1: Verci Kinetic Reel (Full Screen Scaling)
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
        let symbol = WordIconMapper.shared.symbol(for: currentWord.text)
        
        let activeFontSize = 84.0 * textScale
        let secondaryFontSize = 42.0 * textScale
        
        return AnyView(
            VStack(spacing: 32 * textScale) {
                // Previous Word
                if let prev = prevWord {
                    Text(prev.text)
                        .font(.system(size: secondaryFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                
                // Active Center Word (Giant Billboard with Sticker Block)
                HStack(spacing: 20 * textScale) {
                    if let icon = symbol {
                        Image(systemName: icon)
                            .font(.system(size: activeFontSize * 0.65, weight: .black))
                            .foregroundColor(palette.currentPalette.highlightAccent)
                    }
                    
                    Text(currentWord.text)
                        .font(.system(size: activeFontSize, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36 * textScale)
                        .padding(.vertical, 14 * textScale)
                        .background(
                            RoundedRectangle(cornerRadius: 16 * textScale, style: .continuous)
                                .fill(palette.currentPalette.highlightAccent.opacity(0.88))
                                .shadow(color: palette.currentPalette.highlightAccent.opacity(0.6), radius: 24 * textScale, x: 0, y: 8)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: currentWord.id)
                
                // Next Word
                if let next = nextWord {
                    HStack(spacing: 12) {
                        if let nextIcon = WordIconMapper.shared.symbol(for: next.text) {
                            Image(systemName: nextIcon)
                                .font(.system(size: secondaryFontSize * 0.6, weight: .bold))
                                .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.3))
                        }
                        Text(next.text)
                            .font(.system(size: secondaryFontSize, weight: .bold, design: .rounded))
                            .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.35))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: activeWordIdx)
        )
    }
    
    // MARK: - Style 2: Neon Horizon (3D Perspective)
    private func neonHorizonView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        let baseFontSize = 46.0 * textScale
        
        return VStack(spacing: 30 * textScale) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 3), id: \.self) { idx in
                let line = lines[idx]
                let distance = idx - activeIndex
                let isActive = distance == 0
                
                Text(line.fullText)
                    .font(.system(size: baseFontSize, weight: isActive ? .black : .bold, design: .rounded))
                    .foregroundColor(isActive ? palette.currentPalette.highlightAccent : .white.opacity(0.25))
                    .shadow(color: isActive ? palette.currentPalette.highlightAccent.opacity(0.7) : .clear, radius: 20 * textScale)
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
    
    // MARK: - Style 3: Cyberpunk Telemetry
    private func cyberpunkView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        let currentLine = lines[activeIndex]
        let activeFontSize = 52.0 * textScale
        
        return VStack(spacing: 20 * textScale) {
            Text("// AUDIO_TRACK //")
                .font(.system(size: 13 * textScale, weight: .bold, design: .monospaced))
                .foregroundColor(palette.currentPalette.secondaryGlow.opacity(0.7))
                .tracking(4)
            
            HStack(spacing: 12) {
                Text("[")
                    .font(.system(size: activeFontSize, weight: .black, design: .monospaced))
                    .foregroundColor(palette.currentPalette.highlightAccent)
                
                Text(currentLine.fullText.uppercased())
                    .font(.system(size: activeFontSize, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .shadow(color: palette.currentPalette.highlightAccent.opacity(0.7), radius: 15)
                
                Text("]")
                    .font(.system(size: activeFontSize, weight: .black, design: .monospaced))
                    .foregroundColor(palette.currentPalette.highlightAccent)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeIndex)
        }
    }
    
    // MARK: - Style 4: Cinematic Crossfade Stack
    private func cinematicStackView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        let baseFontSize = 48.0 * textScale
        
        return VStack(spacing: 28 * textScale) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                
                Text(line.fullText)
                    .font(.system(size: isActive ? baseFontSize : baseFontSize * 0.65, weight: isActive ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(isActive ? .white : .white.opacity(0.28))
                    .shadow(color: isActive ? palette.currentPalette.highlightAccent.opacity(0.5) : .clear, radius: 16)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: activeIndex)
            }
        }
    }
}
