import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}
