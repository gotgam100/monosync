import Foundation

enum PlaybackEvent: Hashable, Sendable {
    case started(track: TrackSnapshot, position: TimeInterval, at: Date)
    case paused(position: TimeInterval, at: Date)
    case resumed(position: TimeInterval, at: Date)
    case seeked(position: TimeInterval, at: Date)
    case stopped(position: TimeInterval, at: Date)
}
