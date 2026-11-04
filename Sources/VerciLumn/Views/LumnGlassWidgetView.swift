import SwiftUI

public struct LumnGlassWidgetView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var palette = ColorPaletteManager.shared
    
    public init() {}
    
    public var body: some View {
        let track = playback.currentTrack
        let progress = track.duration > 0 ? min(max(track.exactPosition / track.duration, 0.0), 1.0) : 0.0
        
        HStack(spacing: 16) {
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
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: palette.currentPalette.highlightAccent.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Metadata & Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title.isEmpty ? "Not Playing" : track.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(palette.currentPalette.primaryText)
                    .lineLimit(1)
                
                Text(track.artist.isEmpty ? "VerciLumn Ready" : track.artist)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [palette.currentPalette.highlightAccent, palette.currentPalette.secondaryGlow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geo.size.width * CGFloat(progress), 4), height: 4)
                    }
                }
                .frame(height: 4)
                
                // Timestamps
                HStack {
                    Text(formatTime(track.exactPosition))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                    Text(formatTime(track.duration))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .frame(width: 220)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

