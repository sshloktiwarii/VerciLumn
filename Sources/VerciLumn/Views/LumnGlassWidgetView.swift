import SwiftUI

public struct LumnGlassWidgetView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var theme = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        if playback.currentTrack.isPlaying {
            let track = playback.currentTrack
            let palette = theme.activePalette
            
            HStack(spacing: 12) {
                // Album Artwork
                ZStack {
                    if let artwork = track.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: palette.highlightAccent.opacity(0.25), radius: 6, x: 0, y: 3)
                
                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title.isEmpty ? "Unknown Track" : track.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(palette.primaryText)
                        .lineLimit(1)
                    
                    Text(track.artist.isEmpty ? track.playerSource : "\(track.artist) • \(track.playerSource)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                }
                
                // Play / Pause Button
                Button {
                    playback.togglePlayPause()
                } label: {
                    Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(palette.highlightAccent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
    }
}


