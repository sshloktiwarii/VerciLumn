# Design & Visual Engine Specification

---

## 1. Visual Aesthetics & Design System

* **Typography:** System SF Pro Display (`.rounded` design variant), variable font weight ranging from `.medium` to `.black`.
* **Materials:** High-density frosted acrylic (`.ultraThinMaterial` / `CAFilter`).
* **Color System:** Dynamic album-reactive palette with high contrast mapping ($>4.5:1$ W3C contrast ratio standard for lyric readability).

---

## 2. Metal Shader Specification (Fisheye Lens Distortion)

The **Fisheye Lens Shader** distorts text nodes around the active word position in real-time.

```metal
#include <metal_stdlib>
using namespace metal;

kernel void fisheyeDistortion(texture2d<float, access::read> inTexture [[texture(0)]],
                             texture2d<float, access::write> outTexture [[texture(1)]],
                             constant float2 &center [[buffer(0)]],
                             constant float &radius [[buffer(1)]],
                             constant float &strength [[buffer(2)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    float2 size = float2(inTexture.get_width(), inTexture.get_height());
    float2 uv = float2(gid) / size;
    float2 delta = uv - center;
    float dist = length(delta);
    
    if (dist < radius) {
        float percent = dist / radius;
        float distortion = pow(percent, strength);
        float2 distortedUV = center + normalize(delta) * distortion * radius;
        uint2 readCoords = uint2(distortedUV * size);
        outTexture.write(inTexture.read(readCoords), gid);
    } else {
        outTexture.write(inTexture.read(gid), gid);
    }
}
```

---

## 3. UI Layer & Component Tree

```
OverlayView (Root View)
├── BezelGlowView (Display Edge Rim Border)
│   └── Canvas / Dynamic LinearGradient Stroke
│       └── Animatable Modifier (Pulse Scale & Blur)
│
├── VerciLyricsView (Centered Synced Overlay)
│   ├── Mode 1: Standard Stack View (VStack + Transitions)
│   ├── Mode 2: Ship View (3D Projection Perspective Rotation)
│   ├── Mode 3: Fisheye View (Metal Shader Filter Host)
│   └── Mode 4: Visual View (Word + SF Symbol / Emoji Dynamic Match)
│
└── LumnGlassWidgetView (Lock Screen Now-Playing Card)
    ├── AsyncImage (Album Art with 12pt Corner Radius)
    ├── VStack (Track Title + Artist Label)
    └── PlaybackProgressIndicator Bar
```

---

## 4. Word-to-Icon Mapping Dictionary (Visual Mode)

Mapping array embedded in `WordIconMapper.swift` for instant lookup:

```swift
let wordToIconMap: [String: String] = [
    // Vehicles & Travel
    "car": "car.fill",
    "cars": "car.fill",
    "drive": "steeringwheel",
    "fly": "airplane",
    
    // Actions & Expressions
    "swish": "hand.point.up.left.fill",
    "look": "eye.fill",
    "hear": "ear",
    "heart": "heart.fill",
    "love": "heart.fill",
    "like": "hand.thumbsup.fill",
    
    // Objects & Symbols
    "button": "button.horizontal.top.press",
    "chances": "dice.fill",
    "time": "clock.fill",
    "star": "star.fill",
    "fire": "flame.fill",
    "music": "music.note"
]

func getSymbol(for word: String) -> String? {
    let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    return wordToIconMap[clean]
}
```