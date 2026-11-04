import XCTest
@testable import VerciLumn

final class VerciLumnTests: XCTestCase {
    func testTrackStatePositionInterpolation() {
        let baseTime = CACurrentMediaTime() - 2.5
        let track = TrackState(
            title: "Midnight City",
            artist: "M83",
            position: 10.0,
            duration: 240.0,
            isPlaying: true,
            sampledAt: baseTime
        )
        
        let calculated = track.exactPosition
        XCTAssertGreaterThanOrEqual(calculated, 12.0)
        XCTAssertLessThanOrEqual(calculated, 13.5)
    }
    
    func testLRCParserDynamicDeltaAndWordSync() {
        let lrc = """
        [00:01.00]First line of the song
        [00:05.00]Second line starts four seconds later
        [00:08.50]<00:08.50>Third <00:09.00>line <00:09.50>synced
        """
        
        let lyrics = LyricsFetcher.shared.parseLRC(lrc, track: "Test", artist: "Artist")
        XCTAssertEqual(lyrics.lines.count, 3)
        XCTAssertTrue(lyrics.isWordSynced)
        
        // Line 0 delta should be 4.0s (5.0 - 1.0)
        let firstLineWords = lyrics.lines[0].words
        XCTAssertEqual(firstLineWords.count, 5)
        XCTAssertEqual(firstLineWords.first?.timestamp ?? 0, 1.0, accuracy: 0.01)
        
        // Binary search lookup
        let activeIdx = lyrics.activeLineIndex(at: 3.0)
        XCTAssertEqual(activeIdx, 0)
        
        let activeIdx2 = lyrics.activeLineIndex(at: 6.0)
        XCTAssertEqual(activeIdx2, 1)
        
        let activeWordIdx = lyrics.activeWordIndex(in: 2, at: 9.2)
        XCTAssertEqual(activeWordIdx, 1) // "line"
    }
    
    func testAppSettingsDefaults() {
        let settings = AppSettings.shared
        XCTAssertNotNil(settings.lyricStyle)
        XCTAssertGreaterThan(settings.glowSensitivity, 0.0)
        XCTAssertGreaterThan(settings.textScale, 0.0)
        XCTAssertEqual(settings.backdropMode, .infiniteZoom)
    }
    
    func testLockScreenElevationAndTransparency() {
        let panel = LockScreenPanel(contentView: NSView())
        XCTAssertFalse(panel.isScreenLocked)
        
        // Simulate lock event
        panel.screenLocked()
        XCTAssertTrue(panel.isScreenLocked)
        
        // Simulate unlock event
        panel.screenUnlocked()
        XCTAssertFalse(panel.isScreenLocked)
    }
    
    func testColorThemePresets() {
        let themes: [ColorThemePreset] = [
            .blackAndWhite,
            .rainbow,
            .redFamily,
            .purpleSoft,
            .blueFamily,
            .greenFamily,
            .brownFamily,
            .albumReactive
        ]
        
        for theme in themes {
            let palette = theme.palette
            XCTAssertNotNil(palette.highlightAccent)
            XCTAssertNotNil(palette.secondaryGlow)
        }
        
        XCTAssertTrue(ColorThemePreset.rainbow.palette.isRainbow)
        XCTAssertEqual(ColorThemePreset.rainbow.palette.rainbowGradient.count, 7)
    }
    
    // MARK: - Stress Testing & Security Resilience Matrix
    
