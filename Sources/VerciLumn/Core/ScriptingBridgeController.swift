import Foundation
import ScriptingBridge

@objc public protocol SpotifyBridgeProtocol: NSObjectProtocol {
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func previousTrack()
    @objc optional var playerState: Int { get }
}

@objc public protocol MusicBridgeProtocol: NSObjectProtocol {
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func previousTrack()
    @objc optional var playerState: Int { get }
}

/// Low-latency macOS ScriptingBridge transport controller for Spotify and Apple Music.
/// Sends IPC commands directly via Apple Events with automatic pre-compiled NSAppleScript fallbacks.
public final class ScriptingBridgeController {
    public static let shared = ScriptingBridgeController()
    
    private let spotifyBundleId = "com.spotify.client"
    private let musicBundleId = "com.apple.Music"
    
    private lazy var spotifyBridge: SpotifyBridgeProtocol? = {
        return SBApplication(bundleIdentifier: spotifyBundleId) as? SpotifyBridgeProtocol
    }()
    
    private lazy var musicBridge: MusicBridgeProtocol? = {
        return SBApplication(bundleIdentifier: musicBundleId) as? MusicBridgeProtocol
    }()
    
    private init() {}
    
    // MARK: - Transport Actions
    
    public func togglePlayPause(source: String? = nil) {
        let activeSource = source?.lowercased() ?? ""
        if activeSource.contains("spotify") {
            if let bridge = spotifyBridge, bridge.responds(to: #selector(SpotifyBridgeProtocol.playpause)) {
                bridge.playpause?()
            } else {
                executeFallbackAppleScript(app: "Spotify", command: "playpause")
            }
        } else {
            if let bridge = musicBridge, bridge.responds(to: #selector(MusicBridgeProtocol.playpause)) {
                bridge.playpause?()
            } else {
                executeFallbackAppleScript(app: "Music", command: "playpause")
            }
        }
    }
    
    public func nextTrack(source: String? = nil) {
        let activeSource = source?.lowercased() ?? ""
        if activeSource.contains("spotify") {
            if let bridge = spotifyBridge, bridge.responds(to: #selector(SpotifyBridgeProtocol.nextTrack)) {
                bridge.nextTrack?()
            } else {
                executeFallbackAppleScript(app: "Spotify", command: "next track")
            }
        } else {
            if let bridge = musicBridge, bridge.responds(to: #selector(MusicBridgeProtocol.nextTrack)) {
                bridge.nextTrack?()
            } else {
                executeFallbackAppleScript(app: "Music", command: "next track")
            }
        }
    }
    
    public func previousTrack(source: String? = nil) {
        let activeSource = source?.lowercased() ?? ""
        if activeSource.contains("spotify") {
            if let bridge = spotifyBridge, bridge.responds(to: #selector(SpotifyBridgeProtocol.previousTrack)) {
                bridge.previousTrack?()
            } else {
                executeFallbackAppleScript(app: "Spotify", command: "previous track")
            }
        } else {
            if let bridge = musicBridge, bridge.responds(to: #selector(MusicBridgeProtocol.previousTrack)) {
                bridge.previousTrack?()
            } else {
                executeFallbackAppleScript(app: "Music", command: "previous track")
            }
        }
    }
    
    private func executeFallbackAppleScript(app: String, command: String) {
        let scriptText = """
        if application "\(app)" is running then
            tell application "\(app)" to \(command)
        end if
        """
        NSAppleScript(source: scriptText)?.executeAndReturnError(nil)
    }
}
