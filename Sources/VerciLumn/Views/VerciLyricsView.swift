import SwiftUI

public enum LyricStyle: String, CaseIterable, Identifiable {
    case verciReel = "Verci Kinetic Reel (Official)"
    case standard = "Standard Stack (Multi-Line)"
    case ship = "Ship (3D Perspective)"
    case fisheye = "Fisheye Lens"
    case visual = "Visual Mode"
    
    public var id: String { self.rawValue }
}

public struct VerciLyricsView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
    var style: LyricStyle = .verciReel
    var timingOffset: Double = 0.0
    
    public init(style: LyricStyle = .verciReel, timingOffset: Double = 0.0) {
        self.style = style
        self.timingOffset = timingOffset
    }
    
    public var body: some View {
        let currentTime = playback.currentTrack.exactPosition(withOffset: timingOffset)
        let lines = lyrics.currentLyrics.lines
        let activeLineIndex = lyrics.currentLyrics.activeLineIndex(at: currentTime) ?? 0
        
        ZStack {
            if lines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text(lyrics.isLoading ? "Fetching synchronized lyrics..." : (playback.currentTrack.isPlaying ? "Instrumental or lyrics unavailable" : "Play music in Spotify or Apple Music"))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                switch style {
                case .verciReel:
                    verciKineticReelView(lines: lines, activeLineIdx: activeLineIndex, currentTime: currentTime)
                case .standard:
                    standardStackView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                case .ship:
                    shipPerspectiveView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                case .fisheye:
                    fisheyeLensView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                case .visual:
                    visualModeView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Style 0: Verci Kinetic Reel (Matches verci-hero.mp4)
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
        
        return AnyView(
            VStack(spacing: 28) {
                // Previous Word
                if let prev = prevWord {
                    Text(prev.text)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                // Active Center Word
                HStack(spacing: 16) {
                    if let icon = symbol {
                        Image(systemName: icon)
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(palette.currentPalette.highlightAccent)
                    }
                    
                    Text(currentWord.text)
                        .font(.system(size: 76, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.currentPalette.highlightAccent.opacity(0.85))
                                .shadow(color: palette.currentPalette.highlightAccent.opacity(0.55), radius: 18, x: 0, y: 6)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: currentWord.id)
                
                // Next Word
                if let next = nextWord {
                    HStack(spacing: 12) {
                        if let nextIcon = WordIconMapper.shared.symbol(for: next.text) {
                            Image(systemName: nextIcon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.3))
                        }
                        Text(next.text)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.4))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: activeWordIdx)
        )
    }
    
    // MARK: - Style 1: Standard Stack (Clean, No Collisions)
    private func standardStackView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(spacing: 24) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                
                Text(line.fullText)
                    .font(.system(size: isActive ? 44 : 26, weight: isActive ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(isActive ? .white : .white.opacity(0.3))
                    .shadow(color: isActive ? palette.currentPalette.highlightAccent.opacity(0.4) : .clear, radius: 12)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 32)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: activeIndex)
            }
        }
    }
    
    // MARK: - Style 2: Ship (3D Perspective)
    private func shipPerspectiveView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(spacing: 26) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 3), id: \.self) { idx in
                let line = lines[idx]
                let distance = idx - activeIndex
                let isActive = distance == 0
                
                Text(line.fullText)
                    .font(.system(size: 38, weight: isActive ? .black : .semibold, design: .rounded))
                    .foregroundColor(isActive ? palette.currentPalette.highlightAccent : .white.opacity(0.28))
                    .rotation3DEffect(
                        .degrees(Double(distance) * -16),
                        axis: (x: 1.0, y: 0.0, z: 0.0),
                        anchor: .center,
                        perspective: 0.55
                    )
                    .opacity(max(0.15, 1.0 - (abs(Double(distance)) * 0.28)))
                    .animation(.easeInOut(duration: 0.3), value: activeIndex)
            }
        }
    }
    
    // MARK: - Style 3: Fisheye Lens (Smooth Contrast, No Horizontal Scale Collisions)
    private func fisheyeLensView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(spacing: 22) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                
                HStack(spacing: 8) {
                    ForEach(line.words) { word in
                        let isWordActive = isActive && (currentTime >= word.timestamp)
                        Text(word.text)
                            .font(.system(size: isActive ? (isWordActive ? 36 : 30) : 22, weight: isWordActive ? .black : (isActive ? .bold : .medium), design: .rounded))
                            .foregroundColor(isWordActive ? palette.currentPalette.highlightAccent : (isActive ? .white : .white.opacity(0.3)))
                            .shadow(color: isWordActive ? palette.currentPalette.highlightAccent.opacity(0.65) : .clear, radius: 10)
                    }
                }
                .opacity(isActive ? 1.0 : 0.35)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: activeIndex)
            }
        }
    }
    
    // MARK: - Style 4: Visual Mode
    private func visualModeView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(spacing: 24) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                
                HStack(spacing: 8) {
                    ForEach(line.words) { word in
                        let isWordActive = isActive && (currentTime >= word.timestamp)
                        let symbol = WordIconMapper.shared.symbol(for: word.text)
                        
                        HStack(spacing: 4) {
                            Text(word.text)
                                .font(.system(size: isActive ? (isWordActive ? 34 : 28) : 22, weight: isWordActive ? .black : (isActive ? .bold : .medium), design: .rounded))
                                .foregroundColor(isWordActive ? palette.currentPalette.highlightAccent : (isActive ? .white : .white.opacity(0.35)))
                            
                            if let icon = symbol, isWordActive {
                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(palette.currentPalette.secondaryGlow)
                            }
                        }
                    }
                }
                .opacity(isActive ? 1.0 : 0.35)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeIndex)
            }
        }
    }
}
