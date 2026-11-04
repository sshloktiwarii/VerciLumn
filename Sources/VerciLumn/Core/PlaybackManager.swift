import Foundation
import AppKit
import Combine

public struct TrackState: Equatable {
    public let title: String
    public let artist: String
    public let album: String
    public let position: TimeInterval
    public let duration: TimeInterval
    public let isPlaying: Bool
    public let sampledAt: TimeInterval
    public let artwork: NSImage?
    
    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        position: TimeInterval = 0,
        duration: TimeInterval = 0,
        isPlaying: Bool = false,
        sampledAt: TimeInterval = CACurrentMediaTime(),
        artwork: NSImage? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.position = position
        self.duration = duration
        self.isPlaying = isPlaying
        self.sampledAt = sampledAt
        self.artwork = artwork
    }
    
    public func exactPosition(withOffset offset: TimeInterval = 0) -> TimeInterval {
        guard isPlaying else { return max(0, position + offset) }
        let elapsed = CACurrentMediaTime() - sampledAt
        let raw = position + elapsed + offset
        return duration > 0 ? min(max(0, raw), duration) : max(0, raw)
    }
    
    public var exactPosition: TimeInterval {
        return exactPosition(withOffset: 0)
    }
}

public final class PlaybackManager: ObservableObject {
    public static let shared = PlaybackManager()
    
    @Published public private(set) var currentTrack: TrackState = TrackState()
    
    private var timer: AnyCancellable?
    private let pollQueue = DispatchQueue(label: "com.vercilumn.playback.poller", qos: .userInitiated)
    
    private init() {
        startPolling()
    }
    
    public func startPolling() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollActivePlayer()
            }
        pollActivePlayer()
    }
    
    public func stopPolling() {
        timer?.cancel()
        timer = nil
    }
    
    public func pollActivePlayer() {
        pollQueue.async { [weak self] in
            if let spotifyTrack = self?.querySpotify() {
                DispatchQueue.main.async {
                    self?.currentTrack = spotifyTrack
                }
                return
            }
            
            if let musicTrack = self?.queryAppleMusic() {
                DispatchQueue.main.async {
                    self?.currentTrack = musicTrack
                }
                return
            }
            
            DispatchQueue.main.async {
                if self?.currentTrack.isPlaying == true {
                    self?.currentTrack = TrackState(
                        title: self?.currentTrack.title ?? "",
                        artist: self?.currentTrack.artist ?? "",
                        album: self?.currentTrack.album ?? "",
                        position: self?.currentTrack.position ?? 0,
                        duration: self?.currentTrack.duration ?? 0,
                        isPlaying: false,
                        sampledAt: CACurrentMediaTime(),
                        artwork: self?.currentTrack.artwork
                    )
                }
            }
        }
    }
    
    private func querySpotify() -> TrackState? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set trackDuration to (duration of current track) / 1000.0
                    set trackPosition to player position
                    set artUrl to artwork url of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackPosition & "|||" & trackDuration & "|||" & artUrl
                end if
            end tell
        end if
        return "INACTIVE"
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let output = appleScript.executeAndReturnError(&error).stringValue,
              output != "INACTIVE" else {
            return nil
        }
        
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let position = Double(parts[3]) ?? 0.0
        let duration = Double(parts[4]) ?? 0.0
        
        var artworkImage: NSImage?
        if parts.count >= 6, let url = URL(string: parts[5]), !parts[5].isEmpty {
            if let data = try? Data(contentsOf: url) {
                artworkImage = NSImage(data: data)
            }
        }
        
        return TrackState(
            title: title,
            artist: artist,
            album: album,
            position: position,
            duration: duration,
            isPlaying: true,
            sampledAt: CACurrentMediaTime(),
            artwork: artworkImage
        )
    }
    
    private func queryAppleMusic() -> TrackState? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set trackDuration to duration of current track
                    set trackPosition to player position
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackPosition & "|||" & trackDuration
                end if
            end tell
        end if
        return "INACTIVE"
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let output = appleScript.executeAndReturnError(&error).stringValue,
              output != "INACTIVE" else {
            return nil
        }
        
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let position = Double(parts[3]) ?? 0.0
        let duration = Double(parts[4]) ?? 0.0
        
        var artworkImage: NSImage?
        let artScript = """
        tell application "Music"
            try
                set rawData to raw data of artwork 1 of current track
                return rawData
            end try
        end tell
        """
        if let artAppleScript = NSAppleScript(source: artScript) {
            let artDescriptor = artAppleScript.executeAndReturnError(nil)
            let data = artDescriptor.data
            if !data.isEmpty {
                artworkImage = NSImage(data: data)
            }
        }
        
        return TrackState(
            title: title,
            artist: artist,
            album: album,
            position: position,
            duration: duration,
            isPlaying: true,
            sampledAt: CACurrentMediaTime(),
            artwork: artworkImage
        )
    }
}
