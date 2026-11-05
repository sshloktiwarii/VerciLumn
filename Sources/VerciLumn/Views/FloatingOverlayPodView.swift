import SwiftUI

/// Draggable, resizable, floating glassmorphic PiP overlay for lyrics & playback.
public struct FloatingOverlayPodView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var windowManager = OverlayWindowManager.shared
    
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var isHoveringHeader: Bool = false
    
    public init() {}
    
    private var currentWidth: CGFloat {
        max(340, min(1200, CGFloat(settings.floatingWidth) + resizeOffset.width))
    }
    
    private var currentHeight: CGFloat {
        max(180, min(800, CGFloat(settings.floatingHeight) + resizeOffset.height))
    }
    
    private var dynamicTextScale: Double {
        let widthRatio = Double(currentWidth / 540.0)
        return min(max(widthRatio * settings.textScale, 0.7), 1.6)
    }
    
    public var body: some View {
        let palette = theme.activePalette
        let track = playback.currentTrack
        
        VStack(spacing: 0) {
            // MARK: 1. Top Draggable Title Bar / Grip
            HStack(spacing: 10) {
                // Mini Album Art
                if let art = track.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
                
                // Track Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title.isEmpty ? "VerciLumn Floating" : track.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                    
                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Center Drag Handle Grip Pill
                Capsule()
                    .fill(isHoveringHeader ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
                    .frame(width: 38, height: 4)
                
                Spacer()
                
                // Header Actions: Reset Position & Size
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        settings.resetFloatingGeometry()
                        dragOffset = .zero
                        resizeOffset = .zero
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.65))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Reset position and size (Center 540x360)")
                
                // Full Stage Expand Button
                Button {
                    settings.displayMode = .fullStage
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.65))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Expand to Full Stage")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .contentShape(Rectangle())
            .onHover { isHoveringHeader = $0 }
            // Drag Gesture on Header Bar
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        settings.floatingOffsetX += Double(value.translation.width)
                        settings.floatingOffsetY += Double(value.translation.height)
                        dragOffset = .zero
                    }
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // MARK: 2. Synced Lyrics Viewport
            VerciLyricsView(
                style: settings.lyricStyle,
                timingOffset: settings.timingOffset,
                textScale: dynamicTextScale
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // MARK: 3. Bottom Scrubber & Resize Footer
            VStack(spacing: 4) {
                // Scrubber Bar
                if settings.isInteractiveSeekEnabled && track.duration > 0 {
                    InteractivePlaybackScrubberView()
                        .frame(height: 18)
                        .padding(.horizontal, 10)
                }
                
                HStack(spacing: 12) {
                    // Playback Transport Controls
                    Button {
                        playback.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        playback.togglePlayPause()
                    } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(palette.highlightAccent)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        playback.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Corner Resize Handle (Bottom-Right)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    resizeOffset = value.translation
                                }
                                .onEnded { value in
                                    let newWidth = max(340.0, min(1200.0, Double(settings.floatingWidth) + Double(value.translation.width)))
                                    let newHeight = max(180.0, min(800.0, Double(settings.floatingHeight) + Double(value.translation.height)))
                                    settings.floatingWidth = newWidth
                                    settings.floatingHeight = newHeight
                                    resizeOffset = .zero
                                }
                        )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .background(Color.black.opacity(0.18))
        }
        .frame(width: currentWidth, height: currentHeight)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.white.opacity(0.08),
                            palette.highlightAccent.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
        .offset(
            x: CGFloat(settings.floatingOffsetX) + dragOffset.width,
            y: CGFloat(settings.floatingOffsetY) + dragOffset.height
        )
        // Report global bounding frame to OverlayWindowManager for click pass-through hit testing
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: FloatingWidgetFramePreferenceKey.self,
                        value: geo.frame(in: .global)
                    )
            }
        )
        .onPreferenceChange(FloatingWidgetFramePreferenceKey.self) { frame in
            windowManager.updateFloatingWidgetRect(frame)
        }
    }
}

public struct FloatingWidgetFramePreferenceKey: PreferenceKey {
    public static var defaultValue: CGRect = .zero
    public static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
