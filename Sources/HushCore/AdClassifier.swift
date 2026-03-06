import Foundation

public protocol AdClassifier {
    func isAd(metadata: NowPlayingMetadata) -> Bool
}
