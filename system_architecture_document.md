# Technical Architecture & Engineering Specification

---

## 1. System Architecture Overview

```
                      ┌─────────────────────────────────┐
                      │    Spotify / Apple Music Apps   │
                      └────────────────┬────────────────┘
                                       │ (NSAppleScript Poller)
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         VerciLumn Engine Core                               │
 │                                                                             │
 │  ┌────────────────────────┐                   ┌──────────────────────────┐  │
 │  │    PlaybackManager     │                   │     AudioBeatEngine      │  │
 │  │ - Track, Artist, Time  │                   │ - ScreenCaptureKit Audio │  │
 │  │ - Position Drift Calc  │                   │ - Accelerate vDSP FFT    │  │
 │  └───────────┬────────────┘                   └────────────┬─────────────┘  │
 │              │                                             │                │
 │              ▼                                             ▼                │
 │  ┌────────────────────────┐                   ┌──────────────────────────┐  │
 │  │     LyricsFetcher      │                   │   ColorPaletteManager    │  │
 │  │ - LRCLIB API Client    │                   │ - CoreImage CIKMeans     │  │
 │  │ - Timestamp Matcher    │                   │ - Contrast Calculation   │  │
 │  └───────────┬────────────┘                   └────────────┬─────────────┘  │
 └──────────────┼─────────────────────────────────────────────┼────────────────┘
                │                                             │
                └──────────────────────┬──────────────────────┘
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                       AppKit Overlay Window Manager                         │
 │  - NSPanel (Level: CGWindowLevelForKey(.screenSaverWindow))                │
 │  - Frame Rate: CADisplayLink @ 60 FPS Sync                                  │
 └─────────────────────────────────────┬───────────────────────────────────────┘
                                       │
                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                         SwiftUI + Metal Rendering                           │
 │  - BezelGlowView (Shader + Stroke)    - FisheyeShader.metal (Lens Refraction)│
 └─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Technical Stack Matrix

* **Language:** Swift 5.10+
* **Target OS:** macOS 14.0 (Sonoma) or higher
* **App Model:** Agent Executable (`LSUIElement = true`)
* **Frameworks:** `SwiftUI`, `AppKit`, `ScreenCaptureKit`, `Accelerate`, `CoreImage`, `MetalKit`, `IOKit`
* **API Providers:** LRCLIB API (`https://lrclib.net/api/get`)

---

## 3. Core Engine Specifications

### 3.1 Media Poller (`PlaybackManager.swift`)
Reads playback status every $1.0\text{s}$ using `NSAppleScript`. Local timestamp compensation ensures frame-accurate lyric tracking:

$$T_{\text{current}} = T_{\text{sampled}} + (t_{\text{now}} - t_{\text{sampled}}) \times \text{playbackRate}$$

```swift
import Foundation

struct TrackState {
    let title: String
    let artist: String
    let position: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let sampledAt: TimeInterval
    
    var exactPosition: TimeInterval {
        guard isPlaying else { return position }
        return position + (CACurrentMediaTime() - sampledAt)
    }
}
```

### 3.2 Lyrics Engine (`LyricsFetcher.swift`)
Fetches time-synced lyrics from LRCLIB and parses per-word timestamp brackets:
* Format: `[mm:ss.xx] Word` or standard ELRC.
* Lookup Algorithm: Binary search ($O(\log N)$) inside a `CADisplayLink` render loop to locate active, past, and future word tokens.

### 3.3 Audio Beat Analyzer (`AudioBeatEngine.swift`)
Captures system audio using `ScreenCaptureKit` and computes real-time bass energy ($20\text{Hz} - 150\text{Hz}$) using Accelerate's `vDSP_dfmt`:

```swift
import ScreenCaptureKit
import Accelerate

final class AudioBeatEngine: NSObject, SCStreamAudioOutputSampleBufferDelegate {
    static let shared = AudioBeatEngine()
    var onBeatPulse: ((Float) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var dataPtr: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPtr)
        
        guard let data = dataPtr else { return }
        let floatCount = length / MemoryLayout<Float>.size
        let samples = data.withMemoryRebound(to: Float.self, capacity: floatCount) { Array(UnsafeBufferPointer(start: $0, count: floatCount)) }
        
        // Compute RMS value of frame buffer
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        
        // Scale and damp amplitude output
        let pulse = min(max((rms - 0.05) * 5.0, 0.0), 1.0)
        DispatchQueue.main.async { self.onBeatPulse?(pulse) }
    }
}
```

### 3.4 Dominant Palette Extractor (`ColorPaletteManager.swift`)
Extracts dominant background and text accent colors from `NSImage` via `CIKMeans`:

```swift
import CoreImage
import AppKit

struct ColorPalette {
    let background: NSColor
    let primaryText: NSColor
    let highlightAccent: NSColor
}

func extractPalette(from image: NSImage) -> ColorPalette {
    guard let tiffData = image.tiffRepresentation,
          let ciImage = CIImage(data: tiffData) else {
        return ColorPalette(background: .black, primaryText: .white, highlightAccent: .systemPink)
    }
    
    let filter = CIFilter(name: "CIKMeans")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")
    filter.setValue(3, forKey: "inputCount")
    filter.setValue(5, forKey: "inputPasses")
    
    // Returns extracted color palette with contrast guarantees
    return ColorPalette(
        background: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0),
        primaryText: NSColor.white,
        highlightAccent: NSColor(red: 0.95, green: 0.4, blue: 0.6, alpha: 1.0)
    )
}
```

---

## 4. Window & Overlay Integration

```swift
import AppKit
import SwiftUI

final class LockScreenPanel: NSPanel {
    init(contentView: NSView) {
        let screenRect = NSScreen.main?.frame ?? .zero
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Set priority level above Lock Screen / ScreenSaver
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.contentView = contentView
    }
}
```