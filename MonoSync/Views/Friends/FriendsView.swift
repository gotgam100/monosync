import SwiftUI

struct FriendsView: View {
    @Environment(AppModel.self) private var appModel
    let onMenu: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                MonoPageHeader(title: "친구들", subtitle: "누가 지금 듣고 있는지 한눈에 보기", onMenu: onMenu)
                    .padding(.top, 2)
                    .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(appModel.friendSpaces) { space in
                            FriendStatusRow(space: space)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
            .background(MonoTheme.ink.ignoresSafeArea())
        }
    }
}

private struct FriendStatusRow: View {
    @Environment(AppModel.self) private var appModel

    let space: ListeningSpace

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(space.isLive ? MonoTheme.live : MonoTheme.panel)
                .frame(width: 46, height: 46)
                .overlay {
                    Text(String(space.owner.displayName.prefix(1)))
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(space.owner.displayName)
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)

                    Text(space.isLive ? "듣는 중" : "오프라인")
                        .font(MonoTheme.pointSmall)
                        .foregroundStyle(space.isLive ? MonoTheme.live : MonoTheme.mist)
                }

                Text(space.currentTrack.map { "\($0.title) - \($0.artistName)" } ?? "지금 재생 중인 음악 없음")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if space.isLive {
                    Task { await appModel.join(space: space) }
                }
            } label: {
                Image(systemName: space.isLive ? "play.fill" : "bell")
                    .foregroundStyle(MonoTheme.paper)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel(space.isLive ? "같이 듣기" : "알림 받기")
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
