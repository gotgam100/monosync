import SwiftUI

struct RadioView: View {
    let onMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonoPageHeader(title: "미니 라디오", subtitle: "작동 방식은 아직 실험 중", onMenu: onMenu)
                .padding(.top, 2)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    RadioModeRow(title: "공개 방송", subtitle: "가입자 모두에게 열리는 미니 스테이션", icon: "antenna.radiowaves.left.and.right")
                    RadioModeRow(title: "친구 방송", subtitle: "초대한 친구만 함께 듣는 방", icon: "person.2")
                    RadioModeRow(title: "예약 방송", subtitle: "정해둔 시간에 플레이리스트 시작", icon: "clock")
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MonoTheme.ink.ignoresSafeArea())
    }
}

private struct RadioModeRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(MonoTheme.paper)
                .frame(width: 42, height: 42)
                .background(MonoTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)
                Text(subtitle)
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
