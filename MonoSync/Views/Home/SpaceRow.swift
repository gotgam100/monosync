import SwiftUI

struct SpaceRow: View {
    let space: ListeningSpace

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(space.isLive ? MonoTheme.live : MonoTheme.mist.opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: space.isLive ? "waveform" : "moon")
                        .foregroundStyle(MonoTheme.paper)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(space.owner.displayName)
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                    if space.isLive {
                        Text("라이브")
                            .font(MonoTheme.pointSmall)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(MonoTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(space.currentTrack.map { "\($0.title) - \($0.artistName)" } ?? space.title)
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "play.fill")
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("같이 듣기")
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
