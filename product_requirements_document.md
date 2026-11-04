# Product Requirements Document (PRD)
## Project Name: VerciLumn Engine (Unified macOS Audio Visualizer & Synced Lyrics)

---

## 1. Executive Summary
**VerciLumn** is a lightweight, zero-cost, menu-bar-only macOS background application that unifies the capabilities of **Verci** (word-by-word real-time lock screen lyrics) and **Lumn** (beat-reactive bezel rim lighting and frosted glass media player). The application runs seamlessly over both the active desktop and the macOS system lock screen without requiring main window management or user accounts.

---

## 2. Core Capabilities & Feature Set

### 2.1 Verci Engine (Word-Synced Lock Screen Lyrics)
* **Per-Word Timed Lyrics:** Fetch and display real-time lyrics that light up word-by-word in sync with the song lead vocal rather than line-by-line scrolling.
* **Multi-Player Support:** Intercept track metadata, elapsed time, and playback status from Spotify and Apple Music via native macOS scripting.
* **Four Visual Styles:**
  1. **Standard Stack:** Clean vertical text list with high-contrast active word highlighting.
  2. **Ship (3D Perspective):** Word stack rendered along a 3D Z-axis depth vector drifting backward in space.
  3. **Fisheye:** Real-time convex spherical Metal shader distortion centered around the current active word.
  4. **Visual Mode:** Automatic mapping of ~770 common English words to native SF Symbols and Emojis dynamically popped beside sung words.

### 2.2 Lumn Engine (Beat-Reactive Bezel Lighting)
* **Real-time Audio FFT Beat Detection:** Non-invasive system audio capture using `ScreenCaptureKit` to analyze raw PCM buffers and trigger low-pass bass energy beat pulses.
* **Screen Bezel Glow:** Dynamic gradient border surrounding display edges with customizable stroke width, blur radius, and pulsing intensity keyed to audio beats.
* **Frosted Glass Media Card:** Lock screen glass widget displaying high-resolution album artwork, track title, artist name, and playback controls formatted in `.ultraThinMaterial`.
* **Auto-Sync Palette Extraction:** Real-time CoreImage color clustering using `CIKMeans` to pull primary, secondary, and accent glow colors directly from album artwork.

---

## 3. Non-Functional Requirements & Constraints

* **Zero Financial Cost:** Must build using only native macOS SDKs (Swift, SwiftUI, AppKit, Metal, Accelerate, ScreenCaptureKit) and public keyless APIs (LRCLIB). No paid Apple Developer account ($99/yr) required for local compilation.
* **System Integration:** Must execute as a background agent (`LSUIElement = true`) with zero Dock presence.
* **Lock Screen Superiority:** Render windows elevated to `CGWindowLevelForKey(.screenSaverWindow)` so overlays stay visible when macOS locks.
* **Power & Performance:** CPU utilization $< 3\%$ during playback, using `CADisplayLink` frame-throttling and hardware-accelerated Metal fragment shaders.
* **Display Awake Assertions:** Prevent system idle display sleep during active media playback via `IOKit` `IOPMAssertion`.

---

## 4. User Stories

| ID | As a... | I want to... | So that... |
| :--- | :--- | :--- | :--- |
| **US-01** | Music Listener | See lyrics light up word-by-word on my lock screen | I can sing along precisely with the music without unlocking my Mac. |
| **US-02** | Desk Setup Enthusiast | Have my display edges pulse to the bass beat | My Mac display creates an ambient light show matched to my playlist. |
| **US-03** | Minimalist User | Access all controls strictly through the macOS Menu Bar | No windows or dock icons clutter my workspace. |
| **US-04** | Spotify / Apple Music User | Have album colors automatically drive text and bezel lighting | The visual theme updates instantly whenever the track changes. |