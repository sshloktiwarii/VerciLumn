import SwiftUI

public enum BackdropMode: String, CaseIterable, Identifiable {
    case oledBlack = "Cinematic Dark (Verci Style)"
    case ambientAurora = "Fluid Ambient Aurora"
    case transparent = "Transparent Pass-Through"
    
    public var id: String { rawValue }
}

public struct RootOverlayView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    
    @Binding var currentStyle: LyricStyle
    @Binding var isBezelEnabled: Bool
    @Binding var glowSensitivity: Double
    @Binding var backdropMode: BackdropMode
    @Binding var timingOffset: Double
    
    public init(
        currentStyle: Binding<LyricStyle>,
        isBezelEnabled: Binding<Bool>,
        glowSensitivity: Binding<Double>,
        backdropMode: Binding<BackdropMode>,
        timingOffset: Binding<Double>
    ) {
        self._currentStyle = currentStyle
        self._isBezelEnabled = isBezelEnabled
        self._glowSensitivity = glowSensitivity
        self._backdropMode = backdropMode
        self._timingOffset = timingOffset
    }
    
    public var body: some View {
        ZStack {
            // 1. Dynamic Mood Backdrop (Prevents bright wallpaper from showing through)
            backdropLayer
                .ignoresSafeArea()
            
            // 2. Audio Beat Reactive Display Bezel Glow
            BezelGlowView(
                isEnabled: isBezelEnabled,
                glowIntensityMultiplier: CGFloat(glowSensitivity)
            )
            
            // 3. Centered Synced Word Lyrics (Verci Kinetic Reel by default)
            VStack {
                Spacer()
                VerciLyricsView(style: currentStyle, timingOffset: timingOffset)
                Spacer()
            }
            .padding(.horizontal, 40)
            
            // 4. Now Playing Frosted Acrylic Glass Card (Bottom Left)
            VStack {
                Spacer()
                HStack {
                    LumnGlassWidgetView()
                        .padding(.leading, 36)
                        .padding(.bottom, 36)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    @ViewBuilder
    private var backdropLayer: some View {
        switch backdropMode {
        case .oledBlack:
            // Deep OLED black with subtle soft radial ambient glow
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.04)
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        palette.currentPalette.highlightAccent.opacity(0.18),
                        palette.currentPalette.secondaryGlow.opacity(0.08),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 40,
                    endRadius: 750
                )
            }
        case .ambientAurora:
            // Dynamic pulsating ambient aurora mesh
            ZStack {
                Color.black
                
                Circle()
                    .fill(palette.currentPalette.highlightAccent.opacity(0.35))
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .offset(x: -250, y: -100)
                    .scaleEffect(1.0 + CGFloat(audio.beatIntensity) * 0.25)
                
                Circle()
                    .fill(palette.currentPalette.secondaryGlow.opacity(0.3))
                    .frame(width: 550, height: 550)
                    .blur(radius: 130)
                    .offset(x: 200, y: 150)
                    .scaleEffect(1.0 + CGFloat(audio.beatIntensity) * 0.2)
            }
            .animation(.easeInOut(duration: 0.3), value: audio.beatIntensity)
        case .transparent:
            Color.clear
        }
    }
}
