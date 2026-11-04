import SwiftUI

public enum LyricStyle: String, CaseIterable, Identifiable {
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
    
    var style: LyricStyle = .standard
    
    public init(style: LyricStyle = .standard) {
        self.style = style
    }
    
    public var body: some View {
        let currentTime = playback.currentTrack.exactPosition
        let activeLineIndex = lyrics.currentLyrics.activeLineIndex(at: currentTime) ?? 0
        let lines = lyrics.currentLyrics.lines
        
        ZStack {
            if lines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.4))
                    Text(lyrics.isLoading ? "Fetching synchronized lyrics..." : (playback.currentTrack.isPlaying ? "No lyrics available for this track" : "Play music in Spotify or Apple Music"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                switch style {
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
        .frame(maxWidth: 800, maxHeight: 500)
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
    
    // MARK: - Style 4: Visual Mode (Word + SF Symbol / Emoji Pop)
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
