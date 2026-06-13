import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol StationStoring: Sendable {
    /// 해당 공간(station)의 댓글들을 실시간 구독합니다.
    func observeComments(spaceID: String) -> AsyncStream<[StationComment]>
    
    /// 새로운 댓글을 작성합니다.
    func postComment(spaceID: String, comment: StationComment) async throws
}

struct NoOpStationStore: StationStoring {
    func observeComments(spaceID: String) -> AsyncStream<[StationComment]> {
        AsyncStream { $0.finish() }
    }
    func postComment(spaceID: String, comment: StationComment) async throws {}
}

#if canImport(FirebaseFirestore)
final class FirestoreStationStore: StationStoring, @unchecked Sendable {
    private var db: Firestore { Firestore.firestore() }
    
    func observeComments(spaceID: String) -> AsyncStream<[StationComment]> {
        AsyncStream { continuation in
            let listener = db.collection("spaces").document(spaceID)
                .collection("comments")
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .addSnapshotListener { snapshot, _ in
                    guard let docs = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    
                    let comments = docs.compactMap { doc -> StationComment? in
                        let data = doc.data()
                        guard let authorUID = data["authorUID"] as? String,
                              let authorName = data["authorDisplayName"] as? String,
                              let content = data["content"] as? String else { return nil }
                        
                        var track: TrackSnapshot?
                        if let trackId = data["trackId"] as? String {
                            track = TrackSnapshot(
                                id: trackId,
                                title: data["trackTitle"] as? String ?? "",
                                artistName: data["trackArtist"] as? String ?? "",
                                albumTitle: data["trackAlbum"] as? String ?? "",
                                artworkURL: (data["trackArtworkURL"] as? String).flatMap { URL(string: $0) },
                                duration: data["trackDuration"] as? TimeInterval ?? 0
                            )
                        }
                        
                        return StationComment(
                            id: doc.documentID,
                            authorUID: authorUID,
                            authorDisplayName: authorName,
                            content: content,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                            trackContext: track
                        )
                    }
                    continuation.yield(comments)
                }
            
            continuation.onTermination = { _ in listener.remove() }
        }
    }
    
    func postComment(spaceID: String, comment: StationComment) async throws {
        var data: [String: Any] = [
            "authorUID": comment.authorUID,
            "authorDisplayName": comment.authorDisplayName,
            "content": comment.content,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let track = comment.trackContext {
            data["trackId"] = track.id
            data["trackTitle"] = track.title
            data["trackArtist"] = track.artistName
            data["trackAlbum"] = track.albumTitle
            data["trackDuration"] = track.duration
            data["trackArtworkURL"] = track.artworkURL?.absoluteString as Any
        }
        
        try await db.collection("spaces").document(spaceID)
            .collection("comments").document(comment.id)
            .setData(data)
    }
}
#endif
