import SwiftUI
import AppKit

public final class ScreenSaverStateModel: ObservableObject {
    @Published public var isPlaying: Bool = false
    @Published public var title: String = ""
    @Published public var artist: String = ""
    @Published public var beatIntensity: Float = 0.0
    @Published public var bands: [Float] = Array(repeating: 0.0, count: 8)
    @Published public var phase: Double = 0.0
    public let isPreview: Bool
    
    public init(isPreview: Bool = false) {
        self.isPreview = isPreview
        refreshState()
    }
    
    public func stepFrame() {
        refreshState()
        // Thermal invariant: 0% idle GPU when paused unless in preview mode
        guard isPlaying || isPreview else { return }
        phase += 0.04
    }
    
    public func refreshState() {
        let defaults = UserDefaults(suiteName: "group.com.vercilumn.engine") ?? UserDefaults.standard
        let playing = defaults.bool(forKey: "saver_is_playing")
        let t = defaults.string(forKey: "saver_track_title") ?? ""
        let a = defaults.string(forKey: "saver_track_artist") ?? ""
        let beat = Float(defaults.double(forKey: "saver_beat_intensity"))
        let rawBands = defaults.array(forKey: "saver_spectrum_bands") as? [Double] ?? []
        
        let parsedBands: [Float]
        if rawBands.count == 8 {
            parsedBands = rawBands.map { Float($0) }
        } else if playing || isPreview {
            // Harmonic breathing wave fallback
            let simWave = Float(sin(phase * 1.2) * 0.25 + 0.35)
            parsedBands = (0..<8).map { i in
                Float(sin(phase * 0.8 + Double(i) * 0.5) * 0.2 + Double(simWave))
            }
        } else {
            parsedBands = Array(repeating: 0.0, count: 8)
        }
        
        if playing {
            if self.isPlaying != true { self.isPlaying = true }
            if self.title != t { self.title = t }
            if self.artist != a { self.artist = a }
            self.beatIntensity = beat
            self.bands = parsedBands
        } else if isPreview {
            if self.isPlaying != false { self.isPlaying = false }
            let previewTitle = t.isEmpty ? "VerciLumn" : t
            let previewArtist = a.isEmpty ? "Ambient Visualizer" : a
            if self.title != previewTitle { self.title = previewTitle }
            if self.artist != previewArtist { self.artist = previewArtist }
            self.beatIntensity = Float(sin(phase * 1.5) * 0.2 + 0.3)
            self.bands = parsedBands
        } else {
            // Strictly idle: 0% GPU, zero unnecessary state mutations
            if self.isPlaying != false { self.isPlaying = false }
            if self.title != "" { self.title = "" }
            if self.artist != "" { self.artist = "" }
            if self.beatIntensity != 0.0 { self.beatIntensity = 0.0 }
            if self.bands != Array(repeating: 0.0, count: 8) { self.bands = Array(repeating: 0.0, count: 8) }
        }
    }
}

public struct VerciLumnSaverContentView: View {
    @ObservedObject var model: ScreenSaverStateModel
    var isPreview: Bool
    
    public init(model: ScreenSaverStateModel = ScreenSaverStateModel(), isPreview: Bool = false) {
        self.model = model
        self.isPreview = isPreview
    }
    
