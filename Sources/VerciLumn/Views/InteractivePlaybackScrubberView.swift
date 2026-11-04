import SwiftUI

public struct InteractivePlaybackScrubberView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var isScrubbing: Bool = false
    @State private var scrubPosition: Double = 0.0
    @State private var isHoveringRewind: Bool = false
    @State private var isHoveringForward: Bool = false
    
    public init() {}
    
    public var body: some View {
        let currentTime = playback.currentTrack.exactPosition(withOffset: settings.timingOffset)
        let duration = playback.currentTrack.duration
        let displayTime = isScrubbing ? scrubPosition : currentTime
        let progress = duration > 0 ? min(max(displayTime / duration, 0.0), 1.0) : 0.0
        let activeColor = theme.activePalette.highlightAccent
        
        HStack(spacing: 12) {
            // Rewind 5 seconds
            Button {
                playback.rewind(seconds: 5)
            } label: {
                ZStack {
                    Circle()
                        .fill(isHoveringRewind ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isHoveringRewind ? activeColor : Color.white.opacity(0.85))
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringRewind = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .help("Rewind 5 seconds")
            
            // Elapsed Time
            Text(formatTime(displayTime))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 42, alignment: .trailing)
            
            // Interactive Scrub Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: theme.activePalette.isRainbow ? theme.activePalette.rainbowGradient : [activeColor.opacity(0.7), activeColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 5)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 14 : 10, height: isScrubbing ? 14 : 10)
                        .shadow(color: activeColor.opacity(0.8), radius: 6)
                        .offset(x: max(0, min(geo.size.width * CGFloat(progress) - (isScrubbing ? 7 : 5), geo.size.width - 12)))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let ratio = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                            scrubPosition = ratio * duration
                        }
                        .onEnded { value in
                            let ratio = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                            let target = ratio * duration
                            playback.seekTo(seconds: target)
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 20)
            
            // Remaining Duration
            Text(formatTime(duration))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 42, alignment: .leading)
            
            // Fast Forward 5 seconds
            Button {
                playback.fastForward(seconds: 5)
            } label: {
                ZStack {
                    Circle()
                        .fill(isHoveringForward ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "goforward.5")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isHoveringForward ? activeColor : Color.white.opacity(0.85))
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringForward = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .help("Fast-forward 5 seconds")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

