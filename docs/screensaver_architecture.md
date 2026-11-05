# VerciLumn Native Screen Saver Architecture (.saver Bundle)

## Why a Screen Saver instead of WindowServer LockScreen Hacks?
macOS explicitly isolates the loginwindow (`loginwindow` process) behind system integrity protection and shield levels (`CGShieldingWindowLevel()`). Attempting to inject `NSWindow` or `NSPanel` above this shield level using `CGShieldingWindowLevel() + 1` causes WindowServer kernel faults, sudden app kills, and security warnings on macOS Sonoma (14.x) and Sequoia (15.x).

The official, secure, sandboxed method to render ambient audio-reactive visuals while the Mac is locked or idle is building a native macOS Screen Saver (`.saver` bundle) via Apple's official `ScreenSaverView` API.

---

## Architecture Overview

```
VerciLumn.app (Main Application)
│
├── AppSettings (Defaults domain: "group.com.vercilumn.engine")
├── AudioBeatEngine / PlaybackManager
│
└── IPC / Shared Memory (Mach port or shared UserDefaults)
      │
      ▼
VerciLumnSaver.saver (Native Screen Saver Bundle)
├── VerciLumnSaverView : ScreenSaverView
├── Metal / MTKView Pipeline (Fisheye & Aurora shaders)
└── Info.plist (Principal Class: VerciLumnSaverView)
```

## ScreenSaverView Implementation Pattern

```swift
import ScreenSaver
import MetalKit

public final class VerciLumnSaverView: ScreenSaverView {
    private var renderer: MetalShaderRenderer?
    private var isPlaying: Bool = false
    
    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.animationTimeInterval = 1.0 / 30.0 // 30 FPS cap for battery & thermals
        setupRenderer()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.animationTimeInterval = 1.0 / 30.0
        setupRenderer()
    }
    
    private func setupRenderer() {
        // Safe, sandboxed metal rendering within system ScreenSaver context
    }
    
    public override func animateOneFrame() {
        // Read shared now-playing state and render frame
    }
}
```

## Installation & Deployment
1. Build Target: `VerciLumnSaver.saver`
2. Destination: `~/Library/Screen Savers/VerciLumnSaver.saver` or `/Library/Screen Savers/`
3. Activation: Configurable via macOS System Settings > Wallpaper / Screen Saver.

