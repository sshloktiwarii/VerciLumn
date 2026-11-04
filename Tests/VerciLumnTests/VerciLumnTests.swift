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
}
