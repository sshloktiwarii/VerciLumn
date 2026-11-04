import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    
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
        VStack(alignment: .leading, spacing: 14) {
            // Header & Now Playing
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("VerciLumn Engine")
                        .font(.headline)
                    Text(playback.currentTrack.isPlaying ? "\(playback.currentTrack.title) • \(playback.currentTrack.artist)" : "Playback Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Divider()
            
            // Lyric Style Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Lyric Visual Style")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Picker("", selection: $currentStyle) {
                    ForEach(LyricStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Divider()
            
            // Bezel Glow Settings
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Beat-Reactive Bezel Glow", isOn: $isBezelEnabled)
                    .font(.subheadline)
                
                if isBezelEnabled {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Beat Sensitivity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1fx", glowSensitivity))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        Slider(value: $glowSensitivity, in: 0.5...2.5, step: 0.1)
                    }
                }
            }
            
            Divider()
            
            // Audio Capture & Permissions
            HStack {
                Circle()
                    .fill(audio.isCapturing ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(audio.isCapturing ? "Audio Reactive Engine: Active" : "Audio Capture: Idle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Quit
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit VerciLumn")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(14)
        .frame(width: 280)
    }
}
