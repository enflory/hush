import Foundation

public enum MonitorAction: Equatable {
    case volumeDimmed
    case volumeRestored
    case noChange
}

public enum MonitorState: Equatable {
    case idle
    case normal
    case dimmed

    /// Transition based on current metadata. Returns the action to take.
    /// Mutates self to the new state.
    @discardableResult
    public mutating func transition(isSpotify: Bool, isAd: Bool, isPlaying: Bool) -> MonitorAction {
        switch self {
        case .idle:
            if isSpotify && isAd {
                self = .dimmed
                return .volumeDimmed
            } else if isSpotify && isPlaying {
                self = .normal
                return .noChange
            }
            return .noChange

        case .normal:
            if !isSpotify || !isPlaying {
                self = .idle
                return .noChange
            } else if isAd {
                self = .dimmed
                return .volumeDimmed
            }
            return .noChange

        case .dimmed:
            if !isSpotify {
                self = .idle
                return .volumeRestored
            } else if !isAd && isPlaying {
                self = .normal
                return .volumeRestored
            }
            return .noChange
        }
    }
}
