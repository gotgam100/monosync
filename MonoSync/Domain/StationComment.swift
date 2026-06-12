import Foundation

struct StationComment: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var authorUID: String
    var authorDisplayName: String
    var content: String
    var createdAt: Date
    var trackContext: TrackSnapshot?

    init(id: String = UUID().uuidString, authorUID: String, authorDisplayName: String, content: String, createdAt: Date = .now, trackContext: TrackSnapshot? = nil) {
        self.id = id
        self.authorUID = authorUID
        self.authorDisplayName = authorDisplayName
        self.content = content
        self.createdAt = createdAt
        self.trackContext = trackContext
    }
}
