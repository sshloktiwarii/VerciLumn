import SwiftUI

public enum BackdropMode: String, CaseIterable, Identifiable {
    case infiniteZoom = "Infinite Geometric Zoom (Hypnotic Tunnel)"
    case particleCosmos = "Audio-Reactive Particle Cosmos"
    case oledBlack = "Cinematic Dark (Verci Style)"
    case transparent = "Transparent Pass-Through"
    
    public var id: String { rawValue }
    
    public init?(rawValue: String) {
        if rawValue.contains("Aurora") || rawValue.contains("ambientAurora") || rawValue.contains("Zoom") || rawValue.contains("Tunnel") {
            self = .infiniteZoom
            return
        }
        for val in BackdropMode.allCases {
            if val.rawValue == rawValue {
                self = val
                return
            }
        }
        return nil
    }
}

public struct RootOverlayView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var windowManager = OverlayWindowManager.shared
    
    public init() {}
    
    // Backward-compatible init with bindings
    public init(
        currentStyle: Binding<LyricStyle>,
        isBezelEnabled: Binding<Bool>,
        glowSensitivity: Binding<Double>,
        backdropMode: Binding<BackdropMode>,
        timingOffset: Binding<Double>,
        textScale: Binding<Double>
    ) {
        self.init()
    }
    
    public var body: some View {
        let isPlaying = playback.currentTrack.isPlaying
        let isLocked = windowManager.isScreenLocked
        
        ZStack {
            if isPlaying || isLocked {
                // 1. Dynamic Canvas Backdrop (Only if not transparent)
                if settings.backdropMode != .transparent {
                    backdropLayer
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                
                // 2. Audio Beat Reactive Display Bezel Glow
                BezelGlowView(
                    isEnabled: settings.isBezelEnabled,
                    glowIntensityMultiplier: CGFloat(settings.glowSensitivity)
                )
                .allowsHitTesting(false)
                
                // 3. Main Stage Layout (Non-Overlapping Vertical Hierarchy)
                VStack(spacing: 0) {
                    // Tactile Timing Sync Nudge HUD
                    TimingHUDView()
                        .padding(.top, 36)
                        .allowsHitTesting(false)
                    
                    Spacer(minLength: 24)
                    
                    // Synced Lyrics Center Stage
                    VerciLyricsView(
                        style: settings.lyricStyle,
                        timingOffset: settings.timingOffset,
                        textScale: settings.textScale
                    )
                    
                    Spacer(minLength: 32)
                    
                    // Unified Non-Mushed Bottom Control Dock
                    unifiedBottomDock
                        .padding(.horizontal, 36)
                        .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onReceive(playback.$currentTrack) { track in
            palette.updatePalette(from: track.artwork)
            DisplaySleepManager.shared.setPreventDisplaySleep(track.isPlaying)
            if track.isPlaying && !track.title.isEmpty {
                lyrics.fetchLyrics(
                    track: track.title,
                    artist: track.artist,
                    album: track.album,
                    duration: track.duration
                )
            }
        }
    }
    
    // MARK: - Unified Bottom Playback Dock
    private var unifiedBottomDock: some View {
        ZStack {
            // Left: Frosted Now Playing Card
            HStack {
                LumnGlassWidgetView()
                Spacer()
            }
            
            // Center: Interactive Scrubber Timeline (Centered, Zero Collisions)
            if settings.isInteractiveSeekEnabled && playback.currentTrack.duration > 0 {
                InteractivePlaybackScrubberView()
                    .frame(maxWidth: 480)
            }
        }
    }
    
    @ViewBuilder
    private var backdropLayer: some View {
        switch settings.backdropMode {
        case .infiniteZoom:
            // Immersive dark stage background for the sacred geometric tunnel
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06)
                InfiniteZoomTunnelView()
            }
            .ignoresSafeArea()
            
        case .particleCosmos:
            // Immersive dark cosmic stage background for the particle field
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.05)
                ParticleCosmosView()
            }
            .ignoresSafeArea()
            
        case .oledBlack:
            // Pure OLED black stage
            Color.black
                .ignoresSafeArea()
            
        case .transparent:
            // Strictly see-through pass-through
            Color.clear
        }
    }
}
