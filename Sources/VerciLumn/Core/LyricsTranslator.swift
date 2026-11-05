import Foundation
import Combine

/// Asynchronous lyric translation service.
/// Routes requests first to local offline Ollama AI (e.g. Llama 3 / Mistral at localhost:11434),
/// falling back seamlessly to Google Translate if local AI is unavailable.
public final class LyricsTranslator {
    public static let shared = LyricsTranslator()
    
    private let translationCache = NSCache<NSString, NSArray>()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 8.0
        self.session = URLSession(configuration: config)
        self.translationCache.countLimit = 128
    }
    
    // MARK: - Asynchronous Background Translation
    
    public func translateAsync(
        lyrics: LyricsData,
        targetLanguage: String = "en",
        generation: Int,
        completion: @escaping (LyricsData) -> Void
    ) {
        guard !lyrics.lines.isEmpty else {
            completion(lyrics)
            return
        }
        
        let cacheKey = NSString(string: "\(lyrics.trackTitle)-\(lyrics.artistName)-\(targetLanguage)")
        if let cached = translationCache.object(forKey: cacheKey) as? [String], cached.count == lyrics.lines.count {
            let updatedLines = zip(lyrics.lines, cached).map { line, trans in
                LyricLine(
                    id: line.id,
                    timestamp: line.timestamp,
                    fullText: line.fullText,
                    words: line.words,
                    translation: trans.isEmpty ? nil : trans
                )
            }
            let updatedLyrics = LyricsData(
                trackTitle: lyrics.trackTitle,
                artistName: lyrics.artistName,
                lines: updatedLines,
                isWordSynced: lyrics.isWordSynced,
                source: "\(lyrics.source)+Translated"
            )
            completion(updatedLyrics)
            return
        }
        
        // Dispatch translation detached from UI
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            let originalTexts = lyrics.lines.map { $0.fullText }
            
            // 1. Attempt Local Ollama AI Translation
            var translatedTexts = await self.tryOllamaTranslation(lines: originalTexts, targetLang: targetLanguage)
            
            // 2. Fallback to Google Translate if Ollama is not active
            if translatedTexts == nil || translatedTexts?.isEmpty == true {
                translatedTexts = await self.tryGoogleTranslation(lines: originalTexts, targetLang: targetLanguage)
            }
            
            guard let validTranslations = translatedTexts, !validTranslations.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                DispatchQueue.main.async {
                    completion(lyrics)
                }
                return
            }
            
            self.translationCache.setObject(validTranslations as NSArray, forKey: cacheKey)
            
            let updatedLines = zip(lyrics.lines, validTranslations).map { line, trans in
                LyricLine(
                    id: line.id,
                    timestamp: line.timestamp,
                    fullText: line.fullText,
                    words: line.words,
                    translation: trans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trans.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            
            let updatedLyrics = LyricsData(
                trackTitle: lyrics.trackTitle,
                artistName: lyrics.artistName,
                lines: updatedLines,
                isWordSynced: lyrics.isWordSynced,
                source: "\(lyrics.source)+Translated"
            )
            
            DispatchQueue.main.async {
                completion(updatedLyrics)
            }
        }
    }
    
    // MARK: - Backend 1: Local Ollama (Llama 3 / Mistral)
    
    private func tryOllamaTranslation(lines: [String], targetLang: String) async -> [String]? {
        guard let url = URL(string: "http://localhost:11434/api/generate") else { return nil }
        
        let promptText = """
        Translate each of the following lines into English. Return ONLY the translated lines, exactly one translation per line, matching the count (\(lines.count) lines):
        \(lines.joined(separator: "\n"))
        """
        
        let payload: [String: Any] = [
            "model": "llama3",
            "prompt": promptText,
            "stream": false
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 1.0 // Rapid offline probe
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseText = json["response"] as? String {
                let split = responseText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if split.count == lines.count {
                    return split
                }
            }
        } catch {
            // Ollama offline; silently fallback
        }
        
        return nil
    }
    
    // MARK: - Backend 2: Google Translate API (Hardware-Accelerated POST Endpoint)
    
    private func tryGoogleTranslation(lines: [String], targetLang: String) async -> [String]? {
        guard !lines.isEmpty else { return nil }
        guard let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=\(targetLang)&dt=t") else {
            return nil
        }
        
        let joinedText = lines.joined(separator: "\n")
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "q", value: joinedText)]
        guard let postData = components.percentEncodedQuery?.data(using: .utf8) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData
        request.timeoutInterval = 4.5
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            // Format: [[["translated_sentence", "original_sentence", ...], ...]]
            if let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
               let sentences = root.first as? [[Any]] {
                var translatedFull = ""
                for sentence in sentences {
                    if let transPart = sentence.first as? String {
                        translatedFull += transPart
                    }
                }
                
                let splitLines = translatedFull.components(separatedBy: "\n")
                if splitLines.count == lines.count {
                    return splitLines
                } else if !splitLines.isEmpty {
                    var results: [String] = []
                    for idx in 0..<lines.count {
                        if idx < splitLines.count {
                            results.append(splitLines[idx])
                        } else {
                            results.append("")
                        }
                    }
                    return results
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
}

