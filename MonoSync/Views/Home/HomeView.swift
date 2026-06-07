import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isShowingTrackSearch = false
    @State private var activeShelf: AppleMusicShelfKind?
    @State private var isShowingSpaceTools = false
    @State private var isShowingAppleMusicConnectPrompt = false
    @State private var pendingAppleMusicAction: AppleMusicRequiredAction?
    let onMenu: () -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width, 1)
                let availableHeight = max(proxy.size.height, 1)
                let compact = availableWidth < 380 || availableHeight < 760
                let topInset: CGFloat = 2
                let cassetteSize = availableWidth
                let cassetteHeight = cassetteSize * (787.0 / 930.0)
                let headerHeight: CGFloat = compact ? 40 : 46
                let headerToCassette: CGFloat = compact ? 12 : 16
                let cassetteToArtwork: CGFloat = compact ? 6 : 8
                let availableForDisc = availableHeight
                    - topInset
                    - headerHeight
                    - headerToCassette
                    - cassetteHeight
                    - cassetteToArtwork
                let discSize = min(
                    availableWidth - 32,
                    max(availableForDisc, compact ? 148 : 172)
                )

                VStack(alignment: .leading, spacing: headerToCassette) {
                    HeaderView(
                        onSearch: {
                            runOrPromptForAppleMusic(.search)
                        },
                        onPlaylists: {
                            runOrPromptForAppleMusic(.playlists)
                        },
                        onDrawer: {
                            activeShelf = .drawer
                        },
                        onMenu: onMenu
                    )
                    .frame(height: headerHeight, alignment: .top)
                    .padding(.top, topInset)
                    .padding(.horizontal, 16)

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
                        album: appModel.album(for: appModel.activeCassetteSide ?? appModel.selectedCassetteSide),
                        cassetteSide: appModel.activeCassetteSide ?? appModel.selectedCassetteSide,
                        discSize: max(discSize, compact ? 148 : 172),
                        cassetteSize: cassetteSize,
                        compact: compact,
                        cassetteToArtwork: cassetteToArtwork,
                        statusText: appModel.musicStatusText,
                        isPlaying: appModel.isMusicPlaybackActive,
                        isAppleMusicConnected: appModel.isAppleMusicConnected,
                        pressedButtons: appModel.pressedCassetteButtons,
                        onConnectAppleMusic: {
                            Task { await appModel.connectAppleMusic() }
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
                                activeShelf = .drawer
                            } else {
                                Task { await appModel.pressStopButton() }
                            }
                        },
                        onOpenTools: {
                            appModel.flipCassetteSide()
                        }
                    )
                }
                .frame(width: availableWidth, height: availableHeight, alignment: .top)
                .clipped()
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .toolbarBackground(MonoTheme.ink, for: .navigationBar)
            .alert("Apple Music 연결 필요", isPresented: $isShowingAppleMusicConnectPrompt) {
                Button("취소", role: .cancel) {
                    pendingAppleMusicAction = nil
                }
                Button("연결") {
                    Task {
                        await appModel.connectAppleMusic()
                        if appModel.isAppleMusicConnected, let action = pendingAppleMusicAction {
                            performAppleMusicAction(action)
                        }
                        pendingAppleMusicAction = nil
                    }
                }
            } message: {
                Text("앨범 검색과 플레이리스트 가져오기를 사용하려면 Apple Music 연결이 필요해요.")
            }
            .navigationDestination(isPresented: $isShowingTrackSearch) {
                TrackSearchView {
                    activeShelf = .drawer
                }
            }
            .sheet(item: $activeShelf) { shelf in
                AppleMusicShelfView(kind: shelf)
                    .presentationDetents((shelf == .drawer || shelf == .playlists) ? [.large] : [.medium, .large])
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
        case .playlists:
            activeShelf = .playlists
            Task { await appModel.loadLibraryPlaylists() }
        }
    }
}

