import SwiftUI

public enum LyricStyle: String, CaseIterable, Identifiable {
    case verciReel = "Verci Kinetic Reel (Official)"
    case standard = "Standard Stack"
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
                    Text(lyrics.isLoading ? "Fetching time-synced lyrics..." : (playback.currentTrack.isPlaying ? "Instrumental or lyrics unavailable" : "Play music in Spotify or Apple Music"))
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
                    fisheyeView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                case .visual:
                    visualModeView(lines: lines, activeIndex: activeLineIndex, currentTime: currentTime)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Style 0: Verci Kinetic Reel (Matches verci-hero.mp4)
    private func verciKineticReelView(lines: [LyricLine], activeLineIdx: Int, currentTime: TimeInterval) -> some View {
        // Flatten all words across nearby lines into a chronological word stream
        let allWords: [WordToken] = lines.flatMap { $0.words }
        guard !allWords.isEmpty else {
            return AnyView(EmptyView())
        }
        
        // Find active word index via binary search
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
            VStack(spacing: 24) {
                // 1. Previous Word (Receding upwards, smaller, dimmed)
                if let prev = prevWord {
                    Text(prev.text)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.45))
                        .opacity(0.4)
                        .scaleEffect(0.85)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // 2. Active Center Word (Giant, encased in sticker block with dynamic icon)
                HStack(spacing: 16) {
                    if let icon = symbol {
                        Image(systemName: icon)
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(palette.currentPalette.highlightAccent)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Text(currentWord.text)
                        .font(.system(size: 84, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.currentPalette.highlightAccent.opacity(0.85))
                                .shadow(color: palette.currentPalette.highlightAccent.opacity(0.5), radius: 16, x: 0, y: 6)
                        )
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: currentWord.id)
                
                // 3. Next Word (Approaching from bottom, dimmed)
                if let next = nextWord {
                    HStack(spacing: 12) {
                        if let nextIcon = WordIconMapper.shared.symbol(for: next.text) {
                            Image(systemName: nextIcon)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.3))
                        }
                        Text(next.text)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(palette.currentPalette.highlightAccent.opacity(0.5))
                    }
                    .opacity(0.4)
                    .scaleEffect(0.85)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: activeWordIdx)
        )
    }
    
    // MARK: - Style 1: Standard Stack
    private func standardStackView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(alignment: .center, spacing: 20) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                
                HStack(spacing: 8) {
                    ForEach(line.words) { word in
                        let isWordActive = isActive && (currentTime >= word.timestamp)
                        Text(word.text)
                            .font(.system(size: isActive ? 34 : 22, weight: isActive ? .black : .medium, design: .rounded))
                            .foregroundColor(isWordActive ? palette.currentPalette.highlightAccent : (isActive ? .white : .white.opacity(0.35)))
                            .shadow(color: isWordActive ? palette.currentPalette.highlightAccent.opacity(0.6) : .clear, radius: 10)
                            .animation(.easeOut(duration: 0.15), value: isWordActive)
                    }
                }
                .scaleEffect(isActive ? 1.05 : 0.95)
                .opacity(isActive ? 1.0 : 0.4)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeIndex)
            }
        }
    }
    
    // MARK: - Style 2: Ship (3D Perspective)
    private func shipPerspectiveView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(alignment: .center, spacing: 28) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 3), id: \.self) { idx in
                let line = lines[idx]
                let distance = idx - activeIndex
                let isActive = distance == 0
                
                HStack(spacing: 8) {
                    ForEach(line.words) { word in
                        let isWordActive = isActive && (currentTime >= word.timestamp)
                        Text(word.text)
                            .font(.system(size: 32, weight: isActive ? .heavy : .semibold, design: .rounded))
                            .foregroundColor(isWordActive ? palette.currentPalette.highlightAccent : (isActive ? .white : .white.opacity(0.3)))
                    }
                }
                .rotation3DEffect(
                    .degrees(Double(distance) * -18),
                    axis: (x: 1.0, y: 0.0, z: 0.0),
                    anchor: .center,
                    perspective: 0.6
                )
                .scaleEffect(max(0.6, 1.0 - (Double(distance) * 0.15)))
                .offset(y: Double(distance) * 12)
                .opacity(max(0.15, 1.0 - (abs(Double(distance)) * 0.3)))
                .animation(.easeInOut(duration: 0.35), value: activeIndex)
            }
        }
    }
    
    // MARK: - Style 3: Fisheye Lens
    private func fisheyeView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(alignment: .center, spacing: 22) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                let activeWordIdx = lyrics.currentLyrics.activeWordIndex(in: idx, at: currentTime) ?? 0
                
                HStack(spacing: 10) {
                    ForEach(Array(line.words.enumerated()), id: \.element.id) { (wIdx, word) in
                        let isWordActive = isActive && (wIdx == activeWordIdx)
                        let distFromCenter = abs(wIdx - activeWordIdx)
                        let fisheyeScale = isActive ? max(1.0, 1.6 - (CGFloat(distFromCenter) * 0.22)) : 0.9
                        
                        Text(word.text)
                            .font(.system(size: 30, weight: isWordActive ? .black : .bold, design: .rounded))
                            .foregroundColor(isWordActive ? palette.currentPalette.highlightAccent : (isActive ? .white : .white.opacity(0.3)))
                            .scaleEffect(fisheyeScale)
                            .shadow(color: isWordActive ? palette.currentPalette.highlightAccent.opacity(0.7) : .clear, radius: 12)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: activeWordIdx)
                    }
                }
                .opacity(isActive ? 1.0 : 0.4)
            }
        }
    }
    
    // MARK: - Style 4: Visual Mode
    private func visualModeView(lines: [LyricLine], activeIndex: Int, currentTime: TimeInterval) -> some View {
        VStack(alignment: .center, spacing: 22) {
            ForEach(max(0, activeIndex - 2)...min(lines.count - 1, activeIndex + 2), id: \.self) { idx in
                let line = lines[idx]
                let isActive = idx == activeIndex
                
                HStack(spacing: 10) {
                    ForEach(line.words) { word in
                        let isWordActive = isActive && (currentTime >= word.timestamp)
                        let symbol = WordIconMapper.shared.symbol(for: word.text)
                        
                        HStack(spacing: 4) {
                            Text(word.text)
                                .font(.system(size: isActive ? 32 : 22, weight: isActive ? .black : .medium, design: .rounded))
                                .foregroundColor(isWordActive ? palette.currentPalette.highlightAccent : (isActive ? .white : .white.opacity(0.35)))
                            
                            if let icon = symbol, isWordActive {
                                Image(systemName: icon)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(palette.currentPalette.secondaryGlow)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                .scaleEffect(isActive ? 1.05 : 0.95)
                .opacity(isActive ? 1.0 : 0.4)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeIndex)
            }
        }
    }
}
