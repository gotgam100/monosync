import SwiftUI

struct MeView: View {
    @Environment(AppModel.self) private var appModel
    let onMenu: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                MonoPageHeader(title: "설정", subtitle: appModel.currentUser.handle, onMenu: onMenu)
                    .padding(.top, 2)
                    .padding(.horizontal, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("언어")
                            .font(MonoTheme.pointSmall)
                            .foregroundStyle(MonoTheme.mist)
                        Picker("언어", selection: Bindable(appModel).selectedLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsGroup(title: "계정") {
                        SettingRow(title: "앱 정보", value: "MonoSync 0.1")
                        SettingRow(title: "친구 설정", value: "요청 허용")
                        SettingRow(title: "공개 범위", value: appModel.mySpace.visibility.koreanLabel)
                    }

                    SettingsGroup(title: "정책") {
                        SettingRow(title: "이용약관", value: "보기")
                        SettingRow(title: "개인정보 처리방침", value: "보기")
                        SettingRow(title: "오픈소스 라이선스", value: "보기")
                    }

                    Spacer(minLength: 20)
                }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(MonoTheme.ink.ignoresSafeArea())
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MonoTheme.pointSmall)
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