    public var body: some View {
        GeometryReader { geo in
            let scale: CGFloat = isPreview ? 0.45 : 1.0
            let bands = model.bands
            let phase = model.phase
            
            // Multi-zone energies
            let b0 = bands.indices.contains(0) ? CGFloat(bands[0]) : 0.05
            let b1 = bands.indices.contains(1) ? CGFloat(bands[1]) : 0.05
            let b2 = bands.indices.contains(2) ? CGFloat(bands[2]) : 0.05
            let b3 = bands.indices.contains(3) ? CGFloat(bands[3]) : 0.05
            let b4 = bands.indices.contains(4) ? CGFloat(bands[4]) : 0.05
            let b5 = bands.indices.contains(5) ? CGFloat(bands[5]) : 0.05
            let b6 = bands.indices.contains(6) ? CGFloat(bands[6]) : 0.05
            let b7 = bands.indices.contains(7) ? CGFloat(bands[7]) : 0.05
            
            let bottomPulse = min(1.0, b0 * 0.75 + b1 * 0.25)
            let leftPulse   = min(1.0, b2 * 0.5 + b3 * 0.5)
            let rightPulse  = min(1.0, b4 * 0.5 + b5 * 0.5)
            let topPulse    = min(1.0, b6 * 0.5 + b7 * 0.5)
            let maxPulse    = max(bottomPulse, max(leftPulse, max(rightPulse, topPulse)))
            
            // Dynamic Ambilight Colors
            let bottomColor = Color(red: 0.95, green: 0.25, blue: 0.3)  // Sub-bass crimson
            let leftColor   = Color(red: 0.2, green: 0.85, blue: 0.5)  // Midrange emerald
            let rightColor  = Color(red: 0.25, green: 0.55, blue: 0.95) // Presence sapphire
            let topColor    = Color(red: 0.85, green: 0.4, blue: 0.95) // Treble air violet
            
            ZStack {
                // Background: Obsidian
                Color(red: 0.02, green: 0.02, blue: 0.04)
                    .ignoresSafeArea()
                
                // MARK: - Multi-Zone Ambilight Perimeter Glows
                // Bottom Bloom (Sub-Bass)
                LinearGradient(
                    gradient: Gradient(colors: [
                        bottomColor.opacity(Double(bottomPulse) * 0.75),
                        bottomColor.opacity(Double(bottomPulse) * 0.2),
                        Color.clear
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: max(24 * scale, 90 * bottomPulse * scale))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .blur(radius: (16 + 12 * bottomPulse) * scale)
                
                // Top Bloom (Treble Air)
                LinearGradient(
                    gradient: Gradient(colors: [
                        topColor.opacity(Double(topPulse) * 0.7),
                        topColor.opacity(Double(topPulse) * 0.2),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(20 * scale, 75 * topPulse * scale))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .blur(radius: (14 + 10 * topPulse) * scale)
                
                // Left Bloom (Mids / Vocals)
                LinearGradient(
                    gradient: Gradient(colors: [
                        leftColor.opacity(Double(leftPulse) * 0.7),
                        leftColor.opacity(Double(leftPulse) * 0.2),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: max(20 * scale, 75 * leftPulse * scale))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .blur(radius: (14 + 10 * leftPulse) * scale)
                
                // Right Bloom (High-Mids / Percussion)
                LinearGradient(
                    gradient: Gradient(colors: [
                        rightColor.opacity(Double(rightPulse) * 0.7),
                        rightColor.opacity(Double(rightPulse) * 0.2),
                        Color.clear
                    ]),
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .frame(width: max(20 * scale, 75 * rightPulse * scale))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .blur(radius: (14 + 10 * rightPulse) * scale)
                
                // MARK: - Perimeter Bezel Stroke
                let strokeWidth = (2.0 + maxPulse * 4.0) * scale
                let perimeterGradient = AngularGradient(
                    stops: [
                        .init(color: topColor.opacity(Double(topPulse)), location: 0.0),
                        .init(color: rightColor.opacity(Double(rightPulse)), location: 0.25),
                        .init(color: bottomColor.opacity(Double(bottomPulse)), location: 0.5),
                        .init(color: leftColor.opacity(Double(leftPulse)), location: 0.75),
                        .init(color: topColor.opacity(Double(topPulse)), location: 1.0)
                    ],
                    center: .center
                )
                
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .stroke(perimeterGradient, lineWidth: strokeWidth)
                    .padding(3 * scale)
                    .shadow(color: bottomColor.opacity(Double(bottomPulse) * 0.4), radius: 8 * scale)
                    .ignoresSafeArea()
                
                // MARK: - Center Stage: Audio-Reactive Orb & Track Telemetry
                VStack(spacing: 16 * scale) {
                    // Hypnotic Pulsing Center Orb
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        topColor.opacity(0.35 + Double(maxPulse) * 0.45),
                                        leftColor.opacity(0.2 + Double(leftPulse) * 0.3),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: (80 + 40 * maxPulse) * scale
                                )
                            )
                            .frame(width: (180 + 80 * maxPulse) * scale, height: (180 + 80 * maxPulse) * scale)
                            .blur(radius: 20 * scale)
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [topColor, rightColor, bottomColor, leftColor, topColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2 * scale
                            )
                            .frame(width: (120 + 30 * CGFloat(model.beatIntensity)) * scale, height: (120 + 30 * CGFloat(model.beatIntensity)) * scale)
                            .rotationEffect(.radians(phase * 0.5))
                            .shadow(color: topColor.opacity(0.6), radius: 10 * scale)
                    }
                    
                    // Track Information or Ambient Title
                    VStack(spacing: 6 * scale) {
                        if model.isPlaying && !model.title.isEmpty {
                            Text(model.title)
                                .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: Color.black.opacity(0.7), radius: 6)
                            
                            if !model.artist.isEmpty {
                                Text(model.artist)
                                    .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(bottomColor)
                                    .frame(width: 6 * scale, height: 6 * scale)
                                    .scaleEffect(1.0 + CGFloat(model.beatIntensity) * 0.6)
                                Text("VerciLumn Ambient")
                                    .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 4 * scale)
                        } else {
                            Text("VerciLumn")
                                .font(.system(size: 26 * scale, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.7), radius: 6)
                            
                            Text("Ambient Screen Saver")
                                .font(.system(size: 13 * scale, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
    }
}
