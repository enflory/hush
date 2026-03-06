import Foundation

/// Fetches Spotify's Now Playing metadata via AppleScript.
///
/// macOS 26 restricts MediaRemote private framework access to Apple-signed
/// binaries, so we query Spotify directly instead.
public final class MediaRemoteBridge {
    public static let shared = MediaRemoteBridge()

    // Retained for MediaMonitor compatibility until polling replaces notifications (Task 5)
    public static let nowPlayingInfoDidChange = NSNotification.Name(
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    )
    public static let nowPlayingApplicationDidChange = NSNotification.Name(
        "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
    )

    private let script: NSAppleScript?

    private static let appleScriptSource = """
        tell application "System Events"
            if not (exists process "Spotify") then return "NOT_RUNNING"
        end tell
        tell application "Spotify"
            if player state is stopped then return "STOPPED"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackURL to spotify url of current track
            set pState to player state as string
            return trackName & "\\n" & trackArtist & "\\n" & trackAlbum & "\\n" & trackURL & "\\n" & pState
        end tell
        """

    private init() {
        script = NSAppleScript(source: Self.appleScriptSource)
    }

    public func registerForNotifications() {
        // No-op: polling replaces notification-based monitoring
    }

    /// Get current Now Playing info. Calls completion synchronously with the result.
    public func getNowPlayingInfo(completion: @escaping (NowPlayingMetadata?) -> Void) {
        guard let script = script else {
            completion(nil)
            return
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if error != nil {
            completion(nil)
            return
        }

        guard let output = result.stringValue else {
            completion(nil)
            return
        }

        if output == "NOT_RUNNING" || output == "STOPPED" {
            completion(nil)
            return
        }

        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 5 else {
            completion(nil)
            return
        }

        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let spotifyURL = parts[3]
        let playerState = parts[4]
        let isPlaying = playerState == "playing"
        let isAdByURL = spotifyURL.hasPrefix("spotify:ad:")

        let metadata = NowPlayingMetadata(
            title: title,
            artist: artist,
            album: album,
            bundleID: "com.spotify.client",
            playbackRate: isPlaying ? 1.0 : 0.0,
            isAdByURL: isAdByURL
        )
        completion(metadata)
    }
}
