import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isMenuOpen = false

    var body: some View {
        ZStack(alignment: .trailing) {
            GeometryReader { proxy in
                let screenWidth = max(proxy.size.width, 1)
                
                HStack(spacing: 0) {
                    HomeView {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = true
                        }
                    }
                    .frame(width: screenWidth)
                    
                    MyStationView {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = true
                        }
                    }
                    .frame(width: screenWidth)
                    
                    YourStationView {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = true
                        }
                    }
                    .frame(width: screenWidth)
                    
                    MeView {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = true
                        }
                    }
                    .frame(width: screenWidth)
                }
                .offset(x: -CGFloat(indexOf(appModel.selectedSection)) * screenWidth)
            }
            .ignoresSafeArea()
            .disabled(isMenuOpen)

            if isMenuOpen {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            isMenuOpen = false
                        }
                    }

                VStack {
                    SideMenuPanel(
                        selectedSection: appModel.selectedSection,
                        onSelectSection: { section in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                appModel.selectedSection = section
                            }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isMenuOpen = false
                            }
                        }
                    )
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: appModel.selectedSection)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isMenuOpen)
        .preferredColorScheme(.dark)
        .task {
            appModel.startFriendSession()
            await appModel.checkAppleMusicSubscriptionAndAccess()
        }
        .onOpenURL { url in
            if url.scheme == "monosync" && url.host == "space",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let spaceId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                Task {
                    if let space = try? await appModel.spaceStore.fetchSpace(id: spaceId) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            appModel.selectedSection = .yourStation
                        }
                        appModel.yourStationNavigationPath.append(space)
                    }
                }
            } else {
                Task { await appModel.addFriend(from: url) }
            }
        }
        .alert("안내".localized(to: appModel.selectedLanguage), isPresented: Bindable(appModel).showSubscriptionAlert) {
            Button("확인".localized(to: appModel.selectedLanguage), role: .cancel) { }
        } message: {
            Text("애플뮤직 구독 후 사용할 수 있습니다.".localized(to: appModel.selectedLanguage))
        }
        .alert("안내".localized(to: appModel.selectedLanguage), isPresented: Bindable(appModel).showDeleteActiveAlbumAlert) {
            Button("확인".localized(to: appModel.selectedLanguage), role: .cancel) { }
        } message: {
            Text("현재 재생중입니다. 다른 테이프로 교체 후 진행해주세요.".localized(to: appModel.selectedLanguage))
        }
    }

    private func indexOf(_ section: MonoSection) -> Int {
        switch section {
        case .space: return 0
        case .myStation: return 1
        case .yourStation: return 2
        case .settings: return 3
        }
    }
}

enum MonoSection: String, CaseIterable, Identifiable {
    case space
    case myStation
    case yourStation
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .space: "플레이어"
        case .myStation: "마이스테이션"
        case .yourStation: "유어스테이션"
        case .settings: "설정"
        }
    }

    var icon: String {
        switch self {
        case .space: "recordingtape"
        case .myStation: "antenna.radiowaves.left.and.right"
        case .yourStation: "person.2"
        case .settings: "gearshape"
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
    @Environment(AppModel.self) private var appModel
    let selectedSection: MonoSection
    let onSelectSection: (MonoSection) -> Void

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
                            Text(section.title.localized(to: appModel.selectedLanguage))
                            Spacer()
                        }
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
                        .background(selectedSection == section ? MonoTheme.accent.opacity(0.92) : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(selectedSection == section ? 0.18 : 0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(16)
        .frame(width: 220)
        .background(.ultraThinMaterial.opacity(0.82))
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }
}

extension View {
    func onSwipeToChangeSection(current: MonoSection, action: @escaping (MonoSection) -> Void) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let thresh: CGFloat = 50
                    if value.translation.width < -thresh { // 왼쪽으로 쓸기 (오른쪽 탭으로 이동)
                        if let next = current.nextSection {
                            action(next)
                        }
                    } else if value.translation.width > thresh { // 오른쪽으로 쓸기 (왼쪽 탭으로 이동)
                        if let prev = current.prevSection {
                            action(prev)
                        }
                    }
                }
        )
    }
}

extension MonoSection {
    var nextSection: MonoSection? {
        switch self {
        case .space: return .myStation
        case .myStation: return .yourStation
        case .yourStation: return .settings
        case .settings: return nil
        }
    }
    
    var prevSection: MonoSection? {
        switch self {
        case .space: return nil
        case .myStation: return .space
        case .yourStation: return .myStation
        case .settings: return .yourStation
        }
    }
}
