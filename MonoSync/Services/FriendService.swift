import Foundation

/// 사용자 프로필 + 친구 그래프 추상화.
/// 데이터 모델:
///   users/{uid}                     { displayName, handle, updatedAt }
///   users/{uid}/friends/{friendUid} { addedAt }
protocol FriendStoring: Sendable {
    /// 내 프로필을 생성/갱신합니다(로그인 직후 호출).
    func ensureProfile(uid: String, displayName: String, handle: String) async
    /// 특정 사용자의 프로필을 조회합니다.
    func profile(uid: String) async -> MonoUser?
    /// 친구를 추가합니다(단방향 팔로우).
    func addFriend(ownerUID: String, friendUID: String) async throws
    /// 친구 uid 목록 실시간 구독. 변경 시마다 전체 목록을 방출합니다.
    func observeFriendIDs(ownerUID: String) -> AsyncStream<[String]>
}

enum FriendError: LocalizedError {
    case unavailable
    case invalidInvite

    var errorDescription: String? {
        switch self {
        case .unavailable: "친구 기능을 사용할 수 없어요 (Firebase 미설정)"
        case .invalidInvite: "초대 링크를 알아볼 수 없어요"
        }
    }
}

/// monosync://add/<uid> 형태의 초대 링크 도우미.
enum FriendInvite {
    static let scheme = "monosync"
    static let host = "add"

    static func url(for uid: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(uid)"
        return components.url
    }

    /// 초대 링크에서 친구 uid를 추출합니다.
    static func uid(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let uid = url.lastPathComponent
        return uid.isEmpty || uid == "/" ? nil : uid
    }
}

/// Firebase가 없을 때의 폴백.
struct NoOpFriendStore: FriendStoring {
    func ensureProfile(uid: String, displayName: String, handle: String) async {}
    func profile(uid: String) async -> MonoUser? { nil }
    func addFriend(ownerUID: String, friendUID: String) async throws { throw FriendError.unavailable }
    func observeFriendIDs(ownerUID: String) -> AsyncStream<[String]> {
        AsyncStream { $0.finish() }
    }
}

#if canImport(FirebaseFirestore)
import FirebaseFirestore

final class FirestoreFriendStore: FriendStoring, @unchecked Sendable {
    private var db: Firestore { Firestore.firestore() }

    func ensureProfile(uid: String, displayName: String, handle: String) async {
        try? await db.collection("users").document(uid).setData([
            "displayName": displayName,
            "handle": handle,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func profile(uid: String) async -> MonoUser? {
        guard let data = try? await db.collection("users").document(uid).getDocument().data() else {
            return nil
        }
        return MonoUser(
            id: uid,
            displayName: data["displayName"] as? String ?? "친구",
            handle: data["handle"] as? String ?? "",
            isFriend: true
        )
    }

    func addFriend(ownerUID: String, friendUID: String) async throws {
        guard ownerUID != friendUID else { return }
        try await db.collection("users").document(ownerUID)
            .collection("friends").document(friendUID)
            .setData(["addedAt": FieldValue.serverTimestamp()], merge: true)
    }

    func observeFriendIDs(ownerUID: String) -> AsyncStream<[String]> {
        AsyncStream { continuation in
            let listener = db.collection("users").document(ownerUID)
                .collection("friends")
                .addSnapshotListener { snapshot, _ in
                    continuation.yield(snapshot?.documents.map { $0.documentID } ?? [])
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
#endif
