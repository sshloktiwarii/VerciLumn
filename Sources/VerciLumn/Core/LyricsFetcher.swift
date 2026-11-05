import Foundation
import Combine

public struct WordToken: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let text: String
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public let semanticStyle: SemanticStyle
    public let iconSymbol: String?
    
    public init(
        text: String,
        timestamp: TimeInterval,
        duration: TimeInterval = 0.4,
        semanticStyle: SemanticStyle? = nil,
        iconSymbol: String? = nil
    ) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.semanticStyle = semanticStyle ?? WordSemanticEngine.shared.evaluate(word: text)
        self.iconSymbol = iconSymbol ?? WordIconMapper.shared.symbol(for: text)
    }
}

public struct LyricLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let fullText: String
    public let words: [WordToken]
    public let translation: String?
    
    public init(id: UUID = UUID(), timestamp: TimeInterval, fullText: String, words: [WordToken] = [], translation: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.fullText = fullText
        self.words = words
        self.translation = translation
    }
}

public struct LyricsData: Equatable, Sendable {
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

private final class LyricsDataBox {
    let data: LyricsData
    init(_ data: LyricsData) { self.data = data }
}

public final class LyricsFetcher: ObservableObject {
    public static let shared = LyricsFetcher()
    
    @Published public private(set) var currentLyrics: LyricsData = LyricsData()
    @Published public private(set) var isLoading: Bool = false
    
    private var lastQuery: String = ""
    private var activeGeneration: Int = 0
    private var activeTasks: [URLSessionTask] = []
    private let taskQueue = DispatchQueue(label: "com.vercilumn.lyrics.tasks")
    private let session: URLSession
    
    // In-memory offline cache with strict bounds to prevent unbounded heap growth
    private let lyricsCache: NSCache<NSString, LyricsDataBox> = {
        let cache = NSCache<NSString, LyricsDataBox>()
        cache.countLimit = 150
        return cache
    }()
    
    // Precompiled Static Regexes (Eradicates repeated compilation in inner loops)
    private static let standardRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^\[(\d{1,3}):([0-5]\d)(?:\.(\d{1,3}))?\](.*)$"#)
    }()
    
