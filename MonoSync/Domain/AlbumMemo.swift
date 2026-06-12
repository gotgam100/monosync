import Foundation

struct AlbumMemo: Codable, Identifiable, Hashable {
    var id: String { album.id }
    var album: AlbumSnapshot
    var text: String
    var updatedAt: Date
}
