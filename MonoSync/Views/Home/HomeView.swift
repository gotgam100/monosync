import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isShowingTrackSearch = false
    @State private var activeShelf: AppleMusicShelfKind?
    @State private var isShowingSpaceTools = false
    @State private var isShowingTapeCustomizer = false
    @State private var isShowingAppleMusicConnectPrompt = false
    @State private var pendingAppleMusicAction: AppleMusicRequiredAction?
    let onMenu: () -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width, 1)
                let availableHeight = max(proxy.size.height, 1)
                let isLandscape = availableWidth > availableHeight
                let compact = availableWidth < 380 || availableHeight < 760
                let topInset: CGFloat = 2
                
                // 가로 모드일 경우 버튼을 제거하므로 테이프 본체(637) 높이만을 기준으로 합니다.
                let cassetteHeightRatio = isLandscape ? (637.0 / 930.0) : (877.0 / 930.0)
                let cassetteSize = isLandscape ? (availableHeight * 0.95) / cassetteHeightRatio : availableWidth * 0.95
                let cassetteHeight = cassetteSize * cassetteHeightRatio
                let headerHeight: CGFloat = isLandscape ? 0 : (compact ? 40 : 46)
                let headerToCassette: CGFloat = isLandscape ? 0 : (compact ? 12 : 16)
                let cassetteToArtwork: CGFloat = isLandscape ? 0 : (compact ? 6 : 8)
                let cassetteLift: CGFloat = isLandscape ? 0 : (compact ? -25 : -12)
                
                let topRegionHeight = isLandscape ? 0 : max(140, (availableHeight
                    - topInset
                    - headerHeight
                    - headerToCassette
                    - cassetteHeight
                    - cassetteToArtwork
                    - cassetteLift) * 0.9)

                ZStack(alignment: .bottom) {
                    VStack(alignment: .center, spacing: headerToCassette) {
                        if !isLandscape {
                        HeaderView(
                            onSearch: {
                                runOrPromptForAppleMusic(.search)
                            },
                            onCustom: {
                                isShowingTapeCustomizer = true
                            },
                            onMenu: onMenu
                        )
                        .frame(height: headerHeight, alignment: .top)
                        .padding(.top, topInset)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onSwipeToChangeSection(current: .space) { next in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                appModel.selectedSection = next
                            }
                        }
                    }

                    NowPlayingPanel(
                        space: appModel.mySpace,
                        listenerSpaces: appModel.friendSpaces.filter { friendSpace in
                            guard friendSpace.isLive,
                                  let myTrack = appModel.mySpace.currentTrack,
                                  let friendTrack = friendSpace.currentTrack else {
                                return false
                            }
                            return friendTrack.matches(myTrack)
                        },
                        album: appModel.album(for: appModel.selectedCassetteSide),
                        cassetteSide: appModel.selectedCassetteSide,
                        isActiveSide: appModel.selectedCassetteSide == appModel.activeCassetteSide,
                        topRegionHeight: topRegionHeight,
                        cassetteSize: cassetteSize,
                        compact: compact,
                        isLandscape: isLandscape,
                        cassetteToArtwork: cassetteToArtwork,
                        statusText: appModel.musicStatusText,
                        isPlaying: appModel.isMusicPlaybackActive,
                        isAppleMusicConnected: appModel.isAppleMusicConnected,
                        pressedButtons: appModel.pressedCassetteButtons,
                        showsAlbumArt: appModel.showsAlbumArt,
                        drawerAlbums: appModel.drawerAlbums,
                        onConnectAppleMusic: {
                            Task { await appModel.connectAppleMusic() }
                        },
                        onAddAlbum: {
                            runOrPromptForAppleMusic(.search)
                        },
                        onDeleteAlbum: { album in
                            appModel.deleteDrawerAlbum(album)
                        },
                        onShowDrawer: {
                            appModel.prefersDrawerGrid = true
                        },
                        onInsertDroppedAlbum: { id in
                            Task { await appModel.insertDrawerAlbum(id: id, into: appModel.selectedCassetteSide) }
                        },
                        onCassetteSwipeUp: {
                            if appModel.selectedCassetteAlbum != nil {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                                    appModel.prefersDrawerGrid = true
                                    appModel.drawerFocusTrigger += 1
                                }
                            }
                        },
                        onBack: {
                            Task { await appModel.pressPreviousButton() }
                        },
                        onPlay: {
                            Task { await appModel.pressPlayButton() }
                        },
                        onPause: {
                            Task { await appModel.pressPauseButton() }
                        },
                        onNext: {
                            Task { await appModel.pressNextButton() }
                        },
                        onStop: {
                            if appModel.isCassetteTransportZero {
                                runOrPromptForAppleMusic(.search)
                            } else {
                                Task { await appModel.pressStopButton() }
                            }
                        },
                        onOpenTools: {
                            Task { await appModel.flipCassetteSide() }
                        }
                    )
                }
                .frame(width: availableWidth, height: availableHeight, alignment: .center)
                .clipped()
                
                // 딤 레이어 (조건문 제거하여 뒷배경 흔들림 방지)
                Color.black
                    .opacity(isShowingTrackSearch ? 0.4 : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.25), value: isShowingTrackSearch)
                    .allowsHitTesting(isShowingTrackSearch)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isShowingTrackSearch = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            appModel.drawerSnapTrigger += 1
                        }
                    }
                
                // 찾기 화면 (조건문 제거 및 오프셋 애니메이션으로 아래에서 부드럽게 전체화면으로 덮음)
                TrackSearchView(
                    isShowing: isShowingTrackSearch,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isShowingTrackSearch = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            appModel.drawerSnapTrigger += 1
                        }
                    },
                    onDone: {
                        appModel.prefersDrawerGrid = true
                    }
                )
                .offset(y: isShowingTrackSearch ? 0 : availableHeight + 100)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isShowingTrackSearch)
                .zIndex(10)
            } // ZStack 닫음
            } // GeometryReader 닫음
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .alert("Apple Music 연결 필요".localized(to: appModel.selectedLanguage), isPresented: $isShowingAppleMusicConnectPrompt) {
                Button("취소".localized(to: appModel.selectedLanguage), role: .cancel) {
                    pendingAppleMusicAction = nil
                }
                Button("연결".localized(to: appModel.selectedLanguage)) {
                    Task {
                        await appModel.connectAppleMusic()
                        if appModel.isAppleMusicConnected, let action = pendingAppleMusicAction {
                            performAppleMusicAction(action)
                        }
                        pendingAppleMusicAction = nil
                    }
                }
            } message: {
                Text("앨범 검색을 사용하려면 Apple Music 연결이 필요해요.".localized(to: appModel.selectedLanguage))
            }
            .sheet(item: $activeShelf) { shelf in
                AppleMusicShelfView(kind: shelf)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingSpaceTools) {
                SpaceToolsView(
                    onHistory: {
                        isShowingSpaceTools = false
                        activeShelf = .history
                        Task { await appModel.loadRecentlyPlayedTracks() }
                    }
                )
            }
            .sheet(isPresented: $isShowingTapeCustomizer) {
                TapeCustomizerView()
            }
        }
    }

    private func runOrPromptForAppleMusic(_ action: AppleMusicRequiredAction) {
        guard appModel.isAppleMusicConnected else {
            pendingAppleMusicAction = action
            isShowingAppleMusicConnectPrompt = true
            return
        }

        performAppleMusicAction(action)
    }

    private func performAppleMusicAction(_ action: AppleMusicRequiredAction) {
        switch action {
        case .search:
            isShowingTrackSearch = true
        }
    }
}