    private static let wordRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<(\d{1,3}):([0-5]\d)(?:\.(\d{1,3}))?>([^<]+)"#)
    }()

    private static let titleCleanerRegexes: [NSRegularExpression] = {
        let patterns = [
            #"\(feat\..*?\)"#,
            #"\[feat\..*?\]"#,
            #"\(with.*?\)"#,
            #"\(remaster.*?\)"#,
            #"\[remaster.*?\]"#,
            #"- remaster.*"#,
            #"\(deluxe.*?\)"#,
            #"\(live.*?\)"#,
            #"\[live.*?\]"#,
            #"\(anniversary.*?\)"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 12.0
        self.session = URLSession(configuration: config)
    }
    
    public func fetchLyrics(track: String, artist: String, album: String = "", duration: Double = 0) {
        // Sanitize untrusted input: strip control characters and cap excessive length
        let sanitizedTrack = track.components(separatedBy: .controlCharacters).joined()
        let sanitizedArtist = artist.components(separatedBy: .controlCharacters).joined()
        let trimmedTrack = String(sanitizedTrack.trimmingCharacters(in: .whitespaces).prefix(160))
        let trimmedArtist = String(sanitizedArtist.trimmingCharacters(in: .whitespaces).prefix(160))
        guard !trimmedTrack.isEmpty else { return }
        
        // If already showing verified lyrics for this track, avoid redundant network queries
        if currentLyrics.trackTitle.lowercased() == trimmedTrack.lowercased() &&
           currentLyrics.artistName.lowercased() == trimmedArtist.lowercased() &&
           !currentLyrics.lines.isEmpty {
            return
        }
        
        let queryKey = "\(trimmedTrack.lowercased())-\(trimmedArtist.lowercased())"
        let cacheKey = NSString(string: queryKey)
        
        // 1. Cancel in-flight requests from previously skipped songs immediately
        var generation = 0
        taskQueue.sync {
            for task in self.activeTasks {
                task.cancel()
            }
            self.activeTasks.removeAll()
            self.activeGeneration += 1
            generation = self.activeGeneration
        }
        
        // 2. Check in-memory cache first for instant zero-latency replay
        if let cached = lyricsCache.object(forKey: cacheKey) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.activeGeneration == generation else { return }
                self.currentLyrics = cached.data
                self.isLoading = false
            }
            return
        }
        
        // 3. Immediately clear stale lyrics from old song so screen never gets stuck
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.activeGeneration == generation else { return }
            self.currentLyrics = LyricsData(trackTitle: trimmedTrack, artistName: trimmedArtist)
            self.isLoading = true
        }
        
        let cleanTitle = cleanTrackTitle(trimmedTrack)
        
        // 4. Primary: LRCLIB exact get
        fetchFromLRCLIB(track: trimmedTrack, artist: trimmedArtist, album: album, duration: duration, generation: generation) { [weak self] result in
            guard let self = self, self.activeGeneration == generation else { return }
            
            if let lyrics = result, !lyrics.lines.isEmpty {
                self.cacheAndPublish(lyrics, for: cacheKey, generation: generation)
                return
            }
            
            // 5. Secondary: LRCLIB fuzzy search with cleaned title
            self.searchLRCLIB(track: cleanTitle, artist: trimmedArtist, generation: generation) { searchResult in
                guard self.activeGeneration == generation else { return }
                
                if let sLyrics = searchResult, !sLyrics.lines.isEmpty {
                    self.cacheAndPublish(sLyrics, for: cacheKey, generation: generation)
                    return
                }
                
                // 6. Tertiary: NetEase Cloud Music fallback
                self.fetchFromNetEase(track: cleanTitle, artist: trimmedArtist, generation: generation) { fallbackResult in
                    guard self.activeGeneration == generation else { return }
                    let finalLyrics = fallbackResult ?? LyricsData(trackTitle: trimmedTrack, artistName: trimmedArtist)
                    self.cacheAndPublish(finalLyrics, for: cacheKey, generation: generation)
                }
            }
        }
    }
    
    // Clean artist and track titles to strip out '(Remastered)', '(feat. ...)', etc.
    private func cleanTrackTitle(_ title: String) -> String {
        var clean = title
        for regex in Self.titleCleanerRegexes {
            clean = regex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "")
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cacheAndPublish(_ lyrics: LyricsData, for key: NSString, generation: Int) {
        guard generation == self.activeGeneration else { return }
        if !lyrics.lines.isEmpty {
            lyricsCache.setObject(LyricsDataBox(lyrics), forKey: key)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.activeGeneration == generation else { return }
            self.currentLyrics = lyrics
            self.isLoading = false
        }
        
        // Asynchronous non-blocking background translation (Ollama / Google Translate)
        if AppSettings.shared.isTranslationEnabled && !lyrics.lines.isEmpty {
            LyricsTranslator.shared.translateAsync(
                lyrics: lyrics,
                targetLanguage: AppSettings.shared.translationLanguage,
                generation: generation
            ) { [weak self] translatedLyrics in
                guard let self = self, self.activeGeneration == generation else { return }
                DispatchQueue.main.async {
                    self.currentLyrics = translatedLyrics
                    self.lyricsCache.setObject(LyricsDataBox(translatedLyrics), forKey: key)
                }
            }
        }
    }
    
    private func trackTask(_ task: URLSessionTask) {
        taskQueue.sync {
            self.activeTasks.append(task)
        }
    }
    
    private func untrackTask(_ task: URLSessionTask) {
        taskQueue.sync {
            self.activeTasks.removeAll { $0 === task }
        }
    }
    
    private func fetchFromLRCLIB(
        track: String,
        artist: String,
        album: String,
        duration: Double,
        generation: Int,
        retryCount: Int = 0,
        maxRetries: Int = 2,
        completion: @escaping (LyricsData?) -> Void
    ) {
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
        
        var task: URLSessionDataTask?
        task = session.dataTask(with: url) { [weak self, weak task] data, response, error in
            if let t = task { self?.untrackTask(t) }
            guard let self = self, self.activeGeneration == generation else { return }
            
            // Check HTTP status code for server error (5xx) or rate limit (429)
            if let http = response as? HTTPURLResponse, (http.statusCode == 429 || http.statusCode >= 500), retryCount < maxRetries {
                let delay = pow(2.0, Double(retryCount)) * 0.5 // 0.5s, 1.0s exponential backoff
                self.taskQueue.asyncAfter(deadline: .now() + delay) {
                    self.fetchFromLRCLIB(
                        track: track,
                        artist: artist,
                        album: album,
                        duration: duration,
                        generation: generation,
                        retryCount: retryCount + 1,
                        maxRetries: maxRetries,
                        completion: completion
                    )
                }
                return
            }
            
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
            
            let parsed = self.parseLRC(rawLyrics, track: track, artist: artist, source: "LRCLIB")
            completion(parsed)
        }
        if let t = task {
            trackTask(t)
            t.resume()
        }
    }
    
    private func searchLRCLIB(track: String, artist: String, generation: Int, completion: @escaping (LyricsData?) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(track) \(artist)")
        ]
        
        guard let url = components?.url else {
            completion(nil)
            return
        }
        
        var task: URLSessionDataTask?
        task = session.dataTask(with: url) { [weak self, weak task] data, _, error in
            if let t = task { self?.untrackTask(t) }
            guard let self = self, self.activeGeneration == generation else { return }
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            struct SearchItem: Decodable {
                let trackName: String?
                let artistName: String?
                let syncedLyrics: String?
                let plainLyrics: String?
            }
            
            guard let items = try? JSONDecoder().decode([SearchItem].self, from: data), let firstItem = items.first else {
                completion(nil)
                return
            }
            
            let raw = firstItem.syncedLyrics ?? firstItem.plainLyrics ?? ""
            guard !raw.isEmpty else {
                completion(nil)
                return
            }
            
            let parsed = self.parseLRC(raw, track: track, artist: artist, source: "LRCLIB (Search)")
            completion(parsed)
        }
        if let t = task {
            trackTask(t)
            t.resume()
        }
    }
    
    private func fetchFromNetEase(track: String, artist: String, generation: Int, completion: @escaping (LyricsData?) -> Void) {
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
        
        var mainTask: URLSessionDataTask?
        mainTask = session.dataTask(with: request) { [weak self, weak mainTask] data, _, error in
            if let t = mainTask { self?.untrackTask(t) }
            guard let self = self, self.activeGeneration == generation else { return }
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  let firstSong = songs.first,
                  let songId = (firstSong["id"] as? NSNumber)?.intValue ?? (firstSong["id"] as? Int) else {
                completion(nil)
                return
            }
            
            guard let lyricUrl = URL(string: "https://music.163.com/api/song/lyric?os=pc&id=\(songId)&lv=-1&kv=-1&tv=-1") else {
                completion(nil)
                return
            }
            
            var subTask: URLSessionDataTask?
            subTask = self.session.dataTask(with: lyricUrl) { [weak self, weak subTask] lData, _, lError in
                if let st = subTask { self?.untrackTask(st) }
                guard let self = self, self.activeGeneration == generation else { return }
                guard let lData = lData, lError == nil,
                      let lJson = try? JSONSerialization.jsonObject(with: lData) as? [String: Any],
                      let lrcObj = lJson["lrc"] as? [String: Any],
                      let lrcStr = lrcObj["lyric"] as? String,
                      !lrcStr.isEmpty else {
                    completion(nil)
                    return
                }
                
                let parsed = self.parseLRC(lrcStr, track: track, artist: artist, source: "NetEase Cloud")
                completion(parsed)
            }
            if let st = subTask {
                self.trackTask(st)
                st.resume()
            }
        }
        if let mt = mainTask {
            trackTask(mt)
            mt.resume()
        }
    }
    
    public func parseLRC(_ text: String, track: String, artist: String, source: String = "LRCLIB") -> LyricsData {
        let rawLines = text.components(separatedBy: .newlines)
        var rawParsed: [(time: TimeInterval, text: String, elrcWords: [WordToken])] = []
        var detectedWordSync = false
        
        let standardRegex = Self.standardRegex
        let wordRegex = Self.wordRegex
        
        for rawLine in rawLines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = standardRegex?.firstMatch(in: line, options: [], range: range) {
                let minStr = (line as NSString).substring(with: match.range(at: 1))
                let secStr = (line as NSString).substring(with: match.range(at: 2))
                var milliseconds: Double = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let msStr = (line as NSString).substring(with: match.range(at: 3))
                    let msDiv: Double = pow(10.0, Double(max(1, msStr.count)))
                    milliseconds = (Double(msStr) ?? 0.0) / msDiv
                }
                let content = match.range(at: 4).location != NSNotFound ? (line as NSString).substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces) : ""
                
                let minutes = Double(minStr) ?? 0.0
                let seconds = Double(secStr) ?? 0.0
                let lineTime = (minutes * 60.0) + seconds + milliseconds
                
                // Check if line contains word-level bracketed tags: <mm:ss.xx>Word
                var words: [WordToken] = []
                let contentRange = NSRange(location: 0, length: content.utf16.count)
                if let wordMatches = wordRegex?.matches(in: content, options: [], range: contentRange), !wordMatches.isEmpty {
                    detectedWordSync = true
                    for wMatch in wordMatches {
                        let wMin = Double((content as NSString).substring(with: wMatch.range(at: 1))) ?? 0
                        let wSec = Double((content as NSString).substring(with: wMatch.range(at: 2))) ?? 0
                        var wMs: Double = 0.0
                        if wMatch.range(at: 3).location != NSNotFound {
                            let wMsStr = (content as NSString).substring(with: wMatch.range(at: 3))
                            let wMsDiv: Double = pow(10.0, Double(max(1, wMsStr.count)))
                            wMs = (Double(wMsStr) ?? 0.0) / wMsDiv
                        }
                        let wordTime = (wMin * 60.0) + wSec + wMs
                        let wordText = wMatch.range(at: 4).location != NSNotFound ? (content as NSString).substring(with: wMatch.range(at: 4)).trimmingCharacters(in: .whitespaces) : ""
                        if !wordText.isEmpty {
                            words.append(WordToken(text: wordText, timestamp: wordTime))
                        }
                    }
                }
                
                rawParsed.append((time: lineTime, text: content, elrcWords: words))
            }
        }
        
        // Sort strictly chronologically
        rawParsed.sort { $0.time < $1.time }
        
        // Dynamic Inter-line Delta Word Timing
        var finalLines: [LyricLine] = []
        for i in 0..<rawParsed.count {
            let current = rawParsed[i]
            var words: [WordToken] = []
            
            if !current.elrcWords.isEmpty {
                words = current.elrcWords
            } else {
                // Calculate dynamic line duration based on adjacent next line timestamp
                let lineDuration: Double
                if i + 1 < rawParsed.count {
                    let delta = rawParsed[i + 1].time - current.time
                    lineDuration = min(max(delta, 0.8), 7.5)
                } else {
                    lineDuration = 3.5
                }
                
                let splitWords = current.text.split(separator: " ").map(String.init)
                let step = splitWords.count > 0 ? (lineDuration / Double(splitWords.count)) : 0.4
                for (wIdx, word) in splitWords.enumerated() {
                    let wordTime = current.time + (Double(wIdx) * step)
                    words.append(WordToken(text: word, timestamp: wordTime, duration: step))
                }
            }
            
            finalLines.append(LyricLine(timestamp: current.time, fullText: current.text, words: words))
        }
        
        return LyricsData(trackTitle: track, artistName: artist, lines: finalLines, isWordSynced: detectedWordSync, source: source)
    }
}
