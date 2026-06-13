import SwiftUI
import UIKit

struct NowPlayingPanel: View {
    let space: ListeningSpace
    let listenerSpaces: [ListeningSpace]
    let album: AlbumSnapshot?
    let cassetteSide: CassetteSide
    let isActiveSide: Bool
    let topRegionHeight: CGFloat
    let cassetteSize: CGFloat
    let compact: Bool
    let isLandscape: Bool
    let cassetteToArtwork: CGFloat
    let statusText: String
    let isPlaying: Bool
    let isAppleMusicConnected: Bool
    let pressedButtons: Set<CassetteTransportButton>
    // 서랍(인라인) 관련
    let showsAlbumArt: Bool
    let drawerAlbums: [AlbumSnapshot]
    let onConnectAppleMusic: () -> Void
    let onAddAlbum: () -> Void
    let onDeleteAlbum: (AlbumSnapshot) -> Void
    let onShowDrawer: () -> Void
    let onInsertDroppedAlbum: (String) -> Void
    let onCassetteSwipeUp: () -> Void
    let onBack: () -> Void
    let onPlay: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onStop: () -> Void
    let onOpenTools: () -> Void

    var body: some View {
        let safeTopHeight = topRegionHeight.isFinite ? max(topRegionHeight, 120) : 200
        let safeCassetteSize = cassetteSize.isFinite ? max(cassetteSize, 220) : 280
        // 가로 모드일 경우 테이프 본체 비율(637/930), 세로일 경우 전체 비율(877/930) 적용
        let heightRatio = isLandscape ? (637.0 / 930.0) : (877.0 / 930.0)
        let safeCassetteHeight = safeCassetteSize * heightRatio

        VStack(alignment: .center, spacing: 0) {
            // ── 상단: 서랍 그리드 ↔ 앨범아트 ──
            if topRegionHeight > 0 {
                ZStack(alignment: .top) {
                    DrawerStackView(
                        albums: drawerAlbums,
                        activeAlbumID: album?.id,
                        isPlaying: isPlaying,
                        onAddAlbum: onAddAlbum,
                        onDeleteAlbum: onDeleteAlbum,
                        onInsertAlbum: { album in onInsertDroppedAlbum(album.id) }
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: safeTopHeight)
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: showsAlbumArt)

                Spacer()
                    .frame(height: cassetteToArtwork)
            } else {
                Spacer()
            }

            CassetteDeckView(
                track: space.currentTrack,
                album: album,
                cassetteSide: cassetteSide,
                isPlaying: isPlaying,
                pressedButtons: pressedButtons,
                compact: compact,
                isLandscape: isLandscape,
                onBack: onBack,
                onPlay: onPlay,
                onPause: onPause,
                onNext: onNext,
                onStop: onStop,
                onOpenTools: onOpenTools,
                onSwipeUp: onCassetteSwipeUp
            )
            .frame(width: safeCassetteSize, height: safeCassetteHeight)
            .frame(maxWidth: .infinity)
            // 서랍 카드를 끌어와 떨어뜨리면 현재 선택된 면에 삽입.
            .dropDestination(for: String.self) { items, _ in
                guard let id = items.first else { return false }
                onInsertDroppedAlbum(id)
                return true
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlayerArtworkView: View {
    let track: TrackSnapshot?
    let album: AlbumSnapshot?
    let isActiveSide: Bool
    let listenerSpaces: [ListeningSpace]
    let isAppleMusicConnected: Bool
    let onConnectAppleMusic: () -> Void
    let onShowDrawer: () -> Void
    @State private var isShowingAlbumInfo = false
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            let artworkURL = isActiveSide ? (track?.artworkURL ?? album?.artworkURL) : album?.artworkURL
            if let artworkURL {
                // 영역 전체를 앨범이미지로 채움(서랍 창 전체가 앨범이미지가 되는 효과).
                ReliableAsyncImage(url: artworkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    MonoTheme.panel.overlay { ProgressView().tint(MonoTheme.accent) }
                }
                .overlay(alignment: .topTrailing) {
                    if album != nil {
                        Button {
                            isShowingAlbumInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MonoTheme.paper)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel("앨범 정보")
                    }
                }
            } else {
                AppleMusicArtworkConnectButton(
                    isConnected: isAppleMusicConnected,
                    action: onConnectAppleMusic
                )
            }
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                // 아래로 스와이프해 서랍으로 돌아갈 수 있음을 알리는 핸들.
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .padding(.top, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                ArtworkListenerStack(spaces: listenerSpaces)
                    .padding(8)
            }
            .contentShape(Rectangle())
            // 아래로 스와이프 → 서랍 그리드로 복귀.
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.height > 44,
                           value.translation.height > abs(value.translation.width) {
                            onShowDrawer()
                        }
                    }
            )
            .sheet(isPresented: $isShowingAlbumInfo) {
                if let album {
                    AlbumInfoSheetView(album: album)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
    }
}

private struct AlbumTrackListSheet: View {
    let album: AlbumSnapshot?
    let currentTrack: TrackSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array((album?.tracks ?? []).enumerated()), id: \.offset) { index, track in
                        let isCurrentTrack = currentTrack.map { track.matches($0) } ?? false

                        HStack(spacing: 10) {
                            ZStack {
                                if isCurrentTrack {
                                    Circle()
                                        .fill(MonoTheme.accent)
                                        .frame(width: 22, height: 22)
                                }
                                Text("\(index + 1)")
                                    .font(MonoTheme.small)
                                    .foregroundStyle(isCurrentTrack ? MonoTheme.paper : MonoTheme.mist)
                                    .frame(width: 26, alignment: .center)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(MonoTheme.bodyMedium)
                                    .foregroundStyle(isCurrentTrack ? MonoTheme.accent : MonoTheme.paper)
                                    .lineLimit(1)
                                Text(track.artistName)
                                    .font(MonoTheme.small)
                                    .foregroundStyle(isCurrentTrack ? MonoTheme.paper.opacity(0.9) : MonoTheme.mist)
                                    .lineLimit(1)
                            }
                            Spacer()

                            if isCurrentTrack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(MonoTheme.accent)
                            }
                        }
                        .padding(12)
                        .background(isCurrentTrack ? MonoTheme.accent.opacity(0.16) : Color.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isCurrentTrack ? MonoTheme.accent.opacity(0.55) : Color.clear, lineWidth: 1)
                        }
                    }
                }
                .padding(18)
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(album?.title ?? "곡 목록")
                            .font(Font.custom("NotoSansKR-Medium", size: 16))
                            .foregroundStyle(MonoTheme.paper)
                        
                        if let releaseYear = album?.releaseYear {
                            Text(releaseYear)
                                .font(Font.custom("NotoSansKR-Regular", size: 12))
                                .foregroundStyle(MonoTheme.mist)
                        }
                    }
                }
            }
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
                ReliableAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } placeholder: {
                    MonoTheme.panel
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
    let isLandscape: Bool
    let onBack: () -> Void
    let onPlay: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onStop: () -> Void
    let onOpenTools: () -> Void
    let onSwipeUp: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var slideOffset: CGFloat = 0
    @State private var isSlidingSide = false

    private var albumDetailText: String {
        guard let album else { return "-" }
        return album.isPlaylistAlbum ? album.primaryDetailText : (album.releaseYear ?? "연도 미상")
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            // 가로 모드일 땐 버튼을 숨기므로 카세트 본체(637) 비율만 차지, 세로일 땐 버튼(240) 포함(877)
            let cassetteHeight = isLandscape ? height : height * (637.0 / 877.0)
            // Button_N5(930×552). 본체 전체 높이(나머지는 덱 프레임 아래로 흘러갑니다).
            let buttonStripHeight = width * (552.0 / 930.0)
            let baseWidth: CGFloat = 370.0
            let scale = width / baseWidth
            
            let transportButtons: [(label: String, action: () -> Void, isLatched: Bool, sound: SoundEffectPlayer.Effect)] = [
                ("이전 곡", onBack, pressedButtons.contains(.previous), .button),
                ("재생", onPlay, pressedButtons.contains(.play), .button),
                ("일시정지", onPause, pressedButtons.contains(.pause), .button),
                ("다음 곡", onNext, pressedButtons.contains(.next), .button),
                ("정지", onStop, pressedButtons.contains(.stop), pressedButtons.isEmpty ? .open : .button),
            ]

            ZStack(alignment: .top) {
                // ── 카세트 본체 (tape_N2) ──
                ZStack {
                    TapeImage()
                        .frame(width: width, height: cassetteHeight)

                    CassetteReelPair(isPlaying: isPlaying)
                        .allowsHitTesting(false)

                    CassetteSideBadge(side: cassetteSide)
                        .frame(width: width * (72.0 / 930.0), height: cassetteHeight * (62.0 / 637.0))
                        .position(x: width * (116.0 / 930.0) - 2, y: cassetteHeight * (261.0 / 637.0) - 3)
                        .allowsHitTesting(false)

                    let artistName = track?.artistName ?? "-"
                    VStack(alignment: .center, spacing: 2 * scale) {
                        CassetteHandwrittenText(
                            text: track?.title ?? "No Track",
                            size: 19 * scale,
                            isTitle: true,
                            color: Color(hex: 0x25211B),
                            minimumScaleFactor: 0.68
                        )

                        CassetteHandwrittenText(
                            text: artistName,
                            size: 16 * scale,
                            isTitle: false,
                            color: Color(hex: 0x25211B).opacity(0.8),
                            minimumScaleFactor: 0.7,
                            koreanSizeBoost: 2
                        )
                            .offset(y: -2 * scale + (artistName.containsHangul ? 2 : 3))
                    }
                    .frame(width: width * 0.52, alignment: .center)
                    .multilineTextAlignment(.center)
                    .position(x: width * 0.51, y: cassetteHeight * (130.0 / 637.0))

                    VStack(alignment: .leading, spacing: 2 * scale) {
                        Text(album?.title ?? "No Album")
                            .font(Font.custom("Paperlogy-7Bold", size: 11 * scale))
                            .foregroundStyle(Color(hex: 0x25211B))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)

                        Text(albumDetailText)
                            .font(Font.custom("Paperlogy-5Medium", size: 8 * scale))
                            .foregroundStyle(Color(hex: 0x25211B).opacity(0.65))
                            .lineLimit(1)
                    }
                    // 하단 크림 스트라이프(파란네모 위치). 좌측 장식선 오른쪽에서 좌측정렬 시작.
                    .frame(width: width * (470.0 / 930.0), alignment: .leading)
                    .position(x: width * (445.0 / 930.0), y: cassetteHeight * (434.0 / 637.0))
                    .allowsHitTesting(false)
                }
                .frame(width: width, height: cassetteHeight)
                .clipped()
                .offset(x: slideOffset + dragOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard !isSlidingSide else { return }
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            guard abs(horizontal) > abs(vertical) * 1.15 else { return }
                            dragOffset = horizontal
                        }
                        .onEnded { value in
                            guard !isSlidingSide else { return }
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            // 위로 스와이프 → 서랍 그리드를 앨범아트로 전환.
                            if vertical < -44, abs(vertical) > abs(horizontal) * 1.25 {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                    dragOffset = 0
                                }
                                onSwipeUp()
                                return
                            }
                            let threshold = max(width * 0.38, 120)
                            guard abs(horizontal) > threshold, abs(horizontal) > abs(vertical) * 1.25 else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                    dragOffset = 0
                                }
                                return
                            }
                            slideToNextSide(width: width, direction: horizontal < 0 ? -1 : 1)
                        }
                )

                // ── 버튼 스트립 (Button_N5) ──
                // 정적 베이스(테두리·여백·하단 본체)를 깔고, 그 위에 각 버튼 "면"만
                // 점선 박스 좌표에 정확히 맞춰 올립니다. 눌리면 면만 박스 안에서 내려갑니다.
                if !isLandscape {
                    ZStack(alignment: .topLeading) {
                        ButtonStripImage()
                            .frame(width: width, height: buttonStripHeight)
                            .allowsHitTesting(false)

                        ForEach(Array(transportButtons.enumerated()), id: \.offset) { index, button in
                            let box = CassetteButtonGeometry.boxes[index]
                            CassetteButtonFace(
                                stripWidth: width,
                                stripHeight: buttonStripHeight,
                                box: box,
                                isLatched: button.isLatched,
                                action: button.action,
                                label: button.label,
                                soundEffect: button.sound
                            )
                        }
                    }
                    .frame(width: width, height: buttonStripHeight, alignment: .topLeading)
                    .offset(y: cassetteHeight)
                }
            }
            // ZStack을 덱 전체 높이로 채워, 아래로 내려간 버튼 키도 터치 영역 안에 들어오게 합니다.
            .frame(width: width, height: height, alignment: .top)
            .contentShape(Rectangle())
        }
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }

    private func slideToNextSide(width: CGFloat, direction: CGFloat) {
        guard !isSlidingSide else { return }
        isSlidingSide = true
        SoundEffectPlayer.shared.play(.insert)

        withAnimation(.easeInOut(duration: 0.18)) {
            dragOffset = 0
            slideOffset = direction * width
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            onOpenTools()
            slideOffset = -direction * width
            withAnimation(.easeOut(duration: 0.22)) {
                slideOffset = 0
            }
            try? await Task.sleep(for: .milliseconds(220))
            isSlidingSide = false
        }
    }
}