private enum AppleMusicRequiredAction {
    case search
}

private enum AppleMusicShelfKind: String, Identifiable {
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: "최근 기록"
        }
    }
}

private struct SpaceToolsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let onHistory: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ShelfButton(systemName: "clock.arrow.circlepath", action: onHistory)
                    }

                    ListenerStrip(spaces: appModel.friendSpaces.filter(\.isLive))
                    CommentPanel()
                }
                .padding(18)
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationTitle("스페이스")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(MonoTheme.paper)
                    }
                    .accessibilityLabel("닫기")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ShelfButton: View {
    let systemName: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(MonoTheme.paper)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isActive ? MonoTheme.accent : Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct AppleMusicShelfView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let kind: AppleMusicShelfKind

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Text(appModel.appleMusicShelfStatusText.localized(to: appModel.selectedLanguage))
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                    Spacer()
                    if appModel.isLoadingAppleMusicShelf {
                        ProgressView()
                            .tint(MonoTheme.accent)
                    }
                }

                switch kind {
                case .history:
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(appModel.recentlyPlayedTracks) { track in
                                TrackHistoryRow(
                                    track: track,
                                    onPlay: {
                                        dismiss()
                                        Task { await appModel.selectTrack(track) }
                                    },
                                    onAdd: {
                                        appModel.addTrackToSelectedMonoPlaylist(track)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationTitle(kind.title.localized(to: appModel.selectedLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(MonoTheme.bodyMedium)
                            .foregroundStyle(MonoTheme.paper)
                            .frame(width: 34, height: 34)
                    }
                    .accessibilityLabel("닫기")
                }
            }
        }
    }
}

