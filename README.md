# VerciLumn

A lightweight macOS menu bar utility (`LSUIElement = true`) providing real-time, word-synchronized lyrics, audio-reactive visualizers, and interactive playback controls across both the desktop and the macOS lock screen.

Supports **Spotify** and **Apple Music** with zero account configuration.

---

## Capabilities

### Word-Synchronized Lyrics & Interactive Navigation
- **Word-Level Sync:** Ingests synchronized ELRC and standard LRC lyrics from LRCLIB with automated fallback to NetEase Cloud Music.
- **Microsecond Binary Search:** Fast $O(\log N)$ timestamp resolution locates active words and lines with zero frame stutter.
- **Two-Line Interactive Reel:** Click the previous lyric line to jump back, or click the next line to skip ahead. Word tokens support tap-to-seek directly to vocal markers.
- **Dynamic Delta Pacing:** On tracks with line-level timestamps, inter-line deltas interpolate natural word progress without artificial fixed steps.
- **Offline Memory Cache:** `NSCache` retains parsed lyric models for repeated tracks without redundant network round-trips.

### Interactive Transport Dock
- **Tactile Scrub Bar:** Acrylic glass capsule with draggable seek timeline, elapsed and remaining duration counters.
- **Direct Rewind & Fast-Forward:** Instant `-5s` and `+5s` seek buttons communicating with Spotify and Apple Music via AppleScript.
- **Non-Overlapping Stage Layout:** Positioned cleanly at the bottom edge without colliding with audio waveforms or active lyrics.
- **Coordinate-Aware Hit-Testing:** Transparent stage areas pass mouse events through to underlying applications; dock and lyric controls capture clicks with zero activation lag (`acceptsFirstMouse`).

### Visual Backdrops & Audio Engines
- **Hypnotic Geometric Zoom Tunnel:** Delta-time continuous phase integration (`ContinuousTunnelPhase`) driving 24 concentric regular octagons and inscribed diamond star lattices. The zoom rate reacts smoothly to song BPM, bass energy, and transient audio spikes over an opaque dark stage.
- **Audio-Reactive Particle Cosmos:** 120-particle velocity field driven by 8-band FFT audio spectrum analysis.
- **Pure Black (OLED):** True black canvas for distraction-free night listening.
- **Transparent Pass-Through:** Minimalist heads-up display revealing your desktop wallpaper.
- **Audio Processing:** Non-invasive system audio capture via `ScreenCaptureKit` and Accelerate `vDSP` FFT (Sub-Bass, Bass, Low-Mid, Mid, High-Mid, Presence, Brilliance, Air) with automatic rhythmic simulation fallback when recording permissions are absent.

### Curated Color Palettes & Editorial Typography
- **8 Color Themes:**
  - *Album Reactive:* Dynamic palette extracted from cover art via CoreImage `CIKMeans` clustering with W3C contrast enforcement.
  - *Black & White:* High-contrast monochrome for minimalist setups.
  - *Rainbow Spectrum:* Prismatic multi-hue gradient.
  - *Red Family:* Crimson, ruby, and warm scarlet.
  - *Purple Family Soft:* Lavender, lilac, and violet.
  - *Blue Family:* Electric cyan, cobalt, and deep ocean.
  - *Green Family:* Mint, emerald, and sage.
  - *Brown Family:* Caramel, bronze, and warm earth.
- **4 Typography Styles:** SF Pro Rounded, New York Editorial Serif, Industrial Monospace, SF Pro Display.

### Lock Screen & Stage Immersion
- **Lock Screen Superiority:** Elevates to `CGShieldingWindowLevel()` on lock events (`com.apple.screenIsLocked`, `screensDidSleep`) so lyrics remain visible while your Mac is locked.
- **Display Awake Assertion:** Prevents display sleep during active playback via IOKit `IOPMAssertionCreateWithName`.

---

## Global Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘ + ⇧ + L` | Toggle Full Stage Immersion Overlay |
| `⌘ + ⇧ + N` | Toggle Dynamic Notch Island |
| `⌘ + ⌥ + →` | Cycle Lyric Animation Styles |
| `⌘ + [` | Vocal Sync Timing Offset -50ms |
| `⌘ + ]` | Vocal Sync Timing Offset +50ms |
| `⌘ + ⇧ + Space` | Play / Pause Toggle |

