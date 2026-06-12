import Foundation

enum SpaceVisibility: String, CaseIterable, Identifiable, Sendable {
    case privateSpace
    case friends
    case link
    case publicSpace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .privateSpace: "now.private"
        case .friends: "friends"
        case .link: "link"
        case .publicSpace: "now.public"
        }
    }
}

enum PlaybackState: String, Sendable {
    case idle
    case playing
    case paused
}

struct ListeningSpace: Identifiable, Hashable, Sendable {
    let id: String
    var owner: MonoUser
    var title: String
    var stationDescription: String
    var visibility: SpaceVisibility
    var currentTrack: TrackSnapshot?
    var playbackState: PlaybackState
    var playbackStartedAt: Date?
    var positionAtAnchor: TimeInterval
    var updatedAt: Date
    var listenerCount: Int

    var isLive: Bool {
        playbackState == .playing && currentTrack != nil
    }

    func currentPosition(now: Date = .now) -> TimeInterval {
        guard playbackState == .playing, let playbackStartedAt else {
            return positionAtAnchor
        }
        return max(0, positionAtAnchor + now.timeIntervalSince(playbackStartedAt))
    }

    mutating func apply(_ event: PlaybackEvent) {
        updatedAt = .now
        switch event {
        case let .started(track, position, at):
            currentTrack = track
            playbackState = .playing
            playbackStartedAt = at
            positionAtAnchor = position
        case let .paused(position, at):
            playbackState = .paused
            playbackStartedAt = at
            positionAtAnchor = position
        case let .resumed(position, at):
            playbackState = .playing
            playbackStartedAt = at
            positionAtAnchor = position
        case let .seeked(position, at):
            playbackStartedAt = at
            positionAtAnchor = position
        case let .stopped(position, _):
            playbackState = .idle
            playbackStartedAt = nil
            positionAtAnchor = position
        }
    }

    static let sampleMe = ListeningSpace(
        id: "space-me",
        owner: .sampleMe,
        title: "monosync space",
        stationDescription: "환영합니다! 제가 좋아하는 음악들을 주로 듣는 공간이에요.",
        visibility: .friends,
        currentTrack: nil,
        playbackState: .idle,
        playbackStartedAt: nil,
        positionAtAnchor: 0,
        updatedAt: .now,
        listenerCount: 0
    )

    static let sampleFriends: [ListeningSpace] = [
        ListeningSpace(id: "space-rin", owner: MonoUser(id: "rin", displayName: "Rin", handle: "@rin.fm", isFriend: true), title: "late night desk", stationDescription: "새벽 감성 위주로 듣습니다.", visibility: .friends, currentTrack: TrackSnapshot.samples[1], playbackState: .playing, playbackStartedAt: Date().addingTimeInterval(-36), positionAtAnchor: 0, updatedAt: .now, listenerCount: 2),
        ListeningSpace(id: "space-mono", owner: MonoUser(id: "mono", displayName: "Mono", handle: "@mono.radio", isFriend: false), title: "public tiny radio", stationDescription: "누구나 환영", visibility: .publicSpace, currentTrack: TrackSnapshot.samples[2], playbackState: .playing, playbackStartedAt: Date().addingTimeInterval(-148), positionAtAnchor: 0, updatedAt: .now, listenerCount: 28),
        ListeningSpace(id: "space-june", owner: MonoUser(id: "june", displayName: "June", handle: "@june", isFriend: true), title: "quiet room", stationDescription: "작업용 음악", visibility: .friends, currentTrack: nil, playbackState: .idle, playbackStartedAt: nil, positionAtAnchor: 0, updatedAt: .now, listenerCount: 0)
    ]
}
