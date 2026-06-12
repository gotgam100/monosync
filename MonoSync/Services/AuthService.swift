import Foundation

/// 로그인된 사용자 신원. Firebase uid가 핵심 식별자입니다.
struct AuthedUser: Sendable, Equatable {
    let uid: String
    var displayName: String?
    var email: String?
}

enum AuthError: LocalizedError {
    case unavailable
    case missingToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable: "로그인 기능을 사용할 수 없어요 (Firebase 미설정)"
        case .missingToken: "Apple 토큰을 받지 못했어요"
        case .cancelled: "로그인이 취소됐어요"
        }
    }
}

/// 인증 추상화. AppModel은 이 프로토콜만 알고, 실제 구현(Firebase)은 가려져 있습니다.
protocol AuthProviding: Sendable {
    var currentUID: String? { get }
    /// 로그인 상태 변화 스트림(로그인/로그아웃). 시작 시 현재 상태를 즉시 1회 방출합니다.
    func authStateChanges() -> AsyncStream<AuthedUser?>
    /// Sign in with Apple로 로그인. 성공 시 AuthedUser 반환.
    @discardableResult
    func signInWithApple() async throws -> AuthedUser
    func signOut() throws
}

/// Firebase가 아직 프로젝트에 없을 때의 폴백. 항상 비로그인 상태로 동작합니다.
struct NoOpAuthProvider: AuthProviding {
    var currentUID: String? { nil }

    func authStateChanges() -> AsyncStream<AuthedUser?> {
        AsyncStream { continuation in
            continuation.yield(nil)
            continuation.finish()
        }
    }

    func signInWithApple() async throws -> AuthedUser {
        throw AuthError.unavailable
    }

    func signOut() throws {}
}

#if canImport(FirebaseAuth)
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import UIKit

/// Sign in with Apple → Firebase Auth 연동 구현.
final class FirebaseAuthProvider: NSObject, AuthProviding, @unchecked Sendable {
    var currentUID: String? { Auth.auth().currentUser?.uid }

    func authStateChanges() -> AsyncStream<AuthedUser?> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                if let user {
                    continuation.yield(AuthedUser(uid: user.uid, displayName: user.displayName, email: user.email))
                } else {
                    continuation.yield(nil)
                }
            }
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    private var currentNonce: String?
    private var continuation: CheckedContinuation<AuthedUser, Error>?

    @MainActor
    func signInWithApple() async throws -> AuthedUser {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Nonce helpers (Firebase 공식 가이드)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension FirebaseAuthProvider: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithAuthorization authorization: ASAuthorization) {
        let cont = continuation
        continuation = nil

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = appleIDCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            cont?.resume(throwing: AuthError.missingToken)
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Auth.auth().signIn(with: credential) { result, error in
            if let error {
                cont?.resume(throwing: error)
            } else if let user = result?.user {
                let name = appleIDCredential.fullName?.formatted() ?? user.displayName
                cont?.resume(returning: AuthedUser(uid: user.uid, displayName: name, email: user.email))
            } else {
                cont?.resume(throwing: AuthError.missingToken)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithError error: Error) {
        let cont = continuation
        continuation = nil
        if (error as? ASAuthorizationError)?.code == .canceled {
            cont?.resume(throwing: AuthError.cancelled)
        } else {
            cont?.resume(throwing: error)
        }
    }
}

extension FirebaseAuthProvider: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
#endif
