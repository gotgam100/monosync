import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct MonoSyncApp: App {
    @State private var appModel = AppModel()

    init() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil,
           let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
    }
}
