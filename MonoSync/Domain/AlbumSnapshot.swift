import Foundation

enum CassetteSide: String, Identifiable, Hashable, Codable, Sendable {
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

struct AlbumSnapshot: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var artistName: String
    var artistID: String?
    var releaseYear: String?
    var artworkURL: URL?
    var tracks: [TrackSnapshot]
    // 트랙을 모두 로드하지 않아도 곡 수를 표시하기 위한 값(검색 결과 등).
    var trackCount: Int? = nil
    var recordLabelName: String? = nil
    var editorialNotes: String? = nil
    var genreNames: [String]? = nil
    var isCompilation: Bool? = nil

    var subtitle: String {
        "\(artistName) · \(albumFactText)"
    }

    var isPlaylistAlbum: Bool {
        id.hasPrefix("monosync-playlist-album:")
    }

    var primaryDetailText: String {
        artistName
    }

    var secondaryDetailText: String? {
        isPlaylistAlbum ? nil : albumFactText
    }

    var albumFactText: String {
        let count = trackCount ?? tracks.count
        if isPlaylistAlbum {
            return count > 0 ? "\(count)곡" : "플레이리스트"
        }
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
