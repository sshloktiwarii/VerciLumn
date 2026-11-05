import Foundation

public struct ScreenSaverSharedState {
    public static let suiteName = "group.com.vercilumn.engine"
    
    public enum Keys {
        public static let isPlaying = "saver_is_playing"
        public static let trackTitle = "saver_track_title"
        public static let trackArtist = "saver_track_artist"
        public static let trackAlbum = "saver_track_album"
        public static let beatIntensity = "saver_beat_intensity"
        public static let spectrumBands = "saver_spectrum_bands"
        public static let lastUpdated = "saver_last_updated"
    }
    
    public static func sync(
        isPlaying: Bool,
        title: String,
        artist: String,
        album: String = "",
        beatIntensity: Float = 0.0,
        bands: [Float] = Array(repeating: 0.05, count: 8)
    ) {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        defaults.set(isPlaying, forKey: Keys.isPlaying)
        defaults.set(title, forKey: Keys.trackTitle)
        defaults.set(artist, forKey: Keys.trackArtist)
        defaults.set(album, forKey: Keys.trackAlbum)
        defaults.set(Double(beatIntensity), forKey: Keys.beatIntensity)
        defaults.set(bands.map { Double($0) }, forKey: Keys.spectrumBands)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
    }
    
    public static func read() -> (
        isPlaying: Bool,
        title: String,
        artist: String,
        album: String,
        beatIntensity: Float,
        bands: [Float]
    ) {
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        let isPlaying = defaults.bool(forKey: Keys.isPlaying)
        let title = defaults.string(forKey: Keys.trackTitle) ?? ""
        let artist = defaults.string(forKey: Keys.trackArtist) ?? ""
        let album = defaults.string(forKey: Keys.trackAlbum) ?? ""
        let beat = Float(defaults.double(forKey: Keys.beatIntensity))
        let bandsRaw = defaults.array(forKey: Keys.spectrumBands) as? [Double] ?? []
        let bands: [Float] = bandsRaw.count == 8 ? bandsRaw.map { Float($0) } : Array(repeating: Float(0.05), count: 8)
        
        return (isPlaying, title, artist, album, beat, bands)
    }
}
