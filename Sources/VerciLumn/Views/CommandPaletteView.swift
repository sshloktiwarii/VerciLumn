import SwiftUI
import AppKit

public enum CommandCategory: String, CaseIterable, Identifiable {
    case timing = "Timing & Lyrics"
    case playback = "Playback Transport"
    case styles = "Visualizer Styles"
    case stage = "Stage & Immersion"
    case engine = "Performance & Settings"
    
    public var id: String { rawValue }
}

public struct CommandItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: CommandCategory
    public let shortcut: String?
    public let action: () -> Void
}

public struct CommandPaletteView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var playback = PlaybackManager.shared
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var lyrics = LyricsFetcher.shared
    @ObservedObject var windowManager = OverlayWindowManager.shared
    
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    
    public var onClose: (() -> Void)?
    
    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    private var allCommands: [CommandItem] {
        [
            // MARK: - Timing & Sync Commands
            CommandItem(
                title: "Nudge Sync Ahead (+100ms)",
                subtitle: "Compensate for lyrics trailing behind audio",
                icon: "plus.circle.fill",
                category: .timing,
                shortcut: "⌘⌥]",
                action: {
                    settings.nudgeTimingOffset(by: 0.10)
                }
            ),
            CommandItem(
                title: "Nudge Sync Back (-100ms)",
                subtitle: "Compensate for lyrics jumping ahead of audio",
                icon: "minus.circle.fill",
                category: .timing,
                shortcut: "⌘⌥[",
                action: {
                    settings.nudgeTimingOffset(by: -0.10)
                }
            ),
            CommandItem(
                title: "Reset Sync Offset to 0ms",
                subtitle: "Restore natural LRC track timing",
                icon: "arrow.counterclockwise.circle.fill",
                category: .timing,
                shortcut: "⌘⌥0",
                action: {
                    settings.resetTimingOffset()
                }
            ),
            CommandItem(
                title: "Reload & Re-parse Lyrics",
                subtitle: "Fetch fresh synchronized lyrics from LRCLib & NetEase",
                icon: "arrow.clockwise",
                category: .timing,
                shortcut: "⌘R",
                action: {
                    let track = playback.currentTrack
                    if !track.title.isEmpty {
                        lyrics.fetchLyrics(
                            track: track.title,
                            artist: track.artist,
                            album: track.album,
                            duration: track.duration
                        )
                    }
                }
            ),
            
            // MARK: - Playback Transport
            CommandItem(
                title: playback.currentTrack.isPlaying ? "Pause Playback" : "Resume Playback",
                subtitle: playback.currentTrack.isPlaying ? "Pause Spotify or Apple Music" : "Resume playback",
                icon: playback.currentTrack.isPlaying ? "pause.fill" : "play.fill",
                category: .playback,
                shortcut: "⌘⌥Space",
                action: {
                    playback.togglePlayPause()
                }
            ),
            CommandItem(
                title: "Next Track",
                subtitle: "Skip to following song in playlist",
                icon: "forward.fill",
                category: .playback,
                shortcut: "⌘→",
                action: {
                    playback.nextTrack()
                }
            ),
            CommandItem(
                title: "Previous Track",
                subtitle: "Restart song or return to previous track",
                icon: "backward.fill",
                category: .playback,
                shortcut: "⌘←",
                action: {
                    playback.previousTrack()
                }
            ),
            CommandItem(
                title: "Rewind 5 Seconds",
                subtitle: "Seek backward by 5 seconds",
                icon: "gobackward.5",
                category: .playback,
                shortcut: "←",
                action: {
                    playback.rewind(seconds: 5.0)
                }
            ),
            CommandItem(
                title: "Fast-Forward 5 Seconds",
                subtitle: "Seek forward by 5 seconds",
                icon: "goforward.5",
                category: .playback,
                shortcut: "→",
                action: {
                    playback.fastForward(seconds: 5.0)
                }
            ),
            
            // MARK: - Visualizer Styles
            CommandItem(
                title: "Style: Verci Kinetic Reel (Official)",
                subtitle: "Official animated reel with active typography scaling",
                icon: "film.fill",
                category: .styles,
                shortcut: nil,
                action: {
                    settings.lyricStyle = .verciReel
                }
            ),
            CommandItem(
                title: "Style: 3D Holographic Vinyl Turntable",
                subtitle: "Rotating vinyl platter with groove-tracked lyrics",
                icon: "opticaldisc.fill",
                category: .styles,
                shortcut: nil,
                action: {
                    settings.lyricStyle = .turntable
                }
            ),
            CommandItem(
                title: "Style: Neon Horizon (3D Perspective)",
                subtitle: "Synthwave grid with perspective vanishing point",
                icon: "square.stack.3d.forward.dottedline.fill",
                category: .styles,
                shortcut: nil,
                action: {
                    settings.lyricStyle = .neonHorizon
                }
            ),
            CommandItem(
                title: "Style: Cyberpunk Telemetry",
                subtitle: "High-contrast technical HUD telemetry",
                icon: "waveform.path.ecg",
                category: .styles,
                shortcut: nil,
                action: {
                    settings.lyricStyle = .cyberpunk
                }
            ),
            CommandItem(
                title: "Style: Cinematic Crossfade Stack",
                subtitle: "Layered smooth crossfade typography",
                icon: "square.fill.text.grid.1x2",
                category: .styles,
                shortcut: nil,
                action: {
                    settings.lyricStyle = .cinematicStack
                }
            ),
            
            // MARK: - Stage & Immersion
            CommandItem(
                title: "Cycle Display Mode (Desktop ↔ Floating ↔ Stage)",
                subtitle: "Elevate window between wallpaper, top floating layer, or full stage",
                icon: "macwindow.on.rectangle",
                category: .stage,
                shortcut: "⌘⌥1",
                action: {
                    let current = settings.displayMode
                    let next: WindowDisplayMode
                    switch current {
                    case .desktop: next = .floating
                    case .floating: next = .fullStage
                    case .fullStage: next = .desktop
                    }
                    settings.displayMode = next
                }
            ),
            CommandItem(
                title: "Switch to Floating Top Overlay",
                subtitle: "Float lyrics on top of all active apps (Chrome, VS Code, Terminal)",
                icon: "square.stack.3d.up.fill",
                category: .stage,
                shortcut: nil,
                action: {
                    settings.displayMode = .floating
                }
            ),
            CommandItem(
                title: "Switch to Desktop Wallpaper Mode",
                subtitle: "Pin visualizer behind all desktop windows directly above wallpaper",
                icon: "display",
                category: .stage,
                shortcut: nil,
                action: {
                    settings.displayMode = .desktop
                }
            ),
            CommandItem(
                title: settings.isImmersiveModeEnabled ? "Exit Borderless Immersive Mode" : "Enter Borderless Immersive Mode",
                subtitle: "Auto-hide Dock & Menu Bar without macOS Space sliding animation",
                icon: "arrow.up.left.and.arrow.down.right.square",
                category: .stage,
                shortcut: "⌘⌥3",
                action: {
                    settings.isImmersiveModeEnabled.toggle()
                }
            ),
            CommandItem(
                title: "Toggle Dynamic Camera Notch Capsule",
                subtitle: "Show/hide active singing word and spectrum at screen notch",
                icon: "inset.filled.topthird.rectangle",
                category: .stage,
                shortcut: "⌘⌥2",
                action: {
                    settings.isNotchHUDEnabled.toggle()
                }
            ),
            CommandItem(
                title: "Toggle Multi-Zone Ambilight Bezel",
                subtitle: "Audio-reactive border glow mapped to FFT frequency zones",
                icon: "rectangle.inset.filled",
                category: .stage,
                shortcut: "⌘⌥4",
                action: {
                    settings.isBezelEnabled.toggle()
                }
            ),
            CommandItem(
                title: "Cycle Canvas Backdrop",
                subtitle: "Switch between Infinite Tunnel, Particle Cosmos, Obsidian, or Transparent",
                icon: "circle.hexagongrid.fill",
                category: .stage,
                shortcut: nil,
                action: {
                    let all = BackdropMode.allCases
                    let idx = all.firstIndex(of: settings.backdropMode) ?? 0
                    settings.backdropMode = all[(idx + 1) % all.count]
                }
            ),
            
            // MARK: - Performance & Settings
            CommandItem(
                title: "Toggle Screen Ambilight Mode",
                subtitle: "Switch between audio FFT and 128x72 CGDisplayStream edge sampling",
                icon: "display",
                category: .engine,
                shortcut: nil,
                action: {
                    settings.bezelSourceMode = (settings.bezelSourceMode == .screenSampling) ? .audioReactive : .screenSampling
                }
            ),
            CommandItem(
                title: "Toggle Live Lyric AI Translation",
                subtitle: "Asynchronously translate foreign lyrics with local Ollama or Google Translate",
                icon: "character.bubble.fill",
                category: .timing,
                shortcut: "⌘⌥5",
                action: {
                    settings.isTranslationEnabled.toggle()
                }
            ),
            CommandItem(
                title: "Toggle Low Power Mode",
                subtitle: "Cap frame updates to 30 FPS and suspend heavy shaders",
                icon: "battery.50percent",
                category: .engine,
                shortcut: nil,
                action: {
                    settings.isLowPowerModeEnabled.toggle()
                }
            ),
            CommandItem(
                title: "Toggle Metal Fisheye Shader",
                subtitle: "GPU spherical lens distortion around singing words",
                icon: "circle.circle",
                category: .engine,
                shortcut: nil,
                action: {
                    settings.isFisheyeShaderEnabled.toggle()
                }
            ),
            CommandItem(
                title: "Cycle Color Theme Preset",
                subtitle: "Switch accent colors, gradients, and typography",
                icon: "paintpalette.fill",
                category: .engine,
                shortcut: "⌘⌥9",
                action: {
                    let all = ColorThemePreset.allCases
                    let idx = all.firstIndex(of: theme.currentTheme) ?? 0
                    theme.setTheme(all[(idx + 1) % all.count])
                }
            )
        ]
    }
    
    private var filteredCommands: [CommandItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return allCommands
        }
        let query = searchText.lowercased()
        return allCommands.filter {
            $0.title.lowercased().contains(query) ||
            $0.subtitle.lowercased().contains(query) ||
            $0.category.rawValue.lowercased().contains(query)
        }
    }
    
    public var body: some View {
        let activeColor = theme.activePalette.highlightAccent
        let offsetMs = Int(round(settings.timingOffset * 1000.0))
        let offsetText = offsetMs >= 0 ? "+\(offsetMs)ms" : "\(offsetMs)ms"
        
        VStack(spacing: 0) {
            // MARK: - Search Header & Timing Nudge Indicators
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(activeColor)
                
                TextField("Type a command or search (e.g. 'nudge', 'turntable', 'pause')...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                // Live Tactile Timing Nudge Pill
                HStack(spacing: 6) {
                    Button {
                        settings.nudgeTimingOffset(by: -0.10)
                    } label: {
                        Text("[ -100ms")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Nudge lyric sync back 100ms (Hotkey: [)")
                    
                    Text(offsetText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(activeColor)
                        .padding(.horizontal, 4)
                    
                    Button {
                        settings.nudgeTimingOffset(by: 0.10)
                    } label: {
                        Text("+100ms ]")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Nudge lyric sync ahead 100ms (Hotkey: ])")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // MARK: - Command Results List
            if filteredCommands.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No matching commands found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, item in
                                commandRow(item: item, isSelected: index == selectedIndex, activeColor: activeColor)
                                    .id(index)
                                    .onTapGesture {
                                        execute(item: item)
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // MARK: - Footer Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    keyBadge("↑↓")
                    Text("Navigate")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
                
                HStack(spacing: 4) {
                    keyBadge("↵")
                    Text("Execute")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
                
                HStack(spacing: 4) {
                    keyBadge("[")
                    keyBadge("]")
                    Text("±100ms Sync")
                        .font(.system(size: 11))
                        .foregroundColor(activeColor.opacity(0.85))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    keyBadge("Esc")
                    Text("Close")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.3))
        }
        .frame(width: 580, height: 420)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.11).opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    activeColor.opacity(0.6),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 24, y: 12)
        )
        .onAppear {
            selectedIndex = 0
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CommandPaletteKeyDown"))) { notif in
            guard let event = notif.object as? NSEvent else { return }
            handlePaletteKeyEvent(event)
        }
    }
    
    private func execute(item: CommandItem) {
        item.action()
        onClose?()
    }
    
    private func handlePaletteKeyEvent(_ event: NSEvent) {
        switch event.keyCode {
        case 126: // Up Arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
            } else {
                selectedIndex = max(0, filteredCommands.count - 1)
            }
        case 125: // Down Arrow
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            } else {
                selectedIndex = 0
            }
        case 36: // Enter / Return
            if filteredCommands.indices.contains(selectedIndex) {
                execute(item: filteredCommands[selectedIndex])
            }
        case 53: // Escape
            onClose?()
        case 33: // "["
            settings.nudgeTimingOffset(by: -0.10)
        case 30: // "]"
            settings.nudgeTimingOffset(by: 0.10)
        default:
            break
        }
    }
    
    // MARK: - Command Row UI
    private func commandRow(item: CommandItem, isSelected: Bool, activeColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? activeColor : .white.opacity(0.7))
                .frame(width: 22, height: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .white.opacity(0.45))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? activeColor : .white.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? activeColor.opacity(0.18) : Color.white.opacity(0.08))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    private func keyBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
    }
}
