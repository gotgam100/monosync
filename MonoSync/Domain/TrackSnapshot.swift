import Foundation

struct TrackSnapshot: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var artistName: String
    var albumTitle: String
    var artworkURL: URL?
    var duration: TimeInterval

    static let snowfall = TrackSnapshot(
        id: "applemusic:snowfall-demo",
        title: "Snowfall",
        artistName: "oneheart x reidenshi",
        albumTitle: "Snowfall",
        artworkURL: nil,
        duration: 204
    )

    static let samples: [TrackSnapshot] = [
        .snowfall,
        TrackSnapshot(id: "applemusic:bone-demo", title: "Bone", artistName: "Sonic Youth", albumTitle: "Experimental Jet Set", artworkURL: nil, duration: 198),
        TrackSnapshot(id: "applemusic:review-demo", title: "Review", artistName: "Depeche Mode", albumTitle: "Mono Notes", artworkURL: nil, duration: 236),
        TrackSnapshot(id: "applemusic:drowning-demo", title: "Drowning", artistName: "Woodz", albumTitle: "Only Lovers", artworkURL: nil, duration: 216)
    ]
}

extension TrackSnapshot {
    func matches(_ other: TrackSnapshot) -> Bool {
        id == other.id
            || (
                title.caseInsensitiveCompare(other.title) == .orderedSame
                && artistName.caseInsensitiveCompare(other.artistName) == .orderedSame
            )
    }
}
