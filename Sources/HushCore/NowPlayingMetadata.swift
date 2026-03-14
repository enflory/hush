import Foundation

public struct NowPlayingMetadata {
    public let title: String
    public let artist: String
    public let album: String
    public let bundleID: String
    public let playbackRate: Double
    public let isAdByURL: Bool
    public let isPodcastByURL: Bool

    public init(title: String, artist: String, album: String, bundleID: String, playbackRate: Double, isAdByURL: Bool = false, isPodcastByURL: Bool = false) {
        self.title = title
        self.artist = artist
        self.album = album
        self.bundleID = bundleID
        self.playbackRate = playbackRate
        self.isAdByURL = isAdByURL
        self.isPodcastByURL = isPodcastByURL
    }
}