private enum AppleMusicRequiredAction {
    case search
    case playlists
}

private enum AppleMusicShelfKind: String, Identifiable {
    case drawer
    case playlists
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drawer: "내 서랍"
        case .playlists: "플레이리스트"
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
                    Text(appModel.appleMusicShelfStatusText)
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                    Spacer()
                    if appModel.isLoadingAppleMusicShelf {
                        ProgressView()
                            .tint(MonoTheme.accent)
                    }
                }

                switch kind {
                case .drawer:
                    AlbumDrawerView()
                case .playlists, .history:
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            switch kind {
                            case .drawer:
                                EmptyView()
                            case .playlists:
                            AppleMusicDrawerPlaylistImportSection()
                            case .history:
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
            }
            .padding(18)
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationTitle(kind.title)
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

private struct AlbumDrawerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DrawerSideDock()

            HStack {
                Text("내 서랍")
                    .font(MonoTheme.point)
                    .foregroundStyle(MonoTheme.paper)
                Spacer()
            }

            ScrollView {
                if appModel.drawerAlbums.isEmpty {
                    Text("검색에서 앨범을 찾아 내 서랍에 넣어보세요.")
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 14
                    ) {
                        ForEach(appModel.drawerAlbums) { album in
                            DrawerAlbumTile(
                                album: album,
                                onInsertA: {
                                    Task { await appModel.insertAlbum(album, into: .a) }
                                },
                                onInsertB: {
                                    Task { await appModel.insertAlbum(album, into: .b) }
                                },
                                onDelete: {
                                    appModel.deleteDrawerAlbum(album)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct DrawerSideDock: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 8) {
            CassetteSideSlot(side: .a, album: appModel.cassetteSideA, isSelected: appModel.selectedCassetteSide == .a) {
                if let album = appModel.cassetteSideA {
                    Task { await appModel.insertAlbum(album, into: .a) }
                } else {
                    appModel.selectedCassetteSide = .a
                }
            } onDropAlbum: { id in
                Task {
                    await appModel.insertDrawerAlbum(id: id, into: .a)
                }
            }
            CassetteSideSlot(side: .b, album: appModel.cassetteSideB, isSelected: appModel.selectedCassetteSide == .b) {
                if let album = appModel.cassetteSideB {
                    Task { await appModel.insertAlbum(album, into: .b) }
                } else {
                    appModel.selectedCassetteSide = .b
                }
            } onDropAlbum: { id in
                Task {
                    await appModel.insertDrawerAlbum(id: id, into: .b)
                }
            }
        }
        .padding(.bottom, 2)
        .background(MonoTheme.ink)
    }
}

private struct CassetteSideSlot: View {
    let side: CassetteSide
    let album: AlbumSnapshot?
    let isSelected: Bool
    let action: () -> Void
    let onDropAlbum: (AlbumSnapshot.ID) -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(side.title)
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                    Spacer()
                    if album != nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MonoTheme.paper)
                    }
                }

                if let album {
                    HStack(spacing: 8) {
                        AlbumArtworkView(url: album.artworkURL)
                            .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title)
                                .font(MonoTheme.small)
                                .foregroundStyle(MonoTheme.paper)
                                .lineLimit(1)
                            Text(album.artistName)
                                .font(Font.custom("Paperlogy-4Regular", size: 10))
                                .foregroundStyle(MonoTheme.mist)
                                .lineLimit(1)
                            Text(album.albumFactText)
                                .font(Font.custom("Paperlogy-4Regular", size: 9))
                                .foregroundStyle(MonoTheme.mist.opacity(0.78))
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("앨범을 끌어 넣기")
                        .font(MonoTheme.small)
                        .foregroundStyle(MonoTheme.mist)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 78, alignment: .topLeading)
            .padding(12)
            .background(isSelected ? MonoTheme.accent.opacity(0.42) : Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: album == nil ? 1.4 : 1, dash: album == nil ? [5, 5] : [])
                    )
                    .foregroundStyle(album == nil ? MonoTheme.mist.opacity(0.65) : MonoTheme.paper.opacity(0.18))
            }
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            onDropAlbum(id)
            return true
        }
    }
}

