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
    // 트랙을 모두 로드하지 않아도 곡 수를 표시하기 위한 값(검색 결과 등).
    var trackCount: Int? = nil

    var subtitle: String {
        "\(artistName) · \(albumFactText)"
    }

    var albumFactText: String {
        let count = trackCount ?? tracks.count
        return "\(releaseYear ?? "연도 미상") · \(count)곡"
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
