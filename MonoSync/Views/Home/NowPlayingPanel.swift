import SwiftUI
import UIKit

struct NowPlayingPanel: View {
    let space: ListeningSpace
    let listenerSpaces: [ListeningSpace]
    let album: AlbumSnapshot?
    let cassetteSide: CassetteSide
    let discSize: CGFloat
    let cassetteSize: CGFloat
    let compact: Bool
    let cassetteToArtwork: CGFloat
    let statusText: String
    let isPlaying: Bool
    let isAppleMusicConnected: Bool
    let pressedButtons: Set<CassetteTransportButton>
    let onConnectAppleMusic: () -> Void
    let onBack: () -> Void
    let onPlay: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onStop: () -> Void
    let onOpenTools: () -> Void

    var body: some View {
        let safeDiscSize = discSize.isFinite ? max(discSize, 96) : 140
        let safeCassetteSize = cassetteSize.isFinite ? max(cassetteSize, 220) : 280
        let safeCassetteHeight = safeCassetteSize * (787.0 / 930.0)

        VStack(alignment: .leading, spacing: 0) {
            CassetteDeckView(
                track: space.currentTrack,
                album: album,
                cassetteSide: cassetteSide,
                isPlaying: isPlaying,
                pressedButtons: pressedButtons,
                compact: compact,
                onBack: onBack,
                onPlay: onPlay,
                onPause: onPause,
                onNext: onNext,
                onStop: onStop,
                onOpenTools: onOpenTools
            )
            .frame(width: safeCassetteSize, height: safeCassetteHeight)
            .frame(maxWidth: .infinity)

            Spacer()
                .frame(height: cassetteToArtwork)

            PlayerArtworkView(
                track: space.currentTrack,
                album: album,
                listenerSpaces: listenerSpaces,
                isAppleMusicConnected: isAppleMusicConnected,
                onConnectAppleMusic: onConnectAppleMusic
            )
                .frame(width: safeDiscSize, height: safeDiscSize)
                .frame(maxWidth: .infinity)
                .frame(height: safeDiscSize)
                .padding(.horizontal, 16)

            if let album {
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                        .lineLimit(1)
                    Text(album.releaseYear ?? "연도 미상")
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                        .lineLimit(1)
                }
                .padding(.top, compact ? 8 : 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlayerArtworkView: View {
    let track: TrackSnapshot?
    let album: AlbumSnapshot?
    let listenerSpaces: [ListeningSpace]
    let isAppleMusicConnected: Bool
    let onConnectAppleMusic: () -> Void
    @State private var isShowingTrackList = false

    var body: some View {
        Group {
            if track == nil {
                AppleMusicArtworkConnectButton(
                    isConnected: isAppleMusicConnected,
                    action: onConnectAppleMusic
                )
            } else {
                AlbumArtworkView(url: track?.artworkURL, cornerRadius: 8)
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                ArtworkListenerStack(spaces: listenerSpaces)
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                if let album, !album.tracks.isEmpty {
                    Button {
                        isShowingTrackList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MonoTheme.paper)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("앨범 곡 목록")
                }
            }
            .sheet(isPresented: $isShowingTrackList) {
                AlbumTrackListSheet(album: album)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

private struct AlbumTrackListSheet: View {
    let album: AlbumSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array((album?.tracks ?? []).enumerated()), id: \.offset) { index, track in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(MonoTheme.small)
                                .foregroundStyle(MonoTheme.mist)
                                .frame(width: 26, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(MonoTheme.bodyMedium)
                                    .foregroundStyle(MonoTheme.paper)
                                    .lineLimit(1)
                                Text(track.artistName)
                                    .font(MonoTheme.small)
                                    .foregroundStyle(MonoTheme.mist)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(18)
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationTitle(album?.title ?? "곡 목록")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AppleMusicArtworkConnectButton: View {
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: isConnected ? "checkmark.circle.fill" : "music.note")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isConnected ? MonoTheme.live : MonoTheme.accent)

                Text(isConnected ? "Apple Music 연결됨" : "Apple Music 연결")
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)

                Text(isConnected ? "검색과 보관함을 사용할 수 있어요" : "탭해서 연동 상태 확인")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.045))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isConnected ? "Apple Music 연결됨" : "Apple Music 연결")
    }
}

private struct ArtworkListenerStack: View {
    let spaces: [ListeningSpace]

    private var visibleSpaces: [ListeningSpace] {
        Array(spaces.prefix(5))
    }

    private var extraCount: Int {
        max(0, spaces.count - visibleSpaces.count)
    }

    var body: some View {
        if !spaces.isEmpty {
            VStack(alignment: .trailing, spacing: 5) {
                ForEach(visibleSpaces) { space in
                    HStack(spacing: 5) {
                        Text(space.owner.displayName)
                            .font(Font.custom("Paperlogy-5Medium", size: 9))
                            .foregroundStyle(MonoTheme.paper)
                            .lineLimit(1)
                        Circle()
                            .fill(MonoTheme.live)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Text(String(space.owner.displayName.prefix(1)))
                                    .font(Font.custom("Paperlogy-7Bold", size: 8))
                                    .foregroundStyle(MonoTheme.paper)
                            }
                    }
                    .padding(.leading, 7)
                    .padding(.trailing, 4)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                if extraCount > 0 {
                    Text("...(\(extraCount)명)")
                        .font(Font.custom("Paperlogy-5Medium", size: 9))
                        .foregroundStyle(MonoTheme.paper)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// 나머지 ui: now playing 상태줄, 곡 제목/아티스트 별도 영역, 재생바는 현재 화면에서 제거하고 나중에 되살릴 수 있게 아래 보조 뷰들을 남겨둡니다.

private struct PlayerBackgroundView: View {
    let track: TrackSnapshot?

    var body: some View {
        ZStack {
            if let url = track?.artworkURL {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        MonoTheme.panel
                    }
                }
            } else {
                MonoTheme.panel
            }

            LinearGradient(
                colors: [
                    MonoTheme.ink.opacity(0.04),
                    MonoTheme.ink.opacity(0.34),
                    MonoTheme.ink.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct PlaybackProgress: View {
    let space: ListeningSpace

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = max(space.currentTrack?.duration ?? 1, 1)
            let position = min(space.currentPosition(now: context.date), duration)
            VStack(spacing: 6) {
                ProgressView(value: position, total: duration)
                    .tint(MonoTheme.accent)
                    .progressViewStyle(.linear)
                HStack {
                    Text(position.clockString)
                    Spacer()
                    Text(duration.clockString)
                }
                .font(MonoTheme.small)
                .foregroundStyle(MonoTheme.paper)
                .opacity(0)
                .frame(height: 0)
            }
        }
    }
}

private struct CassetteDeckView: View {
    let track: TrackSnapshot?
    let album: AlbumSnapshot?
    let cassetteSide: CassetteSide
    let isPlaying: Bool
    let pressedButtons: Set<CassetteTransportButton>
    let compact: Bool
    let onBack: () -> Void
    let onPlay: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onStop: () -> Void
    let onOpenTools: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let buttonRowWidth = width
            let buttonRowHeight = height * (165.0 / 787.0)
            let buttonRowCenterY = height * (704.5 / 787.0)

            ZStack {
                TapeImage()

                CassetteReelPair(isPlaying: isPlaying)
                    .allowsHitTesting(false)

                CassetteSideBadge(side: cassetteSide)
                    .frame(width: width * (80.0 / 930.0), height: width * (80.0 / 930.0))
                    .position(x: width * (146.0 / 930.0), y: height * (130.0 / 787.0))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                    Text(track?.title ?? "No Track")
                        .font(Font.custom("Cafe24PROSlimAir", size: compact ? 17 : 19))
                        .foregroundStyle(Color(hex: 0x25211B))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text(track?.artistName ?? "MonoSync")
                        .font(Font.custom("Cafe24PROSlimAir", size: compact ? 14 : 16))
                        .foregroundStyle(Color(hex: 0x25211B).opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .rotationEffect(.degrees(-2))
                .frame(width: width * 0.52, alignment: .leading)
                .position(x: width * 0.51, y: height * 0.165)

                VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                    Text(album?.title ?? "MonoSync")
                        .font(Font.custom("Paperlogy-7Bold", size: compact ? 14 : 16))
                        .foregroundStyle(MonoTheme.paper.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text(album?.releaseYear ?? "연도 미상")
                        .font(Font.custom("Paperlogy-5Medium", size: compact ? 9 : 10))
                        .foregroundStyle(MonoTheme.mist.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(width: width * (520.0 / 930.0), alignment: .leading)
                .position(x: width * (370.0 / 930.0), y: height * (486.0 / 787.0))
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    CassettePressZone(
                        action: onBack,
                        label: "이전 곡",
                        isLatched: pressedButtons.contains(.previous)
                    )
                    CassettePressZone(
                        action: onPlay,
                        label: "재생",
                        isLatched: pressedButtons.contains(.play)
                    )
                    CassettePressZone(
                        action: onPause,
                        label: "일시정지",
                        isLatched: pressedButtons.contains(.pause)
                    )
                    CassettePressZone(
                        action: onNext,
                        label: "다음 곡",
                        isLatched: pressedButtons.contains(.next)
                    )
                    CassettePressZone(
                        action: onStop,
                        label: "정지",
                        isLatched: pressedButtons.contains(.stop)
                    )
                }
                .frame(width: buttonRowWidth, height: buttonRowHeight)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .position(x: width * 0.5, y: buttonRowCenterY)

                CassettePressZone(action: onOpenTools)
                    .frame(width: width * 0.18, height: height * 0.13)
                    .position(x: width * 0.87, y: height * 0.62)
                    .accessibilityLabel("카세트 면 넘기기")
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }
}

private struct CassetteSideBadge: View {
    let side: CassetteSide

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: 0x171717))
            .overlay {
                Text(side == .a ? "A" : "B")
                    .font(Font.custom("Paperlogy-7Bold", size: 42))
                    .foregroundStyle(Color(hex: 0xD8D3C7))
                    .minimumScaleFactor(0.5)
            }
    }
}

private struct CassetteReelPair: View {
    let isPlaying: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let reelSize = width * (132.0 / 930.0)

            ZStack {
                RotatingReel(isPlaying: isPlaying)
                    .frame(width: reelSize, height: reelSize)
                    .position(x: width * (242.0 / 930.0), y: height * (320.0 / 787.0))

                RotatingReel(isPlaying: isPlaying)
                    .frame(width: reelSize, height: reelSize)
                    .position(x: width * (692.0 / 930.0), y: height * (320.0 / 787.0))
            }
        }
    }
}

private struct RotatingReel: View {
    let isPlaying: Bool
    private let degreesPerSecond = 360.0 / 2.1
    @State private var baseDegrees = 0.0
    @State private var playStartedAt: Date?

    var body: some View {
        TimelineView(.animation) { context in
            ReelImage()
                .rotationEffect(.degrees(currentDegrees(at: context.date)))
        }
            .onAppear {
                if isPlaying, playStartedAt == nil {
                    playStartedAt = .now
                }
            }
            .onChange(of: isPlaying) { _, newValue in
                let now = Date()
                if newValue {
                    playStartedAt = now
                } else {
                    baseDegrees = normalizedDegrees(currentDegrees(at: now))
                    playStartedAt = nil
                }
            }
    }

    private func currentDegrees(at date: Date) -> Double {
        guard isPlaying, let playStartedAt else {
            return baseDegrees
        }

        return baseDegrees + date.timeIntervalSince(playStartedAt) * degreesPerSecond
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }
}

private struct ReelImage: View {
    var body: some View {
        if let image = UIImage(named: "round") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Circle()
                .fill(Color.clear)
        }
    }
}

private struct TapeImage: View {
    var body: some View {
        if let image = UIImage(named: "tape_full") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: 0x101010))
                .overlay {
                    Text("tape")
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                }
        }
    }
}

private struct CassettePressZone: View {
    let action: () -> Void
    var label = "카세트 버튼"
    var isLatched = false

    var body: some View {
        Button {
            CassetteFeedbackPlayer.shared.impact()
            SoundEffectPlayer.shared.play(.button)
            action()
        } label: {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .overlay(alignment: .top) {
                    if isLatched {
                        Circle()
                            .fill(MonoTheme.accent)
                            .frame(width: 8, height: 8)
                            .padding(.top, 10)
                            .shadow(color: MonoTheme.accent.opacity(0.55), radius: 3)
                    }
                }
        }
        .buttonStyle(CassetteButtonStyle())
        .contentShape(Rectangle())
        .accessibilityLabel(label)
    }
}

@MainActor
private final class CassetteFeedbackPlayer {
    static let shared = CassetteFeedbackPlayer()

    private let generator = UIImpactFeedbackGenerator(style: .rigid)
    private var lastImpactAt = Date.distantPast

    private init() {
        generator.prepare()
    }

    func impact() {
        let now = Date()
        guard now.timeIntervalSince(lastImpactAt) > 0.08 else { return }
        lastImpactAt = now
        generator.impactOccurred(intensity: 0.9)
        generator.prepare()
    }
}

private struct CassetteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Rectangle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0))
            }
            .scaleEffect(y: configuration.isPressed ? 0.9 : 1, anchor: .bottom)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private extension TimeInterval {
    var clockString: String {
        let seconds = max(0, Int(self))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
