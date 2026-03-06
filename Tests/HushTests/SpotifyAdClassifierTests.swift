import Testing
@testable import HushCore

@Suite("SpotifyAdClassifier")
struct SpotifyAdClassifierTests {
    let classifier = SpotifyAdClassifier()
    let spotifyBundleID = "com.spotify.client"

    @Test func detectsAdvertisementTitle() {
        let metadata = NowPlayingMetadata(
            title: "Advertisement",
            artist: "",
            album: "",
            bundleID: spotifyBundleID,
            playbackRate: 1.0
        )
        #expect(classifier.isAd(metadata: metadata))
    }

    @Test func detectsSpotifyArtistAsAd() {
        let metadata = NowPlayingMetadata(
            title: "Spotify",
            artist: "Spotify",
            album: "",
            bundleID: spotifyBundleID,
            playbackRate: 1.0
        )
        #expect(classifier.isAd(metadata: metadata))
    }

    @Test func normalTrackIsNotAd() {
        let metadata = NowPlayingMetadata(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            bundleID: spotifyBundleID,
            playbackRate: 1.0
        )
        #expect(!classifier.isAd(metadata: metadata))
    }

    @Test func nonSpotifySourceIsNotAd() {
        let metadata = NowPlayingMetadata(
            title: "Advertisement",
            artist: "",
            album: "",
            bundleID: "com.apple.Music",
            playbackRate: 1.0
        )
        #expect(!classifier.isAd(metadata: metadata))
    }

    @Test func emptyTitleWithSpotifyArtistIsAd() {
        let metadata = NowPlayingMetadata(
            title: "",
            artist: "Spotify",
            album: "",
            bundleID: spotifyBundleID,
            playbackRate: 1.0
        )
        #expect(classifier.isAd(metadata: metadata))
    }

    @Test func pausedAdIsStillAd() {
        let metadata = NowPlayingMetadata(
            title: "Advertisement",
            artist: "",
            album: "",
            bundleID: spotifyBundleID,
            playbackRate: 0.0
        )
        #expect(classifier.isAd(metadata: metadata))
    }
}
