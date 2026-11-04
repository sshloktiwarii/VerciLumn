import Foundation
import Combine

public struct WordToken: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    
    public init(text: String, timestamp: TimeInterval, duration: TimeInterval = 0.4) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
    }
}

public struct LyricLine: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let fullText: String
    public let words: [WordToken]
    
    public init(timestamp: TimeInterval, fullText: String, words: [WordToken] = []) {
        self.timestamp = timestamp
        self.fullText = fullText
        self.words = words
    }
}

public struct LyricsData: Equatable {
    public let trackTitle: String
    public let artistName: String
    public let lines: [LyricLine]
    public let isWordSynced: Bool
    public let source: String
    
    public init(trackTitle: String = "", artistName: String = "", lines: [LyricLine] = [], isWordSynced: Bool = false, source: String = "LRCLIB") {
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.lines = lines
        self.isWordSynced = isWordSynced
        self.source = source
    }
    
    public func activeLineIndex(at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var low = 0
        var high = lines.count - 1
        var result = -1
        
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].timestamp <= time {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        return result >= 0 ? result : 0
    }
    
    public func activeWordIndex(in lineIndex: Int, at time: TimeInterval) -> Int? {
        guard lineIndex >= 0 && lineIndex < lines.count else { return nil }
        let words = lines[lineIndex].words
        guard !words.isEmpty else { return nil }
        
        var low = 0
        var high = words.count - 1
        var result = -1
        
        while low <= high {
            let mid = (low + high) / 2
            if words[mid].timestamp <= time {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        return result >= 0 ? result : 0
    }
}

public final class LyricsFetcher: ObservableObject {
    public static let shared = LyricsFetcher()
    
    @Published public private(set) var currentLyrics: LyricsData = LyricsData()
    @Published public private(set) var isLoading: Bool = false
    
    private var lastQuery: String = ""
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 12.0
        self.session = URLSession(configuration: config)
    }
    
    public func fetchLyrics(track: String, artist: String, album: String = "", duration: Double = 0) {
        let queryKey = "\(track.lowercased())-\(artist.lowercased())"
        guard !track.isEmpty, queryKey != lastQuery else { return }
        self.lastQuery = queryKey
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // 1. Primary: LRCLIB
        fetchFromLRCLIB(track: track, artist: artist, album: album, duration: duration) { [weak self] result in
            if let lyrics = result, !lyrics.lines.isEmpty {
                DispatchQueue.main.async {
                    self?.currentLyrics = lyrics
                    self?.isLoading = false
                }
            } else {
                // 2. Secondary Fallback: NetEase Cloud Music (Massive International, Bollywood & K-pop coverage)
                self?.fetchFromNetEase(track: track, artist: artist) { fallbackResult in
                    DispatchQueue.main.async {
                        self?.currentLyrics = fallbackResult ?? LyricsData(trackTitle: track, artistName: artist)
                        self?.isLoading = false
                    }
                }
            }
        }
    }
    
    private func fetchFromLRCLIB(track: String, artist: String, album: String, duration: Double, completion: @escaping (LyricsData?) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration))))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            completion(nil)
            return
        }
        
        session.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            struct LRCLIBResponse: Decodable {
                let syncedLyrics: String?
                let plainLyrics: String?
            }
            
            guard let decoded = try? JSONDecoder().decode(LRCLIBResponse.self, from: data) else {
                completion(nil)
                return
            }
            
            let rawLyrics = decoded.syncedLyrics ?? decoded.plainLyrics ?? ""
            guard !rawLyrics.isEmpty else {
                completion(nil)
                return
            }
            
            let parsed = self?.parseLRC(rawLyrics, track: track, artist: artist, source: "LRCLIB")
            completion(parsed)
        }.resume()
    }
    
    private func fetchFromNetEase(track: String, artist: String, completion: @escaping (LyricsData?) -> Void) {
        let searchQuery = "\(track) \(artist)"
        var components = URLComponents(string: "https://music.163.com/api/search/get/web")
        components?.queryItems = [
            URLQueryItem(name: "s", value: searchQuery),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let searchUrl = components?.url else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: searchUrl)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  let firstSong = songs.first,
                  let songId = firstSong["id"] as? Int else {
                completion(nil)
                return
            }
            
            guard let lyricUrl = URL(string: "https://music.163.com/api/song/lyric?os=pc&id=\(songId)&lv=-1&kv=-1&tv=-1") else {
                completion(nil)
                return
            }
            
            self?.session.dataTask(with: lyricUrl) { lData, _, lError in
                guard let lData = lData, lError == nil,
                      let lJson = try? JSONSerialization.jsonObject(with: lData) as? [String: Any],
                      let lrcObj = lJson["lrc"] as? [String: Any],
                      let lrcStr = lrcObj["lyric"] as? String,
                      !lrcStr.isEmpty else {
                    completion(nil)
                    return
                }
                
                let parsed = self?.parseLRC(lrcStr, track: track, artist: artist, source: "NetEase Cloud")
                completion(parsed)
            }.resume()
        }.resume()
    }
    
    public func parseLRC(_ text: String, track: String, artist: String, source: String = "LRCLIB") -> LyricsData {
        let rawLines = text.components(separatedBy: .newlines)
        var parsedLines: [LyricLine] = []
        var detectedWordSync = false
        
        let standardRegex = try? NSRegularExpression(pattern: #"^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$"#)
        let wordRegex = try? NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{2,3})>([^<]+)"#)
        
        for rawLine in rawLines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = standardRegex?.firstMatch(in: line, options: [], range: range) {
                let minStr = (line as NSString).substring(with: match.range(at: 1))
                let secStr = (line as NSString).substring(with: match.range(at: 2))
                let msStr = (line as NSString).substring(with: match.range(at: 3))
                let content = (line as NSString).substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                
                let minutes = Double(minStr) ?? 0.0
                let seconds = Double(secStr) ?? 0.0
                let msDiv: Double = msStr.count == 2 ? 100.0 : 1000.0
                let milliseconds = (Double(msStr) ?? 0.0) / msDiv
                let lineTime = (minutes * 60.0) + seconds + milliseconds
                
                // Check if line contains word-level bracketed tags: <mm:ss.xx>Word
                var words: [WordToken] = []
                let contentRange = NSRange(location: 0, length: content.utf16.count)
                if let wordMatches = wordRegex?.matches(in: content, options: [], range: contentRange), !wordMatches.isEmpty {
                    detectedWordSync = true
                    for wMatch in wordMatches {
                        let wMin = Double((content as NSString).substring(with: wMatch.range(at: 1))) ?? 0
                        let wSec = Double((content as NSString).substring(with: wMatch.range(at: 2))) ?? 0
                        let wMsStr = (content as NSString).substring(with: wMatch.range(at: 3))
                        let wMsDiv: Double = wMsStr.count == 2 ? 100.0 : 1000.0
                        let wMs = (Double(wMsStr) ?? 0.0) / wMsDiv
                        let wordTime = (wMin * 60.0) + wSec + wMs
                        let wordText = (content as NSString).substring(with: wMatch.range(at: 4)).trimmingCharacters(in: .whitespaces)
                        if !wordText.isEmpty {
                            words.append(WordToken(text: wordText, timestamp: wordTime))
                        }
                    }
                } else {
                    // Approximate word timestamps linearly across estimated duration
                    let splitWords = content.split(separator: " ").map(String.init)
                    let estimatedLineDuration = 3.5
                    let step = splitWords.count > 0 ? (estimatedLineDuration / Double(splitWords.count)) : 0.4
                    for (i, word) in splitWords.enumerated() {
                        let wordTime = lineTime + (Double(i) * step)
                        words.append(WordToken(text: word, timestamp: wordTime, duration: step))
                    }
                }
                
                parsedLines.append(LyricLine(timestamp: lineTime, fullText: content, words: words))
            }
        }
        
        parsedLines.sort { $0.timestamp < $1.timestamp }
        return LyricsData(trackTitle: track, artistName: artist, lines: parsedLines, isWordSynced: detectedWordSync, source: source)
    }
}
