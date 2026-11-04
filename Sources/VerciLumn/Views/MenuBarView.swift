import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var windowManager = OverlayWindowManager.shared
    
    @Binding var currentStyle: LyricStyle
    @Binding var isBezelEnabled: Bool
    @Binding var glowSensitivity: Double
    @Binding var displayMode: WindowDisplayMode
    @Binding var backdropMode: BackdropMode
    @Binding var timingOffset: Double
    
    public init(
        currentStyle: Binding<LyricStyle>,
        isBezelEnabled: Binding<Bool>,
        glowSensitivity: Binding<Double>,
        displayMode: Binding<WindowDisplayMode>,
        backdropMode: Binding<BackdropMode>,
        timingOffset: Binding<Double>
    ) {
        self._currentStyle = currentStyle
        self._isBezelEnabled = isBezelEnabled
        self._glowSensitivity = glowSensitivity
        self._displayMode = displayMode
        self._backdropMode = backdropMode
        self._timingOffset = timingOffset
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Header & Now Playing
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.pink)
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
                
                // 1. Window Placement Layer
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Placement")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $displayMode) {
                        ForEach(WindowDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: displayMode) { _, newMode in
                        windowManager.setDisplayMode(newMode)
                    }
                }
                
                Divider()
                
                // 2. Backdrop Style (Solve Bright Wallpaper)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Backdrop / Canvas Style")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $backdropMode) {
                        ForEach(BackdropMode.allCases) { bMode in
                            Text(bMode.rawValue).tag(bMode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // 3. Lyric Visual Style
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lyric Visual Style")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $currentStyle) {
                        ForEach(LyricStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                
                Divider()
                
                // 4. Vocal Timing Calibration Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Vocal Sync Calibration")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%+.2fs", timingOffset))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Slider(value: $timingOffset, in: -1.5...1.5, step: 0.05)
                        Button("Reset") {
                            timingOffset = 0.0
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // 5. Bezel Glow Controls
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Audio-Reactive Bezel Glow", isOn: $isBezelEnabled)
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
                
                // 6. Diagnostics & Quit
                HStack {
                    Circle()
                        .fill(audio.isCapturing ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(audio.isCapturing ? "Beat Engine Active" : "Beat Engine Idle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text("Quit VerciLumn")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            .padding(14)
        }
        .frame(width: 320, height: 460)
    }
}
