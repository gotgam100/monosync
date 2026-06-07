import Foundation

struct MusicCollectionSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    var sourceID: String
    var title: String
    var subtitle: String
    var artworkURL: URL?
}