private struct DrawerAlbumTile: View {
    let album: AlbumSnapshot
    let onInsertA: () -> Void
    let onInsertB: () -> Void
    let onDelete: () -> Void
    @State private var isShowingAlbumActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AlbumArtworkView(url: album.artworkURL)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        isShowingAlbumActions = true
                    } label: {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MonoTheme.paper)
                            .frame(width: 26, height: 26)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .accessibilityLabel("앨범 삽입 메뉴")
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(album.artistName)
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
                Text(album.albumFactText)
                    .font(Font.custom("Paperlogy-4Regular", size: 10))
                    .foregroundStyle(MonoTheme.mist.opacity(0.82))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .draggable(album.id)
        .confirmationDialog(album.title, isPresented: $isShowingAlbumActions, titleVisibility: .visible) {
            Button("A면 삽입", action: onInsertA)
            Button("B면 삽입", action: onInsertB)
            Button("앨범 삭제", role: .destructive, action: onDelete)
            Button("취소", role: .cancel) {}
        }
    }
}

private struct MonoPlaylistEditor: View {
    @Environment(AppModel.self) private var appModel
    let onPlayPlaylist: () -> Void
    let onPlayTrack: (TrackSnapshot) -> Void
    @State private var renameDraft = ""
    @State private var isShowingRenameAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("모노싱크 플레이리스트")
                    .font(MonoTheme.point)
                    .foregroundStyle(MonoTheme.paper)
                Spacer()
                Button(action: onPlayPlaylist) {
                    Image(systemName: "play.fill")
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 38, height: 38)
                        .background(appModel.isSelectedMonoPlaylistPlaying ? MonoTheme.accent : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(appModel.selectedMonoPlaylist?.tracks.isEmpty ?? true)
                .opacity((appModel.selectedMonoPlaylist?.tracks.isEmpty ?? true) ? 0.38 : 1)
                .accessibilityLabel("선택한 모노플리 재생")

                Button {
                    appModel.createMonoPlaylist()
                } label: {
                    Image(systemName: "plus")
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 38, height: 38)
                        .background(MonoTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("모노플리 만들기")
            }

            if !appModel.monoPlaylists.isEmpty {
                HStack(spacing: 8) {
                    Picker("모노플리", selection: Binding(
                        get: { appModel.selectedMonoPlaylistID ?? appModel.monoPlaylists.first?.id },
                        set: { id in
                            appModel.selectedMonoPlaylistID = id
                        }
                    )) {
                        ForEach(appModel.monoPlaylists) { playlist in
                            Text(playlist.title).tag(Optional(playlist.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(MonoTheme.paper)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        renameDraft = appModel.selectedMonoPlaylist?.title ?? ""
                        isShowingRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(MonoTheme.paper)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("모노플리 수정")
                }
                .alert("모노플리 수정", isPresented: $isShowingRenameAlert) {
                    TextField("이름", text: $renameDraft)

                    Button("취소", role: .cancel) {}
                    Button("저장") {
                        if let id = appModel.selectedMonoPlaylist?.id {
                            appModel.renameMonoPlaylist(id: id, title: renameDraft)
                        }
                    }
                } message: {
                    Text("선택한 모노플리의 이름을 바꿀 수 있어요.")
                }

                if let playlist = appModel.selectedMonoPlaylist {
                    if playlist.tracks.isEmpty {
                        Text("아직 곡이 없어요. Apple Music 플레이리스트나 최근 기록에서 곡을 담아보세요.")
                            .font(MonoTheme.small)
                            .foregroundStyle(MonoTheme.mist)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ForEach(playlist.tracks) { track in
                            MonoPlaylistTrackRow(
                                track: track,
                                onPlay: {
                                    onPlayTrack(track)
                                },
                                onDelete: {
                                    appModel.deleteTrackFromSelectedMonoPlaylist(track)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            if appModel.libraryPlaylists.isEmpty {
                await appModel.loadLibraryPlaylists()
            }
        }
    }
}

private struct AppleMusicImportSection: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("애플뮤직 플레이리스트 가져오기")
                    .font(MonoTheme.pointSmall)
                    .foregroundStyle(MonoTheme.mist)
                Spacer()
                Button {
                    Task { await appModel.loadLibraryPlaylists() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("애플뮤직 플레이리스트 새로고침")
            }

            if appModel.libraryPlaylists.isEmpty {
                Text("가져올 Apple Music 플레이리스트가 아직 없어요.")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(appModel.libraryPlaylists) { playlist in
                    MusicCollectionImportRow(item: playlist) {
                        Task { await appModel.importAppleMusicPlaylistToSelectedMonoPlaylist(playlist) }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            if appModel.libraryPlaylists.isEmpty, !appModel.isLoadingAppleMusicShelf {
                await appModel.loadLibraryPlaylists()
            }
        }
    }
}

private struct AppleMusicDrawerPlaylistImportSection: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Apple Music 플레이리스트")
                    .font(MonoTheme.pointSmall)
                    .foregroundStyle(MonoTheme.mist)
                Spacer()
                Button {
                    Task { await appModel.loadLibraryPlaylists() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("새로고침")
            }

            if appModel.libraryPlaylists.isEmpty {
                Text("가져올 Apple Music 플레이리스트가 아직 없어요.")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(appModel.libraryPlaylists) { playlist in
                    MusicCollectionImportRow(
                        item: playlist,
                        isImported: appModel.drawerAlbums.contains(where: { $0.id == "monosync-playlist-album:\(playlist.id)" })
                    ) {
                        Task { await appModel.importAppleMusicPlaylistToDrawer(playlist) }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MusicCollectionImportRow: View {
    let item: MusicCollectionSnapshot
    var isImported = false
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(url: item.artworkURL)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                Text("이 안의 곡을 선택한 모노플리에 담기")
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onImport) {
                Image(systemName: isImported ? "archivebox.fill" : "square.and.arrow.down")
                    .foregroundStyle(isImported ? MonoTheme.paper : MonoTheme.mist)
                    .frame(width: 36, height: 36)
                    .background(isImported ? MonoTheme.accent : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isImported)
            .accessibilityLabel("모노플리에 가져오기")
        }
        .padding(12)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MonoPlaylistTrackRow: View {
    let track: TrackSnapshot
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AlbumArtworkView(url: track.artworkURL)
                .frame(width: 42, height: 42)

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

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .foregroundStyle(MonoTheme.paper)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("이 곡부터 재생")

            Button(action: onDelete) {
                Image(systemName: "minus")
                    .foregroundStyle(MonoTheme.paper)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("모노플리에서 삭제")
        }
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
    let onPlaylists: () -> Void
    let onDrawer: () -> Void
    let onMenu: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("momosync.")
                    .font(Font.custom("Paperlogy-7Bold", size: 25))
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                Text("share the tape")
                    .font(Font.custom("Paperlogy-4Regular", size: 11))
                    .foregroundStyle(MonoTheme.mist)
            }

            Spacer()

            HStack(spacing: 5) {
                HeaderCircleButton(systemName: "magnifyingglass", action: onSearch)
                .accessibilityLabel("검색")
                HeaderCircleButton(systemName: "music.note.list", action: onPlaylists)
                    .accessibilityLabel("플레이리스트")
                HeaderCircleButton(systemName: "archivebox", action: onDrawer)
                    .accessibilityLabel("내 서랍")
                MenuCircleButton(isActive: true, action: onMenu)
            }
            .padding(.top, 6)
        }
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