private struct CassetteHandwrittenText: View {
    let text: String
    let size: CGFloat
    let isTitle: Bool
    let color: Color
    let minimumScaleFactor: CGFloat
    var koreanSizeBoost: CGFloat = 0

    @ViewBuilder
    var body: some View {
        if isTitle {
            ZStack {
                styledText
                styledText.offset(x: boldOffset)
                styledText.offset(y: boldOffset)
            }
        } else {
            styledText
        }
    }

    private var styledText: some View {
        renderedText
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
    }

    private var boldOffset: CGFloat {
        max(0.32, size * 0.018)
    }

    private var renderedText: Text {
        scriptRuns.reduce(Text("")) { partial, run in
            let boostedSize = run.isKorean ? (size + koreanSizeBoost) : size
            let tracking: CGFloat = run.isKorean ? 1.2 : 0
            return partial + Text(run.text)
                .font(font(forKorean: run.isKorean, size: boostedSize))
                .tracking(tracking)
        }
    }

    private var scriptRuns: [(text: String, isKorean: Bool)] {
        var runs: [(String, Bool)] = []
        var current = ""
        var currentIsKorean = false
        var hasCurrentScript = false

        for character in text {
            let characterIsKorean = character.containsHangul
            let characterHasScript = character.isScriptCharacter
            let nextIsKorean = characterHasScript ? characterIsKorean : currentIsKorean

            if hasCurrentScript, characterHasScript, nextIsKorean != currentIsKorean {
                runs.append((current, currentIsKorean))
                current = ""
            }

            current.append(character)
            if characterHasScript {
                currentIsKorean = nextIsKorean
                hasCurrentScript = true
            }
        }

        if !current.isEmpty {
            runs.append((current, currentIsKorean))
        }

        return runs
    }