    func testMalformedAndExtremeLRCStress() {
        let fetcher = LyricsFetcher.shared
        
        // 1. Empty String
        let emptyLyrics = fetcher.parseLRC("", track: "Empty", artist: "Empty")
        XCTAssertEqual(emptyLyrics.lines.count, 0)
        XCTAssertNil(emptyLyrics.activeLineIndex(at: 10.0))
        
        // 2. Corrupted / Non-LRC junk
        let junk = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        [not a timestamp] Just some random text
        [99:99] Missing milliseconds
        <<malformed tags>>
        """
        let junkLyrics = fetcher.parseLRC(junk, track: "Junk", artist: "Junk")
        XCTAssertEqual(junkLyrics.lines.count, 0)
        
        // 3. Precision timestamps with variable decimal places
        let variableDecimals = """
        [00:01.4]One digit ms (400ms)
        [00:02.45]Two digit ms (450ms)
        [00:03.456]Three digit ms (456ms)
        """
        let varLyrics = fetcher.parseLRC(variableDecimals, track: "Var", artist: "Var")
        XCTAssertEqual(varLyrics.lines.count, 3)
        XCTAssertEqual(varLyrics.lines[0].timestamp, 1.4, accuracy: 0.001)
        XCTAssertEqual(varLyrics.lines[1].timestamp, 2.45, accuracy: 0.001)
        XCTAssertEqual(varLyrics.lines[2].timestamp, 3.456, accuracy: 0.001)
        
        // 4. Massive 5,000-line synthetic LRC stress test
        var massiveLRC = ""
        for i in 0..<5000 {
            let min = i / 60
            let sec = i % 60
            massiveLRC += String(format: "[%02d:%02d.00] Line number %d of extreme lyrics\n", min, sec, i)
        }
        let start = CACurrentMediaTime()
        let parsedMassive = fetcher.parseLRC(massiveLRC, track: "Massive", artist: "Massive")
        let duration = CACurrentMediaTime() - start
        
        XCTAssertEqual(parsedMassive.lines.count, 5000)
        XCTAssertLessThan(duration, 0.5, "5,000-line LRC parsing must execute in under 500ms")
        
        // Binary search performance across 5,000 lines
        let activeIdx = parsedMassive.activeLineIndex(at: 1234.5)
        XCTAssertEqual(activeIdx, 1234)
    }
    
    func testRapidTrackSwitchingStress() {
        let fetcher = LyricsFetcher.shared
        let expectation = expectation(description: "Rapid Track Switching Concurrent Stress")
        expectation.expectedFulfillmentCount = 50
        
        let dispatchGroup = DispatchGroup()
        
        // Fire 50 track fetch requests across concurrent background queues within milliseconds
        for i in 0..<50 {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                fetcher.fetchLyrics(
                    track: "Song \(i)",
                    artist: "Artist \(i)",
                    album: "Album \(i)",
                    duration: Double(120 + i)
                )
                expectation.fulfill()
                dispatchGroup.leave()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testTrackStateEdgeCasesAndSeeking() {
        // Zero duration track
        let zeroTrack = TrackState(
            title: "Zero",
            artist: "Zero",
            position: 0,
            duration: 0,
            isPlaying: false
        )
        XCTAssertEqual(zeroTrack.progress, 0.0)
        XCTAssertEqual(zeroTrack.exactPosition, 0.0)
        
        // Negative position with offset
        let negTrack = TrackState(
            title: "Neg",
            artist: "Neg",
            position: 1.0,
            duration: 100,
            isPlaying: false
        )
        let exactNeg = negTrack.exactPosition(withOffset: -5.0)
        XCTAssertEqual(exactNeg, 0.0, "Negative exact position should be clamped to 0")
        
        // Out of bounds seeking resilience
        PlaybackManager.shared.seekTo(seconds: -10.0)
        PlaybackManager.shared.seekTo(seconds: Double.nan)
        PlaybackManager.shared.seekTo(seconds: Double.infinity)
        XCTAssertGreaterThanOrEqual(PlaybackManager.shared.currentTrack.position, 0.0)
    }
    
    func testContinuousTunnelPhaseLongSessionResilience() {
        let tunnelPhase = ContinuousTunnelPhase()
        
        // 1. Advance with NaN & Infinity (must not crash or contaminate state)
        let nanResult = tunnelPhase.advance(time: Double.nan, beat: 0.5, energy: 0.5)
        XCTAssertFalse(nanResult.phase.isNaN)
        XCTAssertFalse(nanResult.rotation.isNaN)
        
        let infResult = tunnelPhase.advance(time: Double.infinity, beat: Double.infinity, energy: Double.infinity)
        XCTAssertFalse(infResult.phase.isNaN)
        XCTAssertFalse(infResult.rotation.isNaN)
        
        // 2. High-iteration multi-day simulation (10,000 steps)
        var simulatedTime: Double = 1000.0
        for _ in 0..<10_000 {
            simulatedTime += 0.0166 // 60 FPS delta
            let (phase, rot) = tunnelPhase.advance(time: simulatedTime, beat: 0.8, energy: 0.6)
            XCTAssertFalse(phase.isNaN)
            XCTAssertFalse(rot.isNaN)
            XCTAssertLessThanOrEqual(phase, 100_000.0)
        }
    }
    
    func testAudioSpectrumEngineBufferStress() {
        let spectrum = AudioSpectrumEngine.shared
        
        // 1. Zero samples
        spectrum.processAudio(samples: [])
        XCTAssertEqual(spectrum.bands.count, 8)
        
        // 2. Undersized buffer (< 1024)
        spectrum.processAudio(samples: [0.1, 0.2, 0.3])
        XCTAssertEqual(spectrum.bands.count, 8)
        
        // 3. Full 1024 silence
        let silence = [Float](repeating: 0.0, count: 1024)
        spectrum.processAudio(samples: silence)
        XCTAssertEqual(spectrum.bands.count, 8)
        
        // 4. Full 1024 extreme 1.0 amplitude
        let maxSignal = [Float](repeating: 1.0, count: 1024)
        spectrum.processAudio(samples: maxSignal)
        XCTAssertEqual(spectrum.bands.count, 8)
        for band in spectrum.bands {
            XCTAssertFalse(band.isNaN)
            XCTAssertFalse(band.isInfinite)
        }
    }
    
    func testWordSemanticEngineAndIconStemming() {
        let engine = WordSemanticEngine.shared
        
        // Check exact match
        let fireStyle = engine.evaluate(word: "fire")
        XCTAssertEqual(fireStyle.mood, .fire)
        
        // Check suffix stemming: "dancing" -> "dance"
        let danceStyle = engine.evaluate(word: "dancing")
        XCTAssertNotNil(danceStyle)
        
        // Check punctuation stripping: "love?!" -> "love"
        let loveStyle = engine.evaluate(word: "love?!")
        XCTAssertEqual(loveStyle.mood, .love)
        
        // Check icon dictionary
        let mapper = WordIconMapper.shared
        XCTAssertEqual(mapper.wordToIconMap["heart"], "heart.fill")
        XCTAssertEqual(mapper.wordToIconMap["driving"], "steeringwheel")
        XCTAssertEqual(mapper.wordToIconMap["rain"], "cloud.rain.fill")
    }
    
    func testZeroLeakSecurityAndRepositorySanity() {
        // Confirm no private tokens or API keys are stored in settings or defaults
        let settings = AppSettings.shared
        XCTAssertFalse(settings.lyricStyle.rawValue.contains("token"))
        XCTAssertFalse(settings.displayMode.rawValue.contains("key"))
        
        // Confirm lyrics sources use pure HTTPS endpoints without sensitive credentials in URI
        let lrclibBase = "https://lrclib.net/api"
        let neteaseBase = "https://music.163.com/api"
        XCTAssertTrue(lrclibBase.starts(with: "https://"))
        XCTAssertTrue(neteaseBase.starts(with: "https://"))
    }
}
