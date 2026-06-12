import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var appModel
    let onMenu: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                MonoPageHeader(title: "설정".localized(to: appModel.selectedLanguage), subtitle: "환경 설정".localized(to: appModel.selectedLanguage), onMenu: onMenu)
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("언어".localized(to: appModel.selectedLanguage))
                            .font(Font.custom("Paperlogy-7Bold", size: 14))
                            .foregroundStyle(MonoTheme.mist)
                        Picker("언어", selection: Bindable(appModel).selectedLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    ProfileSection()

                    SettingsGroup(title: "계정".localized(to: appModel.selectedLanguage)) {
                        SettingRow(title: "앱 정보".localized(to: appModel.selectedLanguage), value: "MonoSync 0.1")
                        SettingRow(title: "친구 설정".localized(to: appModel.selectedLanguage), value: "요청 허용".localized(to: appModel.selectedLanguage))
                        SettingRow(title: "공개 범위".localized(to: appModel.selectedLanguage), value: appModel.mySpace.visibility.koreanLabel.localized(to: appModel.selectedLanguage))
                    }

                    SettingsGroup(title: "정책".localized(to: appModel.selectedLanguage)) {
                        SettingRow(title: "이용약관".localized(to: appModel.selectedLanguage), value: "보기".localized(to: appModel.selectedLanguage))
                        SettingRow(title: "개인정보 처리방침".localized(to: appModel.selectedLanguage), value: "보기".localized(to: appModel.selectedLanguage))
                        SettingRow(title: "오픈소스 라이선스".localized(to: appModel.selectedLanguage), value: "보기".localized(to: appModel.selectedLanguage))
                    }

                    Spacer(minLength: 20)
                }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .contentShape(Rectangle())
            .onSwipeToChangeSection(current: .settings) { next in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    appModel.selectedSection = next
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
    }
}

private struct ProfileSection: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("프로필".localized(to: appModel.selectedLanguage))
                .font(Font.custom("Paperlogy-7Bold", size: 14))
                .foregroundStyle(MonoTheme.mist)

            VStack(alignment: .leading, spacing: 16) {
                // Nickname
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("닉네임".localized(to: appModel.selectedLanguage), text: Bindable(appModel).currentUser.displayName)
                            .font(MonoTheme.bodyMedium)
                            .foregroundStyle(MonoTheme.paper)
                            .onSubmit {
                                Task { await appModel.updateNickname(appModel.currentUser.displayName) }
                            }
                        
                        Button {
                            Task { await appModel.updateNickname(appModel.currentUser.displayName) }
                        } label: {
                            Text("저장".localized(to: appModel.selectedLanguage))
                                .font(MonoTheme.small)
                                .foregroundStyle(MonoTheme.accent)
                        }
                    }
                    Text("다른 친구들에게는 닉네임만 표시됩니다.".localized(to: appModel.selectedLanguage))
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                }

                Divider().background(Color.white.opacity(0.1))

                // Apple Music Status
                HStack {
                    Text("Apple Music 연동".localized(to: appModel.selectedLanguage))
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                    Spacer()
                    Text((appModel.isAppleMusicConnected ? "연결됨" : "연결 안됨").localized(to: appModel.selectedLanguage))
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(appModel.isAppleMusicConnected ? MonoTheme.accent : MonoTheme.mist)
                }

                if let invite = appModel.inviteURL {
                    Divider().background(Color.white.opacity(0.1))
                    
                    ShareLink(item: invite) {
                        Label("내 초대 링크 공유".localized(to: appModel.selectedLanguage), systemImage: "square.and.arrow.up")
                            .font(MonoTheme.body)
                            .foregroundStyle(MonoTheme.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MonoTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Font.custom("Paperlogy-7Bold", size: 14))
                .foregroundStyle(MonoTheme.mist)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SettingRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(MonoTheme.paper)
            Spacer()
            Text(value)
                .foregroundStyle(MonoTheme.mist)
        }
        .font(MonoTheme.body)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private extension SpaceVisibility {
    var koreanLabel: String {
        switch self {
        case .privateSpace: "나만 보기"
        case .friends: "친구 공개"
        case .link: "링크 공개"
        case .publicSpace: "모두 공개"
        }
    }
}
