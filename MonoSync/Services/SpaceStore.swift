import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol SpaceStoring {
    func publish(space: ListeningSpace, event: PlaybackEvent) async
    func listenToSpace(id: ListeningSpace.ID) -> AsyncStream<ListeningSpace>
}

final class InMemorySpaceStore: SpaceStoring {
    private var spaces: [ListeningSpace.ID: ListeningSpace] = [:]

    func publish(space: ListeningSpace, event: PlaybackEvent) async {
        spaces[space.id] = space
    }

    func listenToSpace(id: ListeningSpace.ID) -> AsyncStream<ListeningSpace> {
        AsyncStream { continuation in
            if let space = spaces[id] {
                continuation.yield(space)
            }
            continuation.finish()
        }
    }
}

#if canImport(FirebaseFirestore)
final class FirestoreSpaceStore: SpaceStoring {
    private let db = Firestore.firestore()

    func publish(space: ListeningSpace, event: PlaybackEvent) async {
        let data: [String: Any] = [
            "trackId": space.currentTrack?.id as Any,
            "position": space.positionAtAnchor,
            "startedAt": space.playbackStartedAt as Any,
            "playbackState": space.playbackState.rawValue,
            "updatedAt": Date(),
            "ownerId": space.owner.id,
            "visibility": space.visibility.rawValue
        ]

        do {
            try await db.collection("spaces").document(space.id).setData(data, merge: true)
        } catch {
            #if DEBUG
            print("Firestore space publish failed:", error.localizedDescription)
            #endif
        }
    }

    func listenToSpace(id: ListeningSpace.ID) -> AsyncStream<ListeningSpace> {
        AsyncStream { continuation in
            let listener = db.collection("spaces").document(id).addSnapshotListener { _, _ in
                // 실제 친구 스페이스 구독은 사용자/트랙 캐시 모델을 붙인 뒤 복원합니다.
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
#endif

/*
 Firebase implementation notes:

 Firestore document writes should happen only for PlaybackEvent changes.
 Do not write a ticking playback position. Store:

 - trackId
 - position
 - startedAt
 - playbackState
 - updatedAt

 Clients calculate current playback position locally from those anchors.
 */
