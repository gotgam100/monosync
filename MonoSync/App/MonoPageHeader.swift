import SwiftUI

struct MonoPageHeader: View {
    let title: String
    let subtitle: String
    let onMenu: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Font.custom("Paperlogy-7Bold", size: 25))
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Font.custom("Paperlogy-4Regular", size: 11))
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }

            Spacer()

            MenuCircleButton(isActive: true, action: onMenu)
                .padding(.top, 6)
        }
        .frame(height: 46, alignment: .top)
    }
}
