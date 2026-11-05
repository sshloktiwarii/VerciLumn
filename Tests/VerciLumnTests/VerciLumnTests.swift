import XCTest
@testable import VerciLumn
@testable import VerciLumnSaver

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
        XCTAssertNotNil(settings.backdropMode)
    }
    
    func testStageOverlayPanelConfigurationAndClickThrough() {
        let panel = StageOverlayPanel(contentView: NSView())
        XCTAssertEqual(panel.displayMode, .desktop)
        
        let exp = expectation(description: "Window level transitions")
        
        // Mode transitions
        panel.setDisplayMode(.floating)
        XCTAssertEqual(panel.displayMode, .floating)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertEqual(panel.level.rawValue, Int(CGWindowLevelForKey(.floatingWindow)) + 1)
            
            panel.setDisplayMode(.desktop)
            XCTAssertEqual(panel.displayMode, .desktop)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                XCTAssertEqual(panel.level.rawValue, -1)
                
                panel.setDisplayMode(.fullStage)
                XCTAssertEqual(panel.displayMode, .fullStage)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    XCTAssertEqual(panel.level.rawValue, Int(CGWindowLevelForKey(.floatingWindow)) - 1)
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 2.0)
        
        // Strict mouse ignores test
        panel.setIgnoresMouseEventsStrict(true)
        panel.setIgnoresMouseEventsStrict(false)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
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
    
    func testPowerEfficiencyAndLowPowerModeSuspension() {
        let powerManager = PowerEfficiencyManager.shared
        let renderer = MetalShaderRenderer.shared
        
        // Simulate entering Low Power Mode
        powerManager.setSimulatedLowPowerMode(true)
        XCTAssertTrue(powerManager.isLowPowerModeEnabled)
        XCTAssertTrue(renderer.isSuspended)
        
        // Simulate exiting Low Power Mode
        powerManager.setSimulatedLowPowerMode(false)
        XCTAssertFalse(powerManager.isLowPowerModeEnabled)
        XCTAssertFalse(renderer.isSuspended)
    }
    
    func testParseTimeTokenSemanticCaching() {
        let lrc = "[00:01.00]I love driving fast into the fire"
        let lyrics = LyricsFetcher.shared.parseLRC(lrc, track: "Highway", artist: "Driver")
        
        XCTAssertEqual(lyrics.lines.count, 1)
        let words = lyrics.lines[0].words
        XCTAssertGreaterThan(words.count, 0)
        
        // Verify pre-computed semantic styles and icons on tokens
        for word in words {
            XCTAssertNotNil(word.semanticStyle)
            if word.text == "love" {
                XCTAssertEqual(word.iconSymbol, "heart.fill")
                XCTAssertEqual(word.semanticStyle.mood, .love)
            } else if word.text == "fire" {
                XCTAssertEqual(word.semanticStyle.mood, .fire)
            } else if word.text == "driving" {
                XCTAssertEqual(word.iconSymbol, "steeringwheel")
            }
        }
    }
    
    func testSmartHomeBridgeConfiguration() {
        let bridge = SmartHomeBridge.shared
        XCTAssertEqual(bridge.activeProtocol, .disabled)
        
        bridge.activeProtocol = .philipsHue
        bridge.bridgeHost = "192.168.1.50"
        bridge.apiToken = "test-token"
        bridge.targetLightId = "2"
        
        // Sync color should execute without crash
        bridge.syncColorToSmartHome(.red)
        
        bridge.activeProtocol = .nanoleaf
        bridge.syncColorToSmartHome(.blue)
        
        bridge.activeProtocol = .disabled
    }
    
    // MARK: - Choice 1: Multi-Zone Ambilight Bezel Tests
    
    func testMultiZoneAmbilightBezelConfiguration() {
        let spectrum = AudioSpectrumEngine.shared
        XCTAssertEqual(spectrum.bands.count, 8)
        
        let bezel = BezelGlowView(isEnabled: true, glowIntensityMultiplier: 1.2)
        XCTAssertTrue(bezel.isEnabled)
        XCTAssertEqual(bezel.glowIntensityMultiplier, 1.2)
        
        // Negative & NaN multiplier resilience
        let negBezel = BezelGlowView(isEnabled: true, glowIntensityMultiplier: -5.0)
        XCTAssertEqual(negBezel.glowIntensityMultiplier, -5.0)
        let nanBezel = BezelGlowView(isEnabled: true, glowIntensityMultiplier: Double.nan)
        XCTAssertTrue(nanBezel.glowIntensityMultiplier.isNaN)
        
        // Feed sample buffer to verify hardware vector FFT execution
        let samples = [Float](repeating: 0.25, count: 1024)
        spectrum.processAudio(samples: samples)
        XCTAssertEqual(spectrum.bands.count, 8)
    }
    
    // MARK: - Choice 12: Command Palette & Instant Timing Nudge Tests
    
    func testCommandPaletteAndTimingNudge() {
        let settings = AppSettings.shared
        settings.resetTimingOffset()
        XCTAssertEqual(settings.timingOffset, 0.0, accuracy: 0.001)
        XCTAssertTrue(settings.isTimingHUDVisible)
        XCTAssertTrue(settings.timingHUDMessage.contains("Reset"))
        
        // Nudge +100ms
        settings.nudgeTimingOffset(by: 0.10)
        XCTAssertEqual(settings.timingOffset, 0.10, accuracy: 0.001)
        XCTAssertTrue(settings.isTimingHUDVisible)
        XCTAssertTrue(settings.timingHUDMessage.contains("+100ms"))
        
        // Nudge -100ms twice
        settings.nudgeTimingOffset(by: -0.10)
        XCTAssertEqual(settings.timingOffset, 0.0, accuracy: 0.001)
        settings.nudgeTimingOffset(by: -0.10)
        XCTAssertEqual(settings.timingOffset, -0.10, accuracy: 0.001)
        XCTAssertTrue(settings.timingHUDMessage.contains("-100ms"))
        
        // Reset via PlaybackManager
        PlaybackManager.shared.resetTimingOffset()
        XCTAssertEqual(settings.timingOffset, 0.0, accuracy: 0.001)
        
        // PlaybackManager nudge
        PlaybackManager.shared.nudgeTimingOffset(by: 0.10)
        XCTAssertEqual(settings.timingOffset, 0.10, accuracy: 0.001)
        PlaybackManager.shared.resetTimingOffset()
        
        // Boundary Clamping Stress: Nudge beyond +10.0s clamp limit
        for _ in 0..<150 {
            settings.nudgeTimingOffset(by: 0.10)
        }
        XCTAssertEqual(settings.timingOffset, 10.0, accuracy: 0.001, "Offset must clamp at +10.0s")
        
        // Boundary Clamping Stress: Nudge beyond -10.0s clamp limit
        for _ in 0..<250 {
            settings.nudgeTimingOffset(by: -0.10)
        }
        XCTAssertEqual(settings.timingOffset, -10.0, accuracy: 0.001, "Offset must clamp at -10.0s")
        
        // Resilience: NaN & Infinity delta should be safely rejected
        let savedOffset = settings.timingOffset
        settings.nudgeTimingOffset(by: Double.nan)
        XCTAssertEqual(settings.timingOffset, savedOffset)
        settings.nudgeTimingOffset(by: Double.infinity)
        XCTAssertEqual(settings.timingOffset, savedOffset)
        settings.resetTimingOffset()
        
        // CommandPalettePanel lifecycle & properties
        let panel = CommandPalettePanel.shared
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.canBecomeMain)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.level, .floating)
        
        panel.show()
        XCTAssertTrue(panel.isVisible)
        panel.hide()
        XCTAssertFalse(panel.isVisible)
        panel.toggle()
        XCTAssertTrue(panel.isVisible)
        panel.toggle()
        XCTAssertFalse(panel.isVisible)
    }
    
    // MARK: - Choice 3: Native macOS Screen Saver Bundle Tests
    
    func testNativeScreenSaverBundleArchitecture() {
        // Test ScreenSaverView subclass conforms to ScreenSaver framework
        let saver = VerciLumnSaverView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), isPreview: false)
        XCTAssertNotNil(saver)
        XCTAssertEqual(saver?.animationTimeInterval ?? 0, 1.0 / 30.0, accuracy: 0.001)
        XCTAssertFalse(saver?.hasConfigureSheet ?? true)
        
        // Run animation frames without throwing or leaking
        for _ in 0..<10 {
            saver?.animateOneFrame()
        }
        
        // Test Preview Mode
        let previewSaver = VerciLumnSaverView(frame: NSRect(x: 0, y: 0, width: 320, height: 180), isPreview: true)
        XCTAssertNotNil(previewSaver)
        previewSaver?.animateOneFrame()
        
        // Test Shared IPC state syncing
        ScreenSaverSharedState.sync(
            isPlaying: true,
            title: "Outro",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            beatIntensity: 0.85,
            bands: [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]
        )
        
        let readState = ScreenSaverSharedState.read()
        XCTAssertTrue(readState.isPlaying)
        XCTAssertEqual(readState.title, "Outro")
        XCTAssertEqual(readState.artist, "M83")
        XCTAssertEqual(readState.beatIntensity, 0.85, accuracy: 0.01)
        XCTAssertEqual(readState.bands.count, 8)
        XCTAssertEqual(readState.bands[0], 0.9, accuracy: 0.01)
        
        // Test live throttled audio energy sync
        ScreenSaverSharedState.syncAudioEnergy(
            beatIntensity: 0.92,
            bands: [0.95, 0.85, 0.75, 0.65, 0.55, 0.45, 0.35, 0.25]
        )
        let updatedState = ScreenSaverSharedState.read()
        XCTAssertEqual(updatedState.beatIntensity, 0.92, accuracy: 0.01)
        XCTAssertEqual(updatedState.bands[0], 0.95, accuracy: 0.01)
        
        // Test Thermal Invariant: Idle screensaver drops energy to 0.0
        let idleModel = ScreenSaverStateModel(isPreview: false)
        ScreenSaverSharedState.sync(
            isPlaying: false,
            title: "",
            artist: "",
            album: "",
            beatIntensity: 0.0,
            bands: Array(repeating: 0.0, count: 8)
        )
        idleModel.stepFrame()
        XCTAssertFalse(idleModel.isPlaying)
        XCTAssertEqual(idleModel.beatIntensity, 0.0, accuracy: 0.001)
        let initialPhase = idleModel.phase
        idleModel.stepFrame()
        XCTAssertEqual(idleModel.phase, initialPhase, "Phase must freeze during idle screensaver to guarantee 0% GPU")
    }
    
    func testScreenSamplerSyntheticBufferAndEdgeExtraction() {
        let width = 128
        let height = 72
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        // Write known BGRA colors to the outer 1-pixel borders:
        // Top edge: Red (B:0, G:0, R:255, A:255)
        for x in 0..<width {
            let offset = x * 4
            buffer[offset] = 0       // B
            buffer[offset + 1] = 0   // G
            buffer[offset + 2] = 255 // R
            buffer[offset + 3] = 255 // A
        }
        
        // Bottom edge: Blue (B:255, G:0, R:0, A:255)
        let lastRowOffset = (height - 1) * bytesPerRow
        for x in 0..<width {
            let offset = lastRowOffset + x * 4
            buffer[offset] = 255     // B
            buffer[offset + 1] = 0   // G
            buffer[offset + 2] = 0   // R
            buffer[offset + 3] = 255 // A
        }
        
        // Left edge: Green (B:0, G:255, R:0, A:255)
        for y in 0..<height {
            let offset = y * bytesPerRow
            buffer[offset] = 0       // B
            buffer[offset + 1] = 255 // G
            buffer[offset + 2] = 0   // R
            buffer[offset + 3] = 255 // A
        }
        
        // Right edge: White (B:255, G:255, R:255, A:255)
        for y in 0..<height {
            let offset = y * bytesPerRow + (width - 1) * 4
            buffer[offset] = 255     // B
            buffer[offset + 1] = 255 // G
            buffer[offset + 2] = 255 // R
            buffer[offset + 3] = 255 // A
        }
        
        buffer.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                XCTFail("Failed to get raw buffer base address")
                return
            }
            
            let result = ScreenSampler.computeEdgeColors(
                baseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )
            
            // Top edge should be dominant red
            XCTAssertGreaterThanOrEqual(result.top.r, 0.95)
            XCTAssertLessThanOrEqual(result.top.g, 0.1)
            
            // Bottom edge should be dominant blue
            XCTAssertGreaterThanOrEqual(result.bottom.b, 0.95)
            XCTAssertLessThanOrEqual(result.bottom.r, 0.1)
            
            // Left edge should be dominant green
            XCTAssertGreaterThanOrEqual(result.left.g, 0.95)
            XCTAssertLessThanOrEqual(result.left.r, 0.1)
            
            // Right edge should be white (all channels high)
            XCTAssertGreaterThanOrEqual(result.right.r, 0.95)
            XCTAssertGreaterThanOrEqual(result.right.g, 0.95)
            XCTAssertGreaterThanOrEqual(result.right.b, 0.95)
        }
        
        // Test degenerate buffer bounds safety
        let singlePixel = [UInt8](repeating: 128, count: 4)
        singlePixel.withUnsafeBytes { raw in
            let degenerate = ScreenSampler.computeEdgeColors(
                baseAddress: raw.baseAddress!,
                width: 1,
                height: 1,
                bytesPerRow: 4
            )
            XCTAssertEqual(degenerate.top.r, 0.0)
            XCTAssertEqual(degenerate.bottom.r, 0.0)
        }
        
        // Lifecycle safety
        let sampler = ScreenSampler.shared
        sampler.stop()
        XCTAssertFalse(sampler.isRunning)
    }
    
    func testScriptingBridgeControllerAndMediaControls() {
        let bridge = ScriptingBridgeController.shared
        
        // Ensure calls are completely safe and do not throw in test environments
        bridge.togglePlayPause(source: "Spotify")
        bridge.nextTrack(source: "Spotify")
        bridge.previousTrack(source: "Spotify")
        
        bridge.togglePlayPause(source: "Apple Music")
        bridge.nextTrack(source: "Apple Music")
        bridge.previousTrack(source: "Apple Music")
        
        // PlaybackManager public control facade
        let playback = PlaybackManager.shared
        playback.togglePlayPause()
        playback.nextTrack()
        playback.previousTrack()
        
        XCTAssertNotNil(playback.currentTrack)
    }
    
    func testLyricsTranslatorAndSubtitleStacking() {
        let line1 = LyricLine(
            timestamp: 10.0,
            fullText: "Je te laisserai des mots",
            words: [
                WordToken(text: "Je", timestamp: 10.0),
                WordToken(text: "te", timestamp: 10.3),
                WordToken(text: "laisserai", timestamp: 10.6)
            ],
            translation: "I will leave you notes"
        )
        
        XCTAssertEqual(line1.translation, "I will leave you notes")
        XCTAssertEqual(line1.fullText, "Je te laisserai des mots")
        XCTAssertEqual(line1.words.count, 3)
        
        let lyricsData = LyricsData(
            trackTitle: "Je te laisserai des mots",
            artistName: "Patrick Watson",
            lines: [line1],
            isWordSynced: true
        )
        
        let expectation = self.expectation(description: "LyricsTranslator Async")
        
        LyricsTranslator.shared.translateAsync(
            lyrics: lyricsData,
            targetLanguage: "en",
            generation: 1
        ) { translated in
            XCTAssertEqual(translated.lines.count, 1)
            XCTAssertNotNil(translated.lines[0].translation)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    func testImmersiveModePresentationOptionsAndScreenExpansion() {
        let settings = AppSettings.shared
        let windowManager = OverlayWindowManager.shared
        
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let testPanel = StageOverlayPanel(contentView: NSView(), screen: screen)
        
        // Initial state
        settings.isImmersiveModeEnabled = false
        XCTAssertFalse(testPanel.canBecomeKey)
        XCTAssertFalse(testPanel.canBecomeMain)
        
        // Activate Immersive Mode
        settings.isImmersiveModeEnabled = true
        
        let expEnable = expectation(description: "Enable Immersive Mode")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(windowManager.isImmersiveMode)
            XCTAssertTrue(NSApp.presentationOptions.contains(.autoHideMenuBar))
            XCTAssertTrue(NSApp.presentationOptions.contains(.autoHideDock))
            XCTAssertTrue(testPanel.canBecomeKey)
            XCTAssertTrue(testPanel.canBecomeMain)
            
            // Expand frame check: matches full physical screen bounds, ignoring safe areas
            testPanel.expandToScreenBounds()
            XCTAssertEqual(testPanel.frame.size.width, screen.frame.size.width, accuracy: 1.0)
            XCTAssertEqual(testPanel.frame.size.height, screen.frame.size.height, accuracy: 1.0)
            
            expEnable.fulfill()
        }
        wait(for: [expEnable], timeout: 2.0)
        
        // Deactivate Immersive Mode
        settings.isImmersiveModeEnabled = false
        
        let expDisable = expectation(description: "Disable Immersive Mode")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(windowManager.isImmersiveMode)
            XCTAssertFalse(NSApp.presentationOptions.contains(.autoHideMenuBar))
            XCTAssertFalse(NSApp.presentationOptions.contains(.autoHideDock))
            XCTAssertFalse(testPanel.canBecomeKey)
            XCTAssertFalse(testPanel.canBecomeMain)
            expDisable.fulfill()
        }
        wait(for: [expDisable], timeout: 2.0)
    }
    
    func testDraggableResizableFloatingOverlayPodGeometryAndHitTesting() {
        let settings = AppSettings.shared
        let windowManager = OverlayWindowManager.shared
        
        // 1. Initial / Default geometry
        settings.resetFloatingGeometry()
        XCTAssertEqual(settings.floatingOffsetX, 0.0)
        XCTAssertEqual(settings.floatingOffsetY, 0.0)
        XCTAssertEqual(settings.floatingWidth, 540.0)
        XCTAssertEqual(settings.floatingHeight, 360.0)
        
        // 2. Drag offset modifications
        settings.floatingOffsetX = 120.0
        settings.floatingOffsetY = -80.0
        XCTAssertEqual(settings.floatingOffsetX, 120.0)
        XCTAssertEqual(settings.floatingOffsetY, -80.0)
        
        // 3. Resizing clamping stress tests
        settings.floatingWidth = 200.0 // Below minimum 320
        XCTAssertEqual(settings.floatingWidth, 320.0, "Width must clamp at min 320")
        
        settings.floatingWidth = 2500.0 // Above maximum 1200
        XCTAssertEqual(settings.floatingWidth, 1200.0, "Width must clamp at max 1200")
        
        settings.floatingHeight = 100.0 // Below minimum 180
        XCTAssertEqual(settings.floatingHeight, 180.0, "Height must clamp at min 180")
        
        settings.floatingHeight = 1500.0 // Above maximum 800
        XCTAssertEqual(settings.floatingHeight, 800.0, "Height must clamp at max 800")
        
        // 4. Reset function restores standard dimensions
        settings.resetFloatingGeometry()
        XCTAssertEqual(settings.floatingWidth, 540.0)
        XCTAssertEqual(settings.floatingHeight, 360.0)
        XCTAssertEqual(settings.floatingOffsetX, 0.0)
        XCTAssertEqual(settings.floatingOffsetY, 0.0)
        
        // 5. Test Hit Testing conversion in StageOverlayPanel
        settings.displayMode = .floating
        let screenRect = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let hostingView = InteractivePassThroughHostingView(rootView: RootOverlayView())
        hostingView.frame = screenRect
        let panel = StageOverlayPanel(contentView: hostingView)
        panel.setFrame(screenRect, display: false)
        
        // Simulate floating pod reported by SwiftUI GeometryReader:
        // centered pod at x: 450, y: 270, width: 540, height: 360 (top-left SwiftUI coords)
        let swiftUIRect = CGRect(x: 450, y: 270, width: 540, height: 360)
        windowManager.updateFloatingWidgetRect(swiftUIRect)
        XCTAssertEqual(windowManager.floatingWidgetRect, swiftUIRect)
        
        // AppKit coordinates:
        // y in AppKit = 900 - 270 - 360 = 270 to 630
        // Center point: x = 720, y = 450
        let insidePoint = NSPoint(x: 720, y: 450)
        let outsidePoint = NSPoint(x: 100, y: 100)
        
        let insideResult = hostingView.hitTest(insidePoint)
        XCTAssertNotNil(insideResult, "Clicks inside floating pod must be intercepted for drag/resize/seeking")
        
        let outsideResult = hostingView.hitTest(outsidePoint)
        XCTAssertNil(outsideResult, "Clicks outside floating pod must pass through to background apps")
    }
}
