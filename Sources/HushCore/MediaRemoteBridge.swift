import Foundation

public final class MediaRemoteBridge {
    public static let shared = MediaRemoteBridge()

    // Notification name
    public static let nowPlayingInfoDidChange = NSNotification.Name(
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    )
    public static let nowPlayingApplicationDidChange = NSNotification.Name(
        "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
    )

    // Info dictionary keys
    public static let kTitle = "kMRMediaRemoteNowPlayingInfoTitle"
    public static let kArtist = "kMRMediaRemoteNowPlayingInfoArtist"
    public static let kAlbum = "kMRMediaRemoteNowPlayingInfoAlbum"
    public static let kPlaybackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"

    // Function types matching MediaRemote C signatures
    private typealias GetNowPlayingInfoFn = @convention(c) (
        DispatchQueue, @escaping ([String: Any]) -> Void
    ) -> Void
    private typealias RegisterNotificationsFn = @convention(c) (DispatchQueue) -> Void
    private typealias GetBundleIDFn = @convention(c) (
        DispatchQueue, @escaping (CFString) -> Void
    ) -> Void

    private var getNowPlayingInfoFn: GetNowPlayingInfoFn?
    private var registerNotificationsFn: RegisterNotificationsFn?
    private var getBundleIDFn: GetBundleIDFn?

    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY
        ) else {
            print("Hush: Failed to load MediaRemote framework")
            return
        }

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfoFn = unsafeBitCast(sym, to: GetNowPlayingInfoFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerNotificationsFn = unsafeBitCast(sym, to: RegisterNotificationsFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationBundleIdentifier") {
            getBundleIDFn = unsafeBitCast(sym, to: GetBundleIDFn.self)
        }
    }

    /// Call once at startup to register for Now Playing notifications.
    public func registerForNotifications() {
        registerNotificationsFn?(.main)
    }

    /// Get current Now Playing info. Calls completion with metadata on main queue.
    public func getNowPlayingInfo(completion: @escaping (NowPlayingMetadata?) -> Void) {
        guard let getInfo = getNowPlayingInfoFn, let getBundleID = getBundleIDFn else {
            completion(nil)
            return
        }

        getBundleID(.main) { bundleID in
            getInfo(.main) { info in
                let title = info[MediaRemoteBridge.kTitle] as? String ?? ""
                let artist = info[MediaRemoteBridge.kArtist] as? String ?? ""
                let album = info[MediaRemoteBridge.kAlbum] as? String ?? ""
                let playbackRate = info[MediaRemoteBridge.kPlaybackRate] as? Double ?? 0.0

                let metadata = NowPlayingMetadata(
                    title: title,
                    artist: artist,
                    album: album,
                    bundleID: bundleID as String,
                    playbackRate: playbackRate
                )
                completion(metadata)
            }
        }
    }
}