    private func font(forKorean isKorean: Bool, size: CGFloat) -> Font {
        let fontName = isKorean ? "NanumGangBuJangNimCe" : "UwU-Regular"
        return Font.custom(fontName, size: size)
    }
}

private extension String {
    var containsHangul: Bool {
        contains { $0.containsHangul }
    }
}

private extension Character {
    var containsHangul: Bool {
        unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(Int(scalar.value)) ||
            (0x1100...0x11FF).contains(Int(scalar.value)) ||
            (0x3130...0x318F).contains(Int(scalar.value)) ||
            (0xA960...0xA97F).contains(Int(scalar.value)) ||
            (0xD7B0...0xD7FF).contains(Int(scalar.value))
        }
    }

    var isScriptCharacter: Bool {
        unicodeScalars.contains { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) }
    }
}

private struct CassetteSideBadge: View {
    let side: CassetteSide

    var body: some View {
        // 검은 배경 없이 글자만. TYPE I 박스(노란점 위치) 안에 들어갑니다.
        Text(side == .a ? "A" : "B")
            .font(Font.custom("Paperlogy-7Bold", size: 34))
            .foregroundStyle(Color(hex: 0xD8D3C7))
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CassetteReelPair: View {
    let isPlaying: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let reelSize = width * (132.0 / 930.0)

            // tape_N2(930x637)의 두 릴 구멍 중심(측정값).
            ZStack {
                RotatingReel(isPlaying: isPlaying)
                    .frame(width: reelSize, height: reelSize)
                    .position(x: width * (237.0 / 930.0) + 5 + 2 - 1, y: height * (303.0 / 637.0) - 7 - 2)

                RotatingReel(isPlaying: isPlaying)
                    .frame(width: reelSize, height: reelSize)
                    .position(x: width * (679.0 / 930.0) - 3 - 2 + 1, y: height * (303.0 / 637.0) - 7 - 2)
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
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let image = UIImage(named: appModel.selectedTapeStyle.rawValue) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
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

private struct ButtonStripImage: View {
    var body: some View {
        if let image = UIImage(named: "Button_N5") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle().fill(Color.black)
        }
    }
}

/// Button_N5(930×552) 위 빨간 점선으로 표시된 버튼 박스 좌표(픽셀 단위).
/// 면 세로: 상단 점선 y=22, 하단 점선 y=240.  좌우 경계: 34/210/387/561/735/909.
private enum CassetteButtonGeometry {
    static let imageWidthPx: CGFloat = 930
    static let faceTopPx: CGFloat = 22       // 버튼 면 상단 점선
    static let faceBottomPx: CGFloat = 240   // 버튼 면 하단 점선
    static var faceHeightPx: CGFloat { faceBottomPx - faceTopPx }  // 218

    struct Box { let leftPx: CGFloat; let rightPx: CGFloat }

    static let boxes: [Box] = [
        .init(leftPx: 34,  rightPx: 210),   // 이전 곡
        .init(leftPx: 210, rightPx: 387),   // 재생
        .init(leftPx: 387, rightPx: 561),   // 일시정지
        .init(leftPx: 561, rightPx: 735),   // 다음 곡
        .init(leftPx: 735, rightPx: 909),   // 정지
    ]
}

/// 버튼 한 칸의 "면"만 렌더링·이동. 점선 박스 좌표에 정확히 맞춰 위치하고,
/// 누르면 면만 박스 안에서 아래로 내려갑니다(주변 테두리·여백은 정적 베이스가 담당).
private struct CassetteButtonFace: View {
    let stripWidth: CGFloat   // 버튼 이미지를 그릴 폭(=930px에 대응)
    let stripHeight: CGFloat
    let box: CassetteButtonGeometry.Box
    let isLatched: Bool
    let action: () -> Void
    let label: String
    let soundEffect: SoundEffectPlayer.Effect

    var body: some View {
        let s = stripWidth / CassetteButtonGeometry.imageWidthPx  // px → pt 스케일
        let boxLeft = box.leftPx * s
        let boxWidth = (box.rightPx - box.leftPx) * s
        let faceTop = CassetteButtonGeometry.faceTopPx * s
        let faceHeight = CassetteButtonGeometry.faceHeightPx * s

        Button {
            CassetteFeedbackPlayer.shared.impact()
            SoundEffectPlayer.shared.play(soundEffect)
            action()
        } label: {
            Rectangle()
                .fill(Color.white.opacity(0.001))  // 확실히 hit-test 되는 투명 면
                .frame(width: boxWidth, height: faceHeight)
        }
        .buttonStyle(CassetteFaceStyle(
            stripWidth: stripWidth,
            stripHeight: stripHeight,
            boxLeft: boxLeft,
            boxWidth: boxWidth,
            faceTop: faceTop,
            faceHeight: faceHeight,
            isLatched: isLatched
        ))
        // 박스 좌상단을 스트립 좌상단 기준으로 정확히 배치.
        .frame(width: boxWidth, height: faceHeight, alignment: .topLeading)
        .position(x: boxLeft + boxWidth / 2, y: faceTop + faceHeight / 2)
        .accessibilityLabel(label)
    }
}

private struct CassetteFaceStyle: ButtonStyle {
    let stripWidth: CGFloat
    let stripHeight: CGFloat
    let boxLeft: CGFloat
    let boxWidth: CGFloat
    let faceTop: CGFloat
    let faceHeight: CGFloat
    let isLatched: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressDepth = faceHeight * 0.12  // 면 높이의 12%만큼 내려감
        let isDown = isLatched || configuration.isPressed
        let yShift = isDown ? pressDepth : 0

        ZStack(alignment: .topLeading) {
            // 버튼 면 슬라이스: 전체 이미지를 박스 좌상단으로 끌어와 박스 크기로 잘라냄.
            // 누르면 yShift 만큼 아래로 → 위쪽에 어두운 틈이 생겨 "눌려 들어간" 모습.
            ButtonStripImage()
                .frame(width: stripWidth, height: stripHeight)
                .offset(x: -boxLeft, y: -faceTop + yShift)
                .frame(width: boxWidth, height: faceHeight, alignment: .topLeading)
                .clipped()
                .allowsHitTesting(false)

            // 눌린 상태 음영(면 위에만).
            Rectangle()
                .fill(Color.black.opacity(isDown ? 0.18 : 0))
                .frame(width: boxWidth, height: faceHeight)
                .allowsHitTesting(false)

            configuration.label
        }
        .frame(width: boxWidth, height: faceHeight, alignment: .topLeading)
        .animation(.easeOut(duration: 0.08), value: isDown)
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

private extension TimeInterval {
    var clockString: String {
        let seconds = max(0, Int(self))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
