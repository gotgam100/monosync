import SwiftUI
@available(iOS 17.0, *)
struct TestView: View {
    var body: some View {
        ScrollView {
            HStack { Text("A") }
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }
}
