import SwiftUI

struct RootView: View {
    @AppStorage("monoColorScheme") private var monoColorScheme = MonoColorScheme.dark.rawValue
    @State private var selectedSection = MonoSection.space
    @State private var isMenuOpen = false

    var body: some View {
        ZStack(alignment: .trailing) {
            content
                .disabled(isMenuOpen)

            if isMenuOpen {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = false
                        }
                    }

                SideMenuPanel(
                    selectedSection: selectedSection,
                    colorScheme: MonoColorScheme(rawValue: monoColorScheme) ?? .dark,
                    onSelectSection: { section in
                        selectedSection = section
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = false
                        }
                    },
                    onSelectScheme: { scheme in
                        monoColorScheme = scheme.rawValue
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isMenuOpen)
        .preferredColorScheme((MonoColorScheme(rawValue: monoColorScheme) ?? .dark).colorScheme)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .space:
            HomeView {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isMenuOpen = true
                }
            }
        case .friends:
            FriendsView {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isMenuOpen = true
                }
            }
        case .radio:
            RadioView {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isMenuOpen = true
                }
            }
        case .settings:
            MeView {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isMenuOpen = true
                }
            }
        }
    }
}

enum MonoSection: String, CaseIterable, Identifiable {
    case space
    case friends
    case radio
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .space: "플레이어"
        case .friends: "친구들"
        case .radio: "라디오"
        case .settings: "설정"
        }
    }

    var icon: String {
        switch self {
        case .space: "recordingtape"
        case .friends: "person.2"
        case .radio: "dot.radiowaves.left.and.right"
        case .settings: "gearshape"
        }
    }
}

enum MonoColorScheme: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "dark"
        case .light: "light"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }
}

struct MenuCircleButton: View {
    var isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MonoTheme.paper)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MonoTheme.paper.opacity(0.28), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(MonoTheme.accent)
                        .frame(width: 4, height: 4)
                        .offset(x: -4, y: 5)
                        .opacity(isActive ? 1 : 0.95)
                }
        }
        .accessibilityLabel("메뉴")
    }
}

private struct SideMenuPanel: View {
    let selectedSection: MonoSection
    let colorScheme: MonoColorScheme
    let onSelectSection: (MonoSection) -> Void
    let onSelectScheme: (MonoColorScheme) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 8) {
                ForEach(MonoSection.allCases) { section in
                    Button {
                        onSelectSection(section)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.icon)
                                .frame(width: 28)
                            Text(section.title)
                            Spacer()
                        }
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
                        .background(selectedSection == section ? MonoTheme.accent : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(MonoColorScheme.allCases) { scheme in
                    Button {
                        onSelectScheme(scheme)
                    } label: {
                        Text(scheme.title)
                            .font(MonoTheme.small)
                            .foregroundStyle(colorScheme == scheme ? Color.white : MonoTheme.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(colorScheme == scheme ? MonoTheme.accent : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(20)
        .padding(.vertical, 8)
        .frame(width: 254)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(MonoTheme.ink)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(MonoTheme.line)
                .frame(width: 1)
        }
    }
}
