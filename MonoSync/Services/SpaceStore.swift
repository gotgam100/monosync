import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol SpaceStoring: Sendable {
    /// 내 재생 상태를 spaces/{ownerId} 문서에 발행합니다(재생 이벤트가 바뀔 때만 호출).
    func publish(space: ListeningSpace, event: PlaybackEvent) async
    /// 친구들의 spaces 문서를 실시간 구독합니다. 각 변경마다 해당 ListeningSpace를 방출합니다.
    func listenToSpaces(ownerIDs: [String]) -> AsyncStream<ListeningSpace>
    /// 단일 공간 정보를 1회성으로 읽어옵니다. (딥링크 접속용)
    func fetchSpace(id: String) async throws -> ListeningSpace
}

final class InMemorySpaceStore: SpaceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var spaces: [String: ListeningSpace] = [:]

    func publish(space: ListeningSpace, event: PlaybackEvent) async {
        lock.withLock {
            spaces[space.owner.id] = space
        }
    }

    func listenToSpaces(ownerIDs: [String]) -> AsyncStream<ListeningSpace> {
        AsyncStream { continuation in
            let snapshot = lock.withLock {
                ownerIDs.compactMap { spaces[$0] }
            }
            for space in snapshot { continuation.yield(space) }
            continuation.finish()
        }
    }

    func fetchSpace(id: String) async throws -> ListeningSpace {
        if let space = lock.withLock({ spaces[id] }) {
            return space
        }
        throw NSError(domain: "SpaceStoreError", code: 404, userInfo: [NSLocalizedDescriptionKey: "공간을 찾을 수 없습니다."])
    }
}

#if canImport(FirebaseFirestore)
final class FirestoreSpaceStore: SpaceStoring, @unchecked Sendable {
    private let db = Firestore.firestore()

    func publish(space: ListeningSpace, event: PlaybackEvent) async {
        var data: [String: Any] = [
            "ownerId": space.owner.id,
            "ownerName": space.owner.displayName,
            "ownerHandle": space.owner.handle,
            "title": space.title,
            "stationDescription": space.stationDescription,
            "playbackState": space.playbackState.rawValue,
            "position": space.positionAtAnchor,
            "visibility": space.visibility.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let startedAt = space.playbackStartedAt {
            data["startedAt"] = Timestamp(date: startedAt)
        } else {
            data["startedAt"] = FieldValue.delete()
        }

        if let track = space.currentTrack {
            data["trackId"] = track.id
            data["trackTitle"] = track.title
            data["trackArtist"] = track.artistName
            data["trackAlbum"] = track.albumTitle
            data["trackDuration"] = track.duration
            data["trackArtworkURL"] = track.artworkURL?.absoluteString as Any
        } else {
            for key in ["trackId", "trackTitle", "trackArtist", "trackAlbum", "trackDuration", "trackArtworkURL"] {
                data[key] = FieldValue.delete()
            }
        }

        do {
            try await db.collection("spaces").document(space.owner.id).setData(data, merge: true)
        } catch {
            #if DEBUG
            print("[MonoSync] space publish 실패:", error.localizedDescription)
            #endif
        }
    }

    func listenToSpaces(ownerIDs: [String]) -> AsyncStream<ListeningSpace> {
        AsyncStream { continuation in
            guard !ownerIDs.isEmpty else { continuation.finish(); return }
            var listeners: [ListenerRegistration] = []
            for id in ownerIDs {
                let listener = db.collection("spaces").document(id)
                    .addSnapshotListener { snapshot, _ in
                        guard let data = snapshot?.data(),
                              let space = ListeningSpace(documentID: id, data: data) else { return }
                        continuation.yield(space)
                    }
                listeners.append(listener)
            }
            continuation.onTermination = { _ in listeners.forEach { $0.remove() } }
        }
    }

    func fetchSpace(id: String) async throws -> ListeningSpace {
        let snapshot = try await db.collection("spaces").document(id).getDocument()
        guard let data = snapshot.data(), let space = ListeningSpace(documentID: id, data: data) else {
            throw NSError(domain: "SpaceStoreError", code: 404, userInfo: [NSLocalizedDescriptionKey: "공간 데이터를 불러올 수 없습니다."])
        }
        return space
    }
}

private extension ListeningSpace {
    /// Firestore 문서를 ListeningSpace로 복원합니다.
    init?(documentID: String, data: [String: Any]) {
        let ownerId = data["ownerId"] as? String ?? documentID
        let owner = MonoUser(
            id: ownerId,
            displayName: data["ownerName"] as? String ?? "친구",
            handle: data["ownerHandle"] as? String ?? "",
            isFriend: true
        )

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

        let state = (data["playbackState"] as? String).flatMap(PlaybackState.init(rawValue:)) ?? .idle
        let visibility = (data["visibility"] as? String).flatMap(SpaceVisibility.init(rawValue:)) ?? .friends

        self.init(
            id: documentID,
            owner: owner,
            title: data["title"] as? String ?? "monosync space",
            stationDescription: data["stationDescription"] as? String ?? "환영합니다! 제가 좋아하는 음악들을 주로 듣는 공간이에요.",
            visibility: visibility,
            currentTrack: track,
            playbackState: state,
            playbackStartedAt: (data["startedAt"] as? Timestamp)?.dateValue(),
            positionAtAnchor: data["position"] as? TimeInterval ?? 0,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? .now,
            listenerCount: data["listenerCount"] as? Int ?? 0
        )
    }
}
#endif

/*
 Firestore 설계 메모:

 재생 위치(position)는 매초 쓰지 않습니다. PlaybackEvent(시작/일시정지/시크/정지)가
 바뀔 때만 startedAt 앵커와 함께 기록하고, 구독하는 클라이언트는
 ListeningSpace.currentPosition(now:)으로 현재 위치를 로컬 계산합니다.

 친구의 곡을 화면에 바로 보여주려고 트랙 메타데이터(title/artist/album/artwork/duration)를
 spaces 문서에 비정규화(denormalize)해 저장합니다.
 */
