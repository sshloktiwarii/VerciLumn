import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var audio = AudioBeatEngine.shared
    @ObservedObject var windowManager = OverlayWindowManager.shared
    @ObservedObject var semanticEngine = WordSemanticEngine.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var hotkeys = HotKeyManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var areFeaturesExpanded: Bool = true
    @State private var areAdjustmentsExpanded: Bool = false
    
    public init() {}
    
    // Backward-compatible init with bindings
    public init(
        currentStyle: Binding<LyricStyle>,
        isBezelEnabled: Binding<Bool>,
        glowSensitivity: Binding<Double>,
        displayMode: Binding<WindowDisplayMode>,
        backdropMode: Binding<BackdropMode>,
        timingOffset: Binding<Double>,
        textScale: Binding<Double>
    ) {
        self.init()
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: 1. Header & Now Playing Card
                nowPlayingHeader
                
                // Permission Alert (if needed)
                if !hotkeys.isAccessibilityGranted {
                    accessibilityAlertBanner
                }
                
                Divider()
                
                // MARK: 2. Core Layout Dropdown Pickers
                coreLayoutDropdowns
                
                Divider()
                
                // MARK: 3. Features & Add-ons (Collapsible Dropdown Menu)
                DisclosureGroup(isExpanded: $areFeaturesExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Feature A: Camera Notch Audio Capsule
                        featureRow(
                            icon: "inset.filled.topthird.rectangle",
                            title: "Camera Notch Audio Capsule",
                            shortcut: "⌘⇧N",
                            description: "Displays current singing word and audio spectrum around the camera notch.",
                            isOn: $settings.isNotchHUDEnabled
                        )
                        
                        // Feature B: Interactive Lyric Seek
                        featureRow(
                            icon: "hand.tap.fill",
                            title: "Interactive Line & Word Seeking",
                            shortcut: nil,
                            description: "Click any lyric line to rewind or jump, or drag the bottom scrubber.",
                            isOn: $settings.isInteractiveSeekEnabled
                        )
                        
                        // Feature C: Screen Border Glow
                        featureRow(
                            icon: "rectangle.inset.filled",
                            title: "Display Border Glow Pulse",
                            shortcut: nil,
                            description: "Pulses the outer display edges on low-frequency audio transients.",
                            isOn: $settings.isBezelEnabled
                        )
                        
                        // Feature D: Metal Fisheye Lens
                        featureRow(
                            icon: "circle.circle",
                            title: "Metal Lens Distortion Shader",
                            shortcut: nil,
                            description: "GPU spherical lens distortion focused on the active lyric word.",
                            isOn: $settings.isFisheyeShaderEnabled
                        )
                        
                        // Feature E: Semantic Word Icons
                        featureRow(
                            icon: "sparkles",
                            title: "Contextual Word Icons",
                            shortcut: nil,
                            description: "Renders SF Symbols above matching semantic lyric tokens.",
                            isOn: $semanticEngine.isEnabled
                        )
                        
                        // Feature F: Screen Ambilight Sampling
                        featureRow(
                            icon: "display",
                            title: "Screen Ambilight (CGDisplayStream)",
                            shortcut: nil,
                            description: "Samples 128x72 display edge pixels to drive bezel glow during movies & games.",
                            isOn: Binding(
                                get: { settings.bezelSourceMode == .screenSampling },
                                set: { settings.bezelSourceMode = $0 ? .screenSampling : .audioReactive }
                            )
                        )
                        
                        // Feature G: Live Lyric Translation
                        featureRow(
                            icon: "character.bubble.fill",
                            title: "Live Lyric AI Translation",
                            shortcut: nil,
                            description: "Translates synced lyrics asynchronously via local Ollama or Google Translate.",
                            isOn: $settings.isTranslationEnabled
                        )
                    }
                    .padding(.top, 6)
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.2.square")
                            .foregroundColor(theme.activePalette.highlightAccent)
                        Text("OPTIONAL MODULES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                
                Divider()
                
                // MARK: 4. Fine-Tuning & Adjustments (Collapsible Dropdown Menu)
                DisclosureGroup(isExpanded: $areAdjustmentsExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Text Size
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Text Scale")
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer()
                                Text(String(format: "%.1fx", settings.textScale))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 8) {
                                Slider(value: $settings.textScale, in: 0.7...2.2, step: 0.1)
                                Button("Reset") { settings.textScale = 1.0 }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                            }
                        }
                        
                        // Vocal Timing Offset
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Vocal Timing Offset")
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer()
                                Text(String(format: "%+.2fs", settings.timingOffset))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Text("Use ⌘+[ and ⌘+] or [ / ] to nudge sync ±100ms.")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Slider(value: $settings.timingOffset, in: -1.5...1.5, step: 0.05)
                                Button("0.0s") { settings.resetTimingOffset() }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                            }
                        }
                        
                        // Bezel Sensitivity
                        if settings.isBezelEnabled {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Border Pulse Sensitivity")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text(String(format: "%.1fx", settings.glowSensitivity))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $settings.glowSensitivity, in: 0.5...2.5, step: 0.1)
                            }
                        }
                        
                        // Auto Screensaver
                        Toggle("Activate screensaver after 60s idle", isOn: $hotkeys.isIdleScreensaverEnabled)
                            .font(.system(size: 11, weight: .medium))
                            
                        // Font Style Typography
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Typography")
                                .font(.system(size: 11, weight: .semibold))
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
                    .padding(.top, 6)
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.secondary)
                        Text("FINE TUNING & LATENCY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                
                Divider()
                
                // MARK: 5. Battery & Laptop Thermals
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $settings.isLowPowerModeEnabled) {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                            Text("Cool Laptop / Low Power Mode")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    Text("Limits background animations to 30 FPS and halts rendering when music stops to prevent heating and fan noise.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Divider()
                
                // MARK: 6. Diagnostics & Quit
                footerDiagnostics
            }
            .padding(16)
        }
        .frame(width: 380, height: 600)
    }
    
    // MARK: - Now Playing Header
    private var nowPlayingHeader: some View {
        HStack(spacing: 12) {
            if let art = playback.currentTrack.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(theme.activePalette.highlightAccent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playback.currentTrack.title.isEmpty ? "VerciLumn Engine" : playback.currentTrack.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                
                Text(playback.currentTrack.artist.isEmpty ? "Play song in Spotify or Apple Music" : "\(playback.currentTrack.artist) • \(playback.currentTrack.playerSource)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Media Controls
            HStack(spacing: 6) {
                Button {
                    playback.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                
                Button {
                    playback.togglePlayPause()
                } label: {
                    Image(systemName: playback.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.activePalette.highlightAccent)
                }
                .buttonStyle(.plain)
                
                Button {
                    playback.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Accessibility Permission Banner
    private var accessibilityAlertBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility Needed for Hotkeys")
                    .font(.system(size: 11, weight: .bold))
                Text("Allow in System Settings to use ⌘+⇧+L, ⌘+⇧+N, etc.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Grant") {
                hotkeys.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }
    
    // MARK: - Core Layout Dropdowns
    private var coreLayoutDropdowns: some View {
        VStack(spacing: 10) {
            // Dropdown 1: Window Layer Mode
            dropdownPicker(
                label: "DISPLAY PRESENTATION",
                sublabel: "Screen elevation, desktop wallpaper pass-through, and floating layer",
                selection: $settings.displayMode
            ) {
                Text("Full Screen Stage").tag(WindowDisplayMode.fullStage)
                Text("Desktop Wallpaper (Behind active apps)").tag(WindowDisplayMode.desktop)
                Text("Floating Overlay (Top layer)").tag(WindowDisplayMode.floating)
            }
            .onChange(of: settings.displayMode) { _, newMode in
                windowManager.setDisplayMode(newMode)
            }
            
            // Dropdown 2: Lyric Text Color Palette
            dropdownPicker(
                label: "COLOR PALETTE",
                sublabel: "Active lyric typography, badges, and transient highlights",
                selection: Binding(
                    get: { theme.currentTheme },
                    set: { theme.setTheme($0) }
                )
            ) {
                ForEach(ColorThemePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            
            // Dropdown 3: Animation Theme Style
            dropdownPicker(
                label: "LYRIC PRESENTATION",
                sublabel: "Interactive line reel, 3D typography, or crossfade stack",
                selection: $settings.lyricStyle
            ) {
                Text("Interactive Line Reel (Current & Next Line)").tag(LyricStyle.verciReel)
                Text("3D Vinyl Turntable").tag(LyricStyle.turntable)
                Text("3D Perspective Horizon").tag(LyricStyle.neonHorizon)
                Text("Monospace Telemetry").tag(LyricStyle.cyberpunk)
                Text("Cinematic Crossfade Stack").tag(LyricStyle.cinematicStack)
            }
            
            // Dropdown 4: Canvas Backdrop
            dropdownPicker(
                label: "BACKGROUND BACKDROP",
                sublabel: "Atmospheric visualizer or transparent pass-through",
                selection: $settings.backdropMode
            ) {
                Text("Hypnotic Geometric Tunnel (Dark Stage)").tag(BackdropMode.infiniteZoom)
                Text("Audio Particle Field (Dark Stage)").tag(BackdropMode.particleCosmos)
                Text("Cinematic Dark (Pure Black)").tag(BackdropMode.oledBlack)
                Text("Transparent (Pass-Through to Desktop)").tag(BackdropMode.transparent)
            }
        }
    }
    
    // MARK: - Helper Dropdown Picker Component
    private func dropdownPicker<T: Hashable, Content: View>(
        label: String,
        sublabel: String,
        selection: Binding<T>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            Picker("", selection: selection) {
                content()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Text(sublabel)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    // MARK: - Helper Feature Row Component
    private func featureRow(
        icon: String,
        title: String,
        shortcut: String?,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: isOn) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(isOn.wrappedValue ? theme.activePalette.highlightAccent : .secondary)
                        .frame(width: 16)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    if let sc = shortcut {
                        Text("(\(sc))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Text(description)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .padding(.leading, 22)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Footer Diagnostics
    private var footerDiagnostics: some View {
        HStack {
            Circle()
                .fill(playback.currentTrack.isPlaying ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            
            Text(playback.currentTrack.isPlaying ? "Active: \(playback.currentTrack.playerSource)" : "Idle (0% CPU)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                CommandPalettePanel.shared.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "command")
                        .font(.system(size: 10, weight: .bold))
                    Text("⌘K")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open floating Command Palette (⌘K)")
            
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
}
