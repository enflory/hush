import Foundation

public struct SpotifyAdClassifier: AdClassifier {
    private static let spotifyBundleID = "com.spotify.client"
    private static let adTitles: Set<String> = ["Advertisement", "Spotify"]
    private static let adArtists: Set<String> = ["", "Spotify"]

    public init() {}

    public func isAd(metadata: NowPlayingMetadata) -> Bool {
        guard metadata.bundleID == Self.spotifyBundleID else { return false }

        if metadata.isAdByURL { return true }
        if metadata.isPodcastByURL { return false }

        return Self.adTitles.contains(metadata.title) ||
               Self.adArtists.contains(metadata.artist)
    }
}
