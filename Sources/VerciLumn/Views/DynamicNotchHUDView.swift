import SwiftUI
import AppKit

public struct DynamicNotchHUDView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var spectrum = AudioSpectrumEngine.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var isHovered: Bool = false
    @State private var isContextuallyVisible: Bool = false
    @State private var dismissWorkItem: DispatchWorkItem? = nil
    @State private var lastTrackId: String = ""
    
    public init() {}
    
    private var hasPhysicalNotch: Bool {
        if let screen = NSScreen.main {
            return screen.safeAreaInsets.top > 24 || screen.auxiliaryTopLeftArea != nil
        }
        return false
    }
    
    public var body: some View {
        let track = playback.currentTrack
        let activeColor = theme.activePalette.highlightAccent
        let currentTime = track.exactPosition(withOffset: settings.timingOffset)
        let activeLineIdx = lyrics.currentLyrics.activeLineIndex(at: currentTime) ?? 0
        let currentWordText = currentLyricWord(at: currentTime, activeLineIdx: activeLineIdx)
        let isVisible = isContextuallyVisible || isHovered
        
        ZStack {
            if isVisible {
                // Pill Container
                VStack(spacing: 0) {
                    if isHovered {
                        expandedHUD(track: track, activeColor: activeColor, currentWord: currentWordText)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))
                    } else {
                        compactHUD(track: track, activeColor: activeColor, currentWord: currentWordText)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, isHovered ? 18 : 12)
                .padding(.vertical, isHovered ? 12 : 6)
                .background(
                    RoundedRectangle(cornerRadius: hasPhysicalNotch ? (isHovered ? 20 : 14) : 22, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                        .background(
                            RoundedRectangle(cornerRadius: hasPhysicalNotch ? (isHovered ? 20 : 14) : 22, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: hasPhysicalNotch ? (isHovered ? 20 : 14) : 22, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            activeColor.opacity(isHovered ? 0.6 : 0.25),
                                            Color.white.opacity(0.12),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: isHovered ? activeColor.opacity(0.35) : Color.black.opacity(0.4), radius: isHovered ? 16 : 8, y: 4)
                )
                .frame(width: isHovered ? 430 : (hasPhysicalNotch ? 360 : 320), height: isHovered ? 78 : (hasPhysicalNotch ? 38 : 36))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -20)),
                    removal: .opacity.combined(with: .offset(y: -10))
                ))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.76), value: isHovered)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isContextuallyVisible)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isHovered = hovering
            }
            if hovering {
                dismissWorkItem?.cancel()
                dismissWorkItem = nil
            } else {
                scheduleDismissal(after: 2.0)
            }
        }
        .onReceive(playback.$currentTrack) { newTrack in
            let trackIdentifier = "\(newTrack.title)-\(newTrack.artist)-\(newTrack.isPlaying)"
            if trackIdentifier != lastTrackId {
                lastTrackId = trackIdentifier
                if newTrack.isPlaying {
                    triggerContextualDisplay()
                }
            }
        }
        .onAppear {
            if playback.currentTrack.isPlaying {
                triggerContextualDisplay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, hasPhysicalNotch ? 0 : 8)
    }
    
    private func triggerContextualDisplay() {
        dismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isContextuallyVisible = true
        }
        scheduleDismissal(after: 3.0)
    }
    
    private func scheduleDismissal(after seconds: Double) {
        dismissWorkItem?.cancel()
        let item = DispatchWorkItem {
            guard !self.isHovered else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.isContextuallyVisible = false
            }
        }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
    
    // MARK: - Compact Mode
    private func compactHUD(track: TrackState, activeColor: Color, currentWord: String) -> some View {
        HStack(spacing: 12) {
            // Mini Album Artwork or Fallback Icon
            if let art = track.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(activeColor)
                    .frame(width: 24, height: 24)
            }
            
            // Mini Animated Audio Spectrum
            miniSpectrumView(activeColor: activeColor)
                .frame(width: 42, height: 16)
            
            Spacer()
            
            // Active Singing Word
            if track.isPlaying {
                Text(currentWord.isEmpty ? track.title : currentWord)
                    .font(.system(size: 13, weight: .bold, design: theme.currentTypography.design))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: activeColor.opacity(0.5), radius: 6)
            } else {
                Text("VerciLumn")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Subtle Beat Dot
            Circle()
                .fill(activeColor)
                .frame(width: 6, height: 6)
                .scaleEffect(1.0 + CGFloat(audio.beatIntensity) * 0.8)
                .opacity(0.6 + Double(audio.beatIntensity) * 0.4)
        }
    }
    
    // MARK: - Expanded Hover Mode
    private func expandedHUD(track: TrackState, activeColor: Color, currentWord: String) -> some View {
        HStack(spacing: 14) {
            // Album Art
            if let art = track.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: activeColor.opacity(0.3), radius: 6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(activeColor)
                }
                .frame(width: 50, height: 50)
            }
            
            // Metadata & Live Word
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title.isEmpty ? "No Media Playing" : track.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist.isEmpty ? "VerciLumn Engine" : track.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                // Live Word Banner
                if !currentWord.isEmpty && track.isPlaying {
                    HStack(spacing: 4) {
                        Text("▶")
                            .font(.system(size: 9))
                            .foregroundColor(activeColor)
                        Text(currentWord)
                            .font(.system(size: 11, weight: .bold, design: theme.currentTypography.design))
                            .foregroundColor(activeColor)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Playback Transport Controls
            HStack(spacing: 8) {
                Button {
                    playback.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                
                Button {
                    playback.togglePlayPause()
                } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Circle().fill(activeColor))
                }
                .buttonStyle(.plain)
                
                Button {
                    playback.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Mini Spectrum Bars
    private func miniSpectrumView(activeColor: Color) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<6, id: \.self) { idx in
                let val = CGFloat(spectrum.bands[idx])
                Capsule()
                    .fill(activeColor.opacity(0.7 + Double(val) * 0.3))
                    .frame(width: 3, height: max(3, 16 * val))
            }
        }
    }
    
    private func currentLyricWord(at time: TimeInterval, activeLineIdx: Int) -> String {
        let lines = lyrics.currentLyrics.lines
        guard activeLineIdx < lines.count else { return "" }
        let line = lines[activeLineIdx]
        if let wordIdx = lyrics.currentLyrics.activeWordIndex(in: activeLineIdx, at: time),
           wordIdx < line.words.count {
            return line.words[wordIdx].text
        }
        return line.fullText
    }
}

