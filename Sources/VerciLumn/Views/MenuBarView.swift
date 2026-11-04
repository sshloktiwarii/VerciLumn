import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var windowManager = OverlayWindowManager.shared
    @ObservedObject var semanticEngine = WordSemanticEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var hotkeys = HotKeyManager.shared
    
    @Binding var currentStyle: LyricStyle
    @Binding var isBezelEnabled: Bool
    @Binding var glowSensitivity: Double
    @Binding var displayMode: WindowDisplayMode
    @Binding var backdropMode: BackdropMode
    @Binding var timingOffset: Double
    @Binding var textScale: Double
    
    public init(
        currentStyle: Binding<LyricStyle>,
        isBezelEnabled: Binding<Bool>,
        glowSensitivity: Binding<Double>,
        displayMode: Binding<WindowDisplayMode>,
        backdropMode: Binding<BackdropMode>,
        timingOffset: Binding<Double>,
        textScale: Binding<Double>
    ) {
        self._currentStyle = currentStyle
        self._isBezelEnabled = isBezelEnabled
        self._glowSensitivity = glowSensitivity
        self._displayMode = displayMode
        self._backdropMode = backdropMode
        self._timingOffset = timingOffset
        self._textScale = textScale
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Header & Now Playing
                HStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(theme.activePalette.highlightAccent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VerciLumn Engine")
                            .font(.system(size: 15, weight: .bold))
                        Text(playback.currentTrack.isPlaying ? "\(playback.currentTrack.title) • \(playback.currentTrack.artist)" : "No Music Playing")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.bottom, 2)
                
                Divider()
                
                // 1. Display Placement
                VStack(alignment: .leading, spacing: 5) {
                    Text("WINDOW LAYER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $displayMode) {
                        ForEach(WindowDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: displayMode) { _, newMode in
                        windowManager.setDisplayMode(newMode)
                    }
                }
                
                // 2. Backdrop Style
                VStack(alignment: .leading, spacing: 5) {
                    Text("CANVAS BACKDROP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $backdropMode) {
                        ForEach(BackdropMode.allCases) { bMode in
                            Text(bMode.rawValue).tag(bMode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                // 3. Lyric Visual Theme
                VStack(alignment: .leading, spacing: 5) {
                    Text("ANIMATION THEME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $currentStyle) {
                        ForEach(LyricStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                // 4. Color Palette & Typography Presets
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("COLOR PALETTE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: Binding(
                            get: { theme.currentTheme },
                            set: { theme.setTheme($0) }
                        )) {
                            ForEach(ColorThemePreset.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TYPOGRAPHY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: Binding(
                            get: { theme.currentTypography },
                            set: { theme.setTypography($0) }
                        )) {
                            ForEach(TypographyStyle.allCases) { font in
                                Text(font.rawValue).tag(font)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                
                Divider()
                
                // 5. Semantic Word VFX (Fire, Ice, Speed, Love, Impact)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Semantic Word VFX Engine", isOn: $semanticEngine.isEnabled)
                        .font(.system(size: 13, weight: .medium))
                    
                    if semanticEngine.isEnabled {
                        HStack {
                            Text("VFX Intensity")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Slider(value: $semanticEngine.intensity, in: 0.5...1.5, step: 0.1)
                            Text(String(format: "%.1fx", semanticEngine.intensity))
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 32)
                        }
                    }
                }
                
                Divider()
                
                // 6. Text Size Scale Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("TEXT SIZE SCALE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1fx", textScale))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    
                    HStack(spacing: 8) {
                        Slider(value: $textScale, in: 0.7...2.2, step: 0.1)
                        Button("1x") {
                            textScale = 1.0
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // 7. Vocal Sync Calibration Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("VOCAL SYNC OFFSET")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%+.2fs", timingOffset))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    
                    HStack(spacing: 8) {
                        Slider(value: $timingOffset, in: -1.5...1.5, step: 0.05)
                        Button("0s") {
                            timingOffset = 0.0
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // 8. Global Shortcuts & Screensaver Daemon
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Auto Screensaver on Inactivity (60s)", isOn: $hotkeys.isIdleScreensaverEnabled)
                        .font(.system(size: 12, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SHORTCUTS:")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("⌘+⇧+L (Toggle Stage) • ⌘+⌥+→ (Next Theme) • ⌘+[ / ⌘+] (Sync ±50ms)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }
                
                Divider()
                
                // 9. Bezel Glow Controls
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Beat-Reactive Bezel Glow", isOn: $isBezelEnabled)
                        .font(.system(size: 13, weight: .medium))
                    
                    if isBezelEnabled {
                        HStack {
                            Text("Sensitivity")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Slider(value: $glowSensitivity, in: 0.5...2.5, step: 0.1)
                            Text(String(format: "%.1fx", glowSensitivity))
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 32)
                        }
                    }
                }
                
                Divider()
                
                // 10. Diagnostics & Quit
                HStack {
                    Circle()
                        .fill(audio.isCapturing ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(audio.isCapturing ? "Engine: 8-Band vDSP FFT" : "Engine Idle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text("Quit")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(18)
        }
        .frame(width: 360, height: 600)
    }
}
