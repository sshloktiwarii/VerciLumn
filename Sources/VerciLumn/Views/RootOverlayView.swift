import SwiftUI

public struct RootOverlayView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
    @Binding var currentStyle: LyricStyle
    @Binding var isBezelEnabled: Bool
    @Binding var glowSensitivity: Double
    
    public init(
        currentStyle: Binding<LyricStyle>,
        isBezelEnabled: Binding<Bool>,
        glowSensitivity: Binding<Double>
    ) {
        self._currentStyle = currentStyle
        self._isBezelEnabled = isBezelEnabled
        self._glowSensitivity = glowSensitivity
    }
    
    public var body: some View {
        ZStack {
            // 1. Audio Beat Reactive Display Bezel Glow
            BezelGlowView(
                isEnabled: isBezelEnabled,
                glowIntensityMultiplier: CGFloat(glowSensitivity)
            )
            
            // 2. Centered Synced Word Lyrics (4 Styles)
            VStack {
                Spacer()
                VerciLyricsView(style: currentStyle)
                Spacer()
            }
            .padding(.horizontal, 40)
            
            // 3. Now Playing Frosted Acrylic Glass Card
            VStack {
                Spacer()
                HStack {
                    LumnGlassWidgetView()
                        .padding(.leading, 32)
                        .padding(.bottom, 32)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onReceive(playback.$currentTrack) { track in
            // Update color palette from album artwork
            palette.updatePalette(from: track.artwork)
            
            // Prevent display sleep while music is playing
            DisplaySleepManager.shared.setPreventDisplaySleep(track.isPlaying)
            
            // Query time-synced lyrics from LRCLIB
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
}
