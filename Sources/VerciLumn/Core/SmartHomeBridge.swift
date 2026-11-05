import Foundation
import Combine
import SwiftUI

public enum SmartHomeProtocol: String, CaseIterable, Identifiable {
    case disabled = "Disabled"
    case philipsHue = "Philips Hue (Local REST CLIP v2)"
    case nanoleaf = "Nanoleaf Light Panels (OpenAPI)"
    
    public var id: String { rawValue }
}

/// Lightweight, non-blocking local network synchronization bridge for Philips Hue and Nanoleaf
public final class SmartHomeBridge: ObservableObject {
    public static let shared = SmartHomeBridge()
    
    @Published public var activeProtocol: SmartHomeProtocol = .disabled
    @Published public var bridgeHost: String = ""       // e.g. "192.168.1.100"
    @Published public var apiToken: String = ""         // Hue username / Nanoleaf auth token
    @Published public var targetLightId: String = "1"   // Target light or group ID
    
    private var cancellables = Set<AnyCancellable>()
    private let networkQueue = DispatchQueue(label: "com.vercilumn.smarthome.queue", qos: .utility)
    private let session: URLSession
    
    private var lastDispatchedColor: Color?
    private var lastDispatchTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 0.5 // Limit to 2 requests per second to avoid flooding local IoT bridge
    
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        self.session = URLSession(configuration: config)
        
        // Listen to active palette changes
        ColorPaletteManager.shared.$currentPalette
            .sink { [weak self] palette in
                self?.syncColorToSmartHome(palette.highlightAccent)
            }
            .store(in: &cancellables)
    }
    
    public func syncColorToSmartHome(_ color: Color) {
        guard activeProtocol != .disabled, !bridgeHost.isEmpty, !apiToken.isEmpty else { return }
        
        let now = CACurrentMediaTime()
        guard now - lastDispatchTime >= throttleInterval else { return }
        lastDispatchTime = now
        
        // Convert SwiftUI Color to RGB Float components
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.white
        let r = Float(nsColor.redComponent)
        let g = Float(nsColor.greenComponent)
        let b = Float(nsColor.blueComponent)
        
        networkQueue.async { [weak self] in
            guard let self = self else { return }
            switch self.activeProtocol {
            case .philipsHue:
                self.dispatchHueColor(r: r, g: g, b: b)
            case .nanoleaf:
                self.dispatchNanoleafColor(r: r, g: g, b: b)
            case .disabled:
                break
            }
        }
    }
    
    // MARK: - Philips Hue Local REST API
    private func dispatchHueColor(r: Float, g: Float, b: Float) {
        // Approximate RGB -> CIE 1931 XY coordinates for Philips Hue gamut
        let x = (r * 0.664511) + (g * 0.154324) + (b * 0.162028)
        let y = (r * 0.283881) + (g * 0.0668459) + (b * 0.048126)
        let z = (r * 0.000088) + (g * 0.072310) + (b * 0.986039)
        let sum = x + y + z
        let cx = sum > 0 ? (x / sum) : 0.3127
        let cy = sum > 0 ? (y / sum) : 0.3290
        
        guard let url = URL(string: "http://\(bridgeHost)/api/\(apiToken)/lights/\(targetLightId)/state") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "on": true,
            "xy": [cx, cy],
            "bri": Int(max(r, max(g, b)) * 254.0),
            "transitiontime": 2 // 200ms smooth transition
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        session.dataTask(with: request).resume()
    }
    
    // MARK: - Nanoleaf OpenAPI
    private func dispatchNanoleafColor(r: Float, g: Float, b: Float) {
        guard let url = URL(string: "http://\(bridgeHost):16021/api/v1/\(apiToken)/state") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert RGB to HSV
        let ns = NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        let hue = Int(ns.hueComponent * 360.0)
        let sat = Int(ns.saturationComponent * 100.0)
        let bri = Int(ns.brightnessComponent * 100.0)
        
        let payload: [String: Any] = [
            "hue": ["value": hue],
            "sat": ["value": sat],
            "brightness": ["value": max(10, bri)]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        session.dataTask(with: request).resume()
    }
}

