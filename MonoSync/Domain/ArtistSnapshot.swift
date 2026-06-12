import Foundation

struct ArtistSnapshot: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var name: String
    var artworkURL: URL?
    var editorialNotes: String?
    var albums: [AlbumSnapshot]
    var similarArtists: [ArtistSnapshot]
    
    var subtitle: String? {
        "아티스트"
    }
}