---

## Project Structure

```
├── Package.swift                             # Swift 5.10+ package manifest (macOS 14+)
├── Info.plist                                # LSUIElement & permission declarations
├── Sources/
│   └── VerciLumn/
│       ├── App/
│       │   └── VerciLumnApp.swift            # NSApplicationDelegate & MenuBarExtra entry
│       ├── Core/
│       │   ├── AppSettings.swift             # Persistent UserDefaults settings store
│       │   ├── AudioBeatEngine.swift         # ScreenCaptureKit audio stream & beat analyzer
│       │   ├── AudioSpectrumEngine.swift     # Accelerate vDSP 8-band FFT spectrum processor
│       │   ├── ColorPaletteManager.swift     # CIKMeans color extraction from album art
│       │   ├── DisplaySleepManager.swift     # IOKit display sleep assertion manager
│       │   ├── HotKeyManager.swift           # NSEvent global hotkeys & idle sleep detector
│       │   ├── LyricsFetcher.swift           # LRCLIB & NetEase API fetcher & LRC parser
│       │   ├── PlaybackManager.swift         # Spotify & Music state poller and transport
│       │   ├── ThemeManager.swift            # Color presets & typography selection
│       │   └── WordSemanticEngine.swift      # Lexicon sentiment & visual effect resolver
│       ├── Shaders/
│       │   └── FisheyeShader.metal           # Metal compute & stitchable distortion shader
│       ├── Views/
│       │   ├── BezelGlowView.swift           # Display rim glow stroke view
│       │   ├── DynamicNotchHUDView.swift     # MacBook camera notch expanding island
│       │   ├── InfiniteZoomTunnelView.swift  # BPM-reactive geometric tunnel canvas
│       │   ├── InteractivePlaybackScrubberView.swift # Timeline scrub bar & seek buttons
│       │   ├── LiquidWaveformView.swift      # Harmonic ripple audio rings
│       │   ├── LumnGlassWidgetView.swift     # Frosted glass now-playing card
│       │   ├── MenuBarView.swift             # Native macOS dropdown settings popover
│       │   ├── ParticleCosmosView.swift      # Audio-reactive floating particle field
│       │   ├── RootOverlayView.swift         # Full-screen hierarchy & backdrop orchestrator
│       │   ├── SemanticWordView.swift        # Active singing word styling & highlight
│       │   ├── VerciLyricsView.swift         # Synced lyrics presentation styles
│       │   └── VinylTurntableView.swift      # 3D grooved vinyl record with tonearm
│       └── Windows/
│           ├── DynamicNotchPanel.swift       # Notch panel positioning & lifecycle
│           ├── LockScreenPanel.swift         # Full-screen borderless window & hit-test routing
│           └── OverlayWindowManager.swift    # Multi-monitor management & lock screen coordinator
└── Tests/
    └── VerciLumnTests/
        └── VerciLumnTests.swift              # Unit test suite (timing, ELRC, settings)
```

---

## Build & Run

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 15.0+ / Swift 5.10+
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

### Build from Command Line
```bash
# Clone the repository
git clone https://github.com/sshloktiwarii/VerciLumn.git
cd VerciLumn

# Run automated tests
swift test

# Build release binary
swift build -c release

# Launch background application
swift run VerciLumn
```

### Build with Xcode
```bash
open Package.swift
```
Select the `VerciLumn` scheme and press `⌘ + R`.

---

## Required macOS Permissions

On first launch, macOS will prompt for the following system permissions:
1. **Automation (Apple Events):** Allows VerciLumn to read track metadata and seek in Spotify and Apple Music. Verify in *System Settings > Privacy & Security > Automation*.
2. **Screen & System Audio Recording (Optional):** Required by `ScreenCaptureKit` to analyze raw system audio PCM buffers for live beat reaction. If disabled, VerciLumn automatically falls back to an internal rhythmic simulation with zero visual degradation.
3. **Accessibility (Optional):** Required for global keyboard shortcuts (`⌘ + ⇧ + L`, etc.) when other applications have focus. Verify in *System Settings > Privacy & Security > Accessibility*.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
