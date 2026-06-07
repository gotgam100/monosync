import Foundation

enum CassetteSide: String, Identifiable, Hashable, Sendable {
    case a
    case b

    var id: String { rawValue }

    var title: String {
        switch self {
        case .a: "A면"
        case .b: "B면"
        }
    }
}

struct AlbumSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var artistName: String
    var releaseYear: String?
    var artworkURL: URL?
    var tracks: [TrackSnapshot]

    var subtitle: String {
        "\(artistName) · \(albumFactText)"
    }

    var albumFactText: String {
        "\(releaseYear ?? "연도 미상") · \(tracks.count)곡"
    }

    static let sample = AlbumSnapshot(
        id: "applemusic-album:mono-sample",
        title: "Mono Demo",
        artistName: "MonoSync",
        releaseYear: "2026",
        artworkURL: nil,
        tracks: TrackSnapshot.samples
    )
}
