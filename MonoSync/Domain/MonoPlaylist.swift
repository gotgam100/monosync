import Foundation

struct MonoPlaylist: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var tracks: [TrackSnapshot]
    var createdAt: Date
    var updatedAt: Date

    var subtitle: String {
        "\(tracks.count)곡"
    }

    static let sample = MonoPlaylist(
        id: UUID().uuidString,
        title: "나의 첫 모노플리",
        tracks: [.snowfall],
        createdAt: .now,
        updatedAt: .now
    )
}
