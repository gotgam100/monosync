import Foundation

struct MonoUser: Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var handle: String
    var isFriend: Bool

    static let sampleMe = MonoUser(
        id: "user-me",
        displayName: "Baek",
        handle: "@mini.baek",
        isFriend: false
    )
}
