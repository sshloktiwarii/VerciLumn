# VerciLumn Engine (Unified macOS Audio Visualizer & Synced Lyrics)

**VerciLumn** is a lightweight, zero-cost, menu-bar-only macOS background application (`LSUIElement = true`) unifying real-time, word-by-word lock screen lyrics (**Verci**) and beat-reactive bezel rim lighting with a frosted glass media player card (**Lumn**).

---

## 🌟 Features

- **Word-by-Word Synchronized Lyrics:** Fetches time-synced ELRC and standard lyrics via public keyless LRCLIB API (`https://lrclib.net`), with $O(\log N)$ binary search timing lookup.
- **Multi-Player Support:** Intercepts track metadata, artwork, and playback position from **Spotify** and **Apple Music** with local $T_{\text{current}} = T_{\text{sampled}} + \Delta t$ timestamp compensation.
- **4 Visual Lyric Styles:**
  1. **Standard Stack:** Clean vertical word stack with high-contrast active word highlighting.
  2. **Ship (3D Perspective):** Word stack rendered along a 3D Z-axis depth vector drifting backward into space.
  3. **Fisheye Lens:** Real-time convex spherical Metal shader distortion centered around the active word.
  4. **Visual Mode:** Real-time semantic mapping of sung words to native SF Symbols and dynamic emojis.
- **Lumn Beat-Reactive Bezel Glow:** Non-invasive system audio capture via `ScreenCaptureKit` and Accelerate `vDSP` RMS/FFT bass energy analysis ($20\text{Hz}-150\text{Hz}$) pulsing display borders.
- **Frosted Glass Media Card:** Lock screen card rendered in `.ultraThinMaterial` displaying high-res album artwork, track title, artist, and playback progress.
- **Dynamic Palette Extraction:** CoreImage `CIKMeans` color clustering extracting primary, secondary, and accent colors from album art with W3C $>4.5:1$ contrast guarantees.
- **Lock Screen Superiority:** AppKit `NSPanel` elevated to `CGWindowLevelForKey(.screenSaverWindow)` so overlays stay visible on the macOS lock screen.
- **Display Awake Assertion:** Prevents system idle display sleep during active media playback via `IOKit` `IOPMAssertion`.

---

## 🛠 Project Structure

```
├── Package.swift                             # Swift 5.10+ package manifest (macOS 14+)
├── Info.plist                                # LSUIElement & permission descriptions
├── product_requirements_document.md          # PRD specification
├── system_architecture_document.md           # Engineering architecture specification
├── design_ui_specifications.md               # Visual design & Metal shader specification
└── Sources/
    └── VerciLumn/
        ├── App/
        │   └── VerciLumnApp.swift            # @main entry point & NSStatusItem menu bar
        ├── Core/
        │   ├── AudioBeatEngine.swift         # ScreenCaptureKit audio & vDSP beat FFT
        │   ├── ColorPaletteManager.swift     # CIKMeans color clustering from album art
        │   ├── DisplaySleepManager.swift     # IOKit display sleep prevention
        │   ├── LyricsFetcher.swift           # LRCLIB client & ELRC word-sync parser
        │   ├── PlaybackManager.swift         # AppleScript Spotify/Music bridge + interpolation
        │   └── WordIconMapper.swift          # Lexicon mapping words to SF Symbols
        ├── Rendering/
        │   └── MetalShaderRenderer.swift     # Metal compute pipeline & runtime JIT compiler
        ├── Shaders/
        │   └── FisheyeShader.metal           # Fisheye lens distortion kernel
        ├── Views/
        │   ├── BezelGlowView.swift           # Display edge rim border & beat bloom
        │   ├── LumnGlassWidgetView.swift     # Frosted acrylic now-playing card
        │   ├── MenuBarView.swift             # Menu bar dropdown & controls
        │   ├── RootOverlayView.swift         # Master overlay combining Bezel, Lyrics & Card
        │   └── VerciLyricsView.swift         # 4-style synchronized lyrics presenter
        └── Windows/
            ├── LockScreenPanel.swift         # ScreenSaver-level borderless pass-through panel
            └── OverlayWindowManager.swift     # Multi-display layout manager
```

---

## 🚀 How to Run in Xcode (Step-by-Step)

### Option 1: Open Directly as Swift Package (Fastest)

1. **Launch Xcode**:
   ```bash
   open -a Xcode /Users/shloktiwari/Documents/untitled\ folder/completed\ projects/lumnnverci
   # Or directly open Package.swift:
   open Package.swift
   ```
2. **Select Scheme and Destination**:
   - In Xcode's top toolbar, click the Scheme dropdown and select **`VerciLumn` > `My Mac`**.
3. **Build & Run**:
   - Press **`⌘ + R`** (or click the Play button).
   - VerciLumn will compile and launch directly in your macOS menu bar with icon `waveform.badge.magnifyingglass`.

---

### Option 2: Run via Terminal

You can also compile and run directly from the command line:
```bash
# Build executable
swift build

# Run background executable
swift run VerciLumn
```

---

## 🔐 Required macOS Permissions (First-Time Setup)

When running for the first time, macOS will request the following permissions:

1. **Apple Events / Automation (Spotify & Apple Music)**:
   - A dialog will appear asking: *"VerciLumn wants access to control Spotify / Music"*. Click **OK**.
   - If missed, verify under: **System Settings > Privacy & Security > Automation > VerciLumn**.

2. **Screen & System Audio Recording (ScreenCaptureKit)**:
   - Required by `ScreenCaptureKit` to analyze raw system audio PCM buffers for beat detection.
   - Go to: **System Settings > Privacy & Security > Screen & System Audio Recording**.
   - Ensure the toggle for your running target or terminal is enabled.
   - *Note:* If permission has not been granted yet, VerciLumn automatically falls back to an internal rhythmic beat simulation so visuals remain smooth and functional.

3. **Background Agent Mode (`LSUIElement`)**:
   - The app runs exclusively as a menu bar agent with zero Dock clutter. To control or quit, click the waveform icon in the top macOS menu bar.

---

## 🎛 Menu Bar Controls

Clicking the VerciLumn icon in the macOS menu bar opens the control menu:
- **Lyric Visual Style**: Toggle instantly between *Standard Stack*, *Ship (3D Perspective)*, *Fisheye Lens*, and *Visual Mode*.
- **Beat-Reactive Bezel Glow**: Enable or disable display rim lighting.
- **Beat Sensitivity**: Adjust audio reaction multiplier ($0.5\times$ to $2.5\times$).
- **Engine Status**: Shows live status of playback poller and audio capture engine.
- **Quit**: Gracefully closes lock screen overlay panels and releases all assertions.

