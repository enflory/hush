import Testing
@testable import HushCore

@Suite("MonitorState")
struct MonitorStateTests {
    @Test func idleToNormalOnMusic() {
        var state = MonitorState.idle
        let action = state.transition(isSpotify: true, isAd: false, isPlaying: true)
        #expect(state == .normal)
        #expect(action == .noChange)
    }

    @Test func idleToDimmedOnAd() {
        var state = MonitorState.idle
        let action = state.transition(isSpotify: true, isAd: true, isPlaying: true)
        #expect(state == .dimmed)
        #expect(action == .volumeDimmed)
    }

    @Test func normalToDimmedOnAd() {
        var state = MonitorState.normal
        let action = state.transition(isSpotify: true, isAd: true, isPlaying: true)
        #expect(state == .dimmed)
        #expect(action == .volumeDimmed)
    }

    @Test func dimmedToNormalOnMusic() {
        var state = MonitorState.dimmed
        let action = state.transition(isSpotify: true, isAd: false, isPlaying: true)
        #expect(state == .normal)
        #expect(action == .volumeRestored)
    }

    @Test func normalToIdleOnSpotifyStop() {
        var state = MonitorState.normal
        let action = state.transition(isSpotify: false, isAd: false, isPlaying: false)
        #expect(state == .idle)
        #expect(action == .noChange)
    }

    @Test func dimmedToIdleOnSpotifyStop() {
        var state = MonitorState.dimmed
        let action = state.transition(isSpotify: false, isAd: false, isPlaying: false)
        #expect(state == .idle)
        #expect(action == .volumeRestored)
    }

    @Test func dimmedStaysDimmedOnPause() {
        var state = MonitorState.dimmed
        let action = state.transition(isSpotify: true, isAd: true, isPlaying: false)
        #expect(state == .dimmed)
        #expect(action == .noChange)
    }

    @Test func normalStaysNormalOnSameTrack() {
        var state = MonitorState.normal
        let action = state.transition(isSpotify: true, isAd: false, isPlaying: true)
        #expect(state == .normal)
        #expect(action == .noChange)
    }

    @Test func idleStaysIdleOnNonSpotify() {
        var state = MonitorState.idle
        let action = state.transition(isSpotify: false, isAd: false, isPlaying: true)
        #expect(state == .idle)
        #expect(action == .noChange)
    }
}