private struct TrackHistoryRow: View {
    let track: TrackSnapshot
    let onPlay: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(url: track.artworkURL)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                Text("\(track.artistName) · \(track.albumTitle)")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Button(action: onAdd) {
                    Image(systemName: "text.badge.plus")
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("모노플리에 담기")

                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("재생")
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct HeaderView: View {
    let onSearch: () -> Void
    let onCustom: () -> Void
    let onMenu: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("monosync.")
                    .font(Font.custom("Paperlogy-7Bold", size: 25))
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                Text("share the tape")
                    .font(Font.custom("Paperlogy-4Regular", size: 11))
                    .foregroundStyle(MonoTheme.mist)
            }

            Spacer()

            HStack(spacing: 10) {
                HeaderCircleButton(systemName: "magnifyingglass", action: onSearch)
                    .accessibilityLabel("검색")
                HeaderCircleButton(systemName: "paintpalette", action: onCustom)
                    .accessibilityLabel("테이프 커스텀")
                MenuCircleButton(isActive: true, action: onMenu)
            }
            .padding(.top, 6)
        }
        .frame(height: 46, alignment: .top)
    }
}

private struct TapeCustomizerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("원하는 카세트 테이프 스타일을 선택해 주세요.")
                        .font(Font.custom("NotoSansKR-Regular", size: 14))
                        .foregroundStyle(MonoTheme.mist)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    ForEach(CassetteTapeStyle.allCases) { style in
                        Button {
                            appModel.selectedTapeStyle = style
                        } label: {
                            HStack(spacing: 16) {
                                TapeStyleThumbnail(style: style)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(style.name)
                                        .font(Font.custom("NotoSansKR-Bold", size: 15))
                                        .foregroundStyle(MonoTheme.paper)
                                    Text(style.description)
                                        .font(Font.custom("NotoSansKR-Regular", size: 12))
                                        .foregroundStyle(MonoTheme.mist)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(MonoTheme.accent)
                                    .font(.system(size: 20))
                                    .frame(width: 24, height: 24)
                                    .opacity(appModel.selectedTapeStyle == style ? 1 : 0)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(appModel.selectedTapeStyle == style ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(appModel.selectedTapeStyle == style ? MonoTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }
                }
                .padding(18)
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationTitle("테이프 커스텀")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(MonoTheme.paper)
                    }
                    .accessibilityLabel("닫기")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct TapeStyleThumbnail: View {
    let style: CassetteTapeStyle

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)

            if let uiImage = UIImage(named: style.rawValue) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 51)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 80, height: 55)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .drawingGroup()
    }
}

private struct HeaderCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MonoTheme.paper)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MonoTheme.paper.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private struct ListenerStrip: View {
    let spaces: [ListeningSpace]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("함께 듣는 친구")
                    .font(MonoTheme.pointSmall)
                    .foregroundStyle(MonoTheme.mist)
                Spacer()
                Text("\(spaces.reduce(0) { $0 + max($1.listenerCount, 0) })명")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.paper)
            }

            HStack(spacing: 8) {
                ForEach(spaces.prefix(4)) { space in
                    VStack(spacing: 5) {
                        Circle()
                            .fill(MonoTheme.panel)
                            .frame(width: 42, height: 42)
                            .overlay {
                                Text(String(space.owner.displayName.prefix(1)))
                                    .font(MonoTheme.bodyMedium)
                                    .foregroundStyle(MonoTheme.paper)
                            }
                            .overlay(Circle().stroke(MonoTheme.live, lineWidth: 1))
                        Text(space.owner.displayName)
                            .font(MonoTheme.small)
                            .foregroundStyle(MonoTheme.mist)
                            .lineLimit(1)
                    }
                    .frame(width: 58)
                }

                if spaces.isEmpty {
                    Text("아직 함께 듣는 친구가 없어요")
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                        .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CommentPanel: View {
    private let comments = [
        ("Rin", "이 곡 밤에 잘 어울린다"),
        ("Mono", "다음 곡도 이 무드로 가자")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("댓글")
                .font(MonoTheme.pointSmall)
                .foregroundStyle(MonoTheme.mist)

            ForEach(comments, id: \.0) { name, text in
                HStack(alignment: .top, spacing: 10) {
                    Text(name)
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 48, alignment: .leading)
                    Text(text)
                        .font(MonoTheme.body)
                        .foregroundStyle(MonoTheme.mist)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                Text("댓글 남기기")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MonoTheme.paper)
                    .frame(width: 30, height: 30)
                    .background(MonoTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(10)
            .background(MonoTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
