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
    public let playerSource: String
    
    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        position: TimeInterval = 0,
        duration: TimeInterval = 0,
        isPlaying: Bool = false,
        sampledAt: TimeInterval = CACurrentMediaTime(),
        artwork: NSImage? = nil,
        playerSource: String = "None"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.position = position
        self.duration = duration
        self.isPlaying = isPlaying
        self.sampledAt = sampledAt
        self.artwork = artwork
        self.playerSource = playerSource
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
    
    public var progress: Double {
        guard duration > 0 else { return 0.0 }
        return min(max(exactPosition / duration, 0.0), 1.0)
    }
}

public final class PlaybackManager: ObservableObject {
    public static let shared = PlaybackManager()
    
    @Published public private(set) var currentTrack: TrackState = TrackState()
    
    private var timer: AnyCancellable?
    private let pollQueue = DispatchQueue(label: "com.vercilumn.playback.poller", qos: .userInitiated)
    
    // Artwork Cache with strict memory bounds
    private let artworkCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 64
        return cache
    }()
    private var fetchingUrls = Set<String>()
    private let urlLock = NSLock()
    
    // Pre-compiled AppleScripts
    private let spotifyPollScript: NSAppleScript? = {
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
        return NSAppleScript(source: script)
    }()
    
    private let musicPollScript: NSAppleScript? = {
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
        return NSAppleScript(source: script)
    }()
    
    private let musicArtworkScript: NSAppleScript? = {
        let script = """
        tell application "Music"
            try
                return raw data of artwork 1 of current track
            end try
        end tell
        """
        return NSAppleScript(source: script)
    }()
    
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
            guard let self = self else { return }
            
            if let spotifyTrack = self.querySpotify() {
                DispatchQueue.main.async {
                    self.updateTrackState(spotifyTrack)
                }
                return
            }
            
            if let musicTrack = self.queryAppleMusic() {
                DispatchQueue.main.async {
                    self.updateTrackState(musicTrack)
                }
                return
            }
            
            DispatchQueue.main.async {
                if self.currentTrack.isPlaying {
                    self.currentTrack = TrackState(
                        title: self.currentTrack.title,
                        artist: self.currentTrack.artist,
                        album: self.currentTrack.album,
                        position: self.currentTrack.position,
                        duration: self.currentTrack.duration,
                        isPlaying: false,
                        sampledAt: CACurrentMediaTime(),
                        artwork: self.currentTrack.artwork,
                        playerSource: self.currentTrack.playerSource
                    )
                }
            }
        }
    }
    
    private func updateTrackState(_ newTrack: TrackState) {
        // If track changed, fetch lyrics automatically
        if newTrack.title != currentTrack.title || newTrack.artist != currentTrack.artist {
            LyricsFetcher.shared.fetchLyrics(
                track: newTrack.title,
                artist: newTrack.artist,
                album: newTrack.album,
                duration: newTrack.duration
            )
            
            // Extract dynamic color palette if artwork exists
            if let art = newTrack.artwork {
                _ = ColorPaletteManager.shared.extractPalette(from: art)
            }
        }
        
        // Preserve artwork if newTrack has none yet but keys match
        let finalArtwork = newTrack.artwork ?? (newTrack.title == currentTrack.title ? currentTrack.artwork : nil)
        
        self.currentTrack = TrackState(
            title: newTrack.title,
            artist: newTrack.artist,
            album: newTrack.album,
            position: newTrack.position,
            duration: newTrack.duration,
            isPlaying: newTrack.isPlaying,
            sampledAt: newTrack.sampledAt,
            artwork: finalArtwork,
            playerSource: newTrack.playerSource
        )
    }
    
    private func querySpotify() -> TrackState? {
        guard let script = spotifyPollScript else { return nil }
        var error: NSDictionary?
        guard let output = script.executeAndReturnError(&error).stringValue,
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
        let artUrlStr = parts.count >= 6 ? parts[5] : ""
        
        let cacheKey = NSString(string: "\(title)-\(artist)-\(album)")
        let artworkImage = artworkCache.object(forKey: cacheKey)
        
        // Asynchronous non-blocking artwork fetch with thread-safe tracking
        var shouldFetch = false
        if artworkImage == nil && !artUrlStr.isEmpty {
            urlLock.lock()
            if !fetchingUrls.contains(artUrlStr) {
                fetchingUrls.insert(artUrlStr)
                shouldFetch = true
            }
            urlLock.unlock()
        }
        
        if shouldFetch, let url = URL(string: artUrlStr) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self else { return }
                defer {
                    self.urlLock.lock()
                    self.fetchingUrls.remove(artUrlStr)
                    self.urlLock.unlock()
                }
                guard let data = data, let image = NSImage(data: data) else { return }
                self.artworkCache.setObject(image, forKey: cacheKey)
                DispatchQueue.main.async {
                    if self.currentTrack.title == title {
                        self.currentTrack = TrackState(
                            title: self.currentTrack.title,
                            artist: self.currentTrack.artist,
                            album: self.currentTrack.album,
                            position: self.currentTrack.position,
                            duration: self.currentTrack.duration,
                            isPlaying: self.currentTrack.isPlaying,
                            sampledAt: self.currentTrack.sampledAt,
                            artwork: image,
                            playerSource: "Spotify"
                        )
                        _ = ColorPaletteManager.shared.extractPalette(from: image)
                    }
                }
            }.resume()
        }
        
        return TrackState(
            title: title,
            artist: artist,
            album: album,
            position: position,
            duration: duration,
            isPlaying: true,
            sampledAt: CACurrentMediaTime(),
            artwork: artworkImage,
            playerSource: "Spotify"
        )
    }
    
    private func queryAppleMusic() -> TrackState? {
        guard let script = musicPollScript else { return nil }
        var error: NSDictionary?
        guard let output = script.executeAndReturnError(&error).stringValue,
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
        
        let cacheKey = NSString(string: "\(title)-\(artist)-\(album)")
        var artworkImage = artworkCache.object(forKey: cacheKey)
        
        // Only run expensive AppleScript artwork read if not in cache
        if artworkImage == nil, let artScript = musicArtworkScript {
            let artDescriptor = artScript.executeAndReturnError(nil)
            let data = artDescriptor.data
            if !data.isEmpty, let img = NSImage(data: data) {
                artworkCache.setObject(img, forKey: cacheKey)
                artworkImage = img
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
            artwork: artworkImage,
            playerSource: "Apple Music"
        )
    }
    
    // MARK: - Interactive Seeking (Feature 1)
    
    public func seekTo(seconds: TimeInterval) {
        guard !seconds.isNaN && !seconds.isInfinite else { return }
        let target = max(0, seconds)
        let source = currentTrack.playerSource
        
        // Optimistically update local position immediately
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentTrack = TrackState(
                title: self.currentTrack.title,
                artist: self.currentTrack.artist,
                album: self.currentTrack.album,
                position: target,
                duration: self.currentTrack.duration,
                isPlaying: self.currentTrack.isPlaying,
                sampledAt: CACurrentMediaTime(),
                artwork: self.currentTrack.artwork,
                playerSource: self.currentTrack.playerSource
            )
        }
        
        pollQueue.async {
            if source == "Spotify" || source.isEmpty || source == "None" {
                let script = """
                if application "Spotify" is running then
                    tell application "Spotify" to set player position to \(target)
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            if source == "Apple Music" || source.isEmpty || source == "None" {
                let script = """
                if application "Music" is running then
                    tell application "Music" to set player position to \(target)
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        }
    }
    
    public func rewind(seconds: TimeInterval = 5.0) {
        let current = currentTrack.exactPosition
        guard !current.isNaN && !current.isInfinite else { return }
        let target = max(0, current - seconds)
        seekTo(seconds: target)
    }
    
    public func fastForward(seconds: TimeInterval = 5.0) {
        let current = currentTrack.exactPosition
        let duration = currentTrack.duration
        guard !current.isNaN && !current.isInfinite && !duration.isNaN && !duration.isInfinite else { return }
        let target = min(duration, current + seconds)
        seekTo(seconds: target)
    }
    
    // MARK: - Playback Media Controls
    
    public func togglePlayPause() {
        let source = currentTrack.playerSource
        pollQueue.async { [weak self] in
            if source == "Spotify" {
                let script = """
                if application "Spotify" is running then
                    tell application "Spotify" to playpause
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else {
                let script = """
                if application "Music" is running then
                    tell application "Music" to playpause
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self?.pollActivePlayer()
        }
    }
    
    public func nextTrack() {
        let source = currentTrack.playerSource
        pollQueue.async { [weak self] in
            if source == "Spotify" {
                let script = """
                if application "Spotify" is running then
                    tell application "Spotify" to next track
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else {
                let script = """
                if application "Music" is running then
                    tell application "Music" to next track
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self?.pollActivePlayer()
        }
    }
    
    public func previousTrack() {
        let source = currentTrack.playerSource
        pollQueue.async { [weak self] in
            if source == "Spotify" {
                let script = """
                if application "Spotify" is running then
                    tell application "Spotify" to previous track
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else {
                let script = """
                if application "Music" is running then
                    tell application "Music" to previous track
                end if
                """
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self?.pollActivePlayer()
        }
    }
}
