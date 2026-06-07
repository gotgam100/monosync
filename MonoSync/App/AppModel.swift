import Foundation
import MusicKit

enum CassetteTransportButton: Hashable, Sendable {
    case previous
    case play
    case pause
    case next
    case stop
}

@Observable
@MainActor
final class AppModel {
    let musicService: AppleMusicServicing
    let spaceStore: SpaceStoring

    var currentUser: MonoUser
    var mySpace: ListeningSpace
    var friendSpaces: [ListeningSpace]
    var selectedLanguage: AppLanguage
    var musicStatusText = "애플뮤직 연결 전"
    var isMusicPlaybackActive = false
    var searchResults: [TrackSnapshot] = []
    var albumSearchResults: [AlbumSnapshot] = []
    var isSearchingTracks = false
    var searchStatusText = "곡 제목이나 아티스트로 앨범을 찾아보세요"
    var drawerAlbums: [AlbumSnapshot] = []
    var cassetteSideA: AlbumSnapshot?
    var cassetteSideB: AlbumSnapshot?
    var selectedCassetteSide: CassetteSide = .a
    var activeCassetteSide: CassetteSide?
    var activeCassetteTrackIndex: Int?
    var pressedCassetteButtons: Set<CassetteTransportButton> = []
    var libraryPlaylists: [MusicCollectionSnapshot] = []
    var recentlyPlayedTracks: [TrackSnapshot] = []
    var monoPlaylists: [MonoPlaylist] = [.sample]
    var selectedMonoPlaylistID: MonoPlaylist.ID?
    var activeMonoPlaylistID: MonoPlaylist.ID?
    var activeMonoPlaylistTrackIndex: Int?
    var activeMonoPlaylistTrackID: TrackSnapshot.ID?
    var isLoadingAppleMusicShelf = false
    var appleMusicShelfStatusText = "Apple Music 보관함을 불러올 수 있어요"

    private var playerSyncTask: Task<Void, Never>?
    private var lastPublishedSnapshot: MusicPlayerSnapshot?
    private var isTransportStoppedManually = false
    private var isHandlingPauseButton = false
    private var searchGeneration = 0
    private var playlistLoadGeneration = 0
    private var shelfOperationGeneration = 0

    var isCassetteTransportZero: Bool {
        pressedCassetteButtons.isEmpty
    }

    var isAppleMusicConnected: Bool {
        musicService.authorizationStatus == .authorized
    }

    init() {
        self.musicService = AppleMusicService()
        #if canImport(FirebaseFirestore)
        self.spaceStore = FirestoreSpaceStore()
        #else
        self.spaceStore = InMemorySpaceStore()
        #endif
        self.currentUser = .sampleMe
        self.mySpace = .sampleMe
        self.friendSpaces = ListeningSpace.sampleFriends
        self.selectedLanguage = .korean
        self.selectedMonoPlaylistID = self.monoPlaylists.first?.id
    }

    init(musicService: AppleMusicServicing, spaceStore: SpaceStoring) {
        self.musicService = musicService
        self.spaceStore = spaceStore
        self.currentUser = .sampleMe
        self.mySpace = .sampleMe
        self.friendSpaces = ListeningSpace.sampleFriends
        self.selectedLanguage = .korean
        self.selectedMonoPlaylistID = self.monoPlaylists.first?.id
    }

    @MainActor
    func connectAppleMusic() async {
        let status = await musicService.requestAuthorization()
        updateMusicStatus(status: status)
        startPlayerSync()
    }

    @MainActor
    func publish(_ event: PlaybackEvent) async {
        mySpace.apply(event)
        await spaceStore.publish(space: mySpace, event: event)
    }

    @MainActor
    func selectTrack(_ track: TrackSnapshot) async {
        clearActiveMonoPlaylist()
        await publish(.started(track: track, position: 0, at: .now))
        await playCurrentTrack()
    }

    @MainActor
    func searchTracks(term: String) async {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        searchGeneration += 1
        let generation = searchGeneration
        guard !trimmedTerm.isEmpty else {
            searchResults = []
            albumSearchResults = []
            searchStatusText = "곡 제목이나 아티스트로 앨범을 찾아보세요"
            isSearchingTracks = false
            return
        }

        do {
            isSearchingTracks = true
            searchStatusText = "애플뮤직에서 앨범 찾는 중"
            let albums = try await musicService.searchAlbums(term: trimmedTerm)
            guard generation == searchGeneration else { return }
            albumSearchResults = albums
            searchResults = albumSearchResults.flatMap(\.tracks)
            searchStatusText = albumSearchResults.isEmpty ? "검색 결과가 없어요" : "\(albumSearchResults.count)개 앨범 찾음"
        } catch let error as AppleMusicPlaybackError {
            guard generation == searchGeneration else { return }
            searchStatusText = error.errorDescription ?? "검색 실패"
        } catch {
            guard generation == searchGeneration else { return }
            searchStatusText = musicPlaybackFailureMessage(for: error)
        }
        guard generation == searchGeneration else { return }
        isSearchingTracks = false
    }

    @MainActor
    func addAlbumToDrawer(_ album: AlbumSnapshot) {
        if drawerAlbums.contains(where: { $0.id == album.id }) {
            searchStatusText = "이미 내 서랍에 있는 앨범이에요"
            appleMusicShelfStatusText = searchStatusText
            return
        }

        drawerAlbums.insert(album, at: 0)
        searchStatusText = "\(album.title)을 내 서랍에 넣었어요"
        appleMusicShelfStatusText = searchStatusText
    }

    @MainActor
    func insertAlbum(_ album: AlbumSnapshot, into side: CassetteSide) async {
        if mySpace.currentTrack != nil || isMusicPlaybackActive || !pressedCassetteButtons.isEmpty {
            await stopCurrentTrack(resetPosition: true)
        }

        switch side {
        case .a:
            cassetteSideA = album
        case .b:
            cassetteSideB = album
        }
        selectedCassetteSide = side
        activeCassetteSide = nil
        activeCassetteTrackIndex = nil
        isMusicPlaybackActive = false
        isTransportStoppedManually = true
        pressedCassetteButtons = []
        if let firstTrack = album.tracks.first {
            mySpace.currentTrack = firstTrack
            mySpace.playbackState = .idle
            mySpace.playbackStartedAt = nil
            mySpace.positionAtAnchor = 0
            mySpace.updatedAt = .now
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: firstTrack,
                position: 0,
                playbackState: .idle
            )
        }
        SoundEffectPlayer.shared.play(.insert)
        appleMusicShelfStatusText = "\(album.title)을 \(side.title)에 넣었어요"
        musicStatusText = "\(side.title) · \(album.title) 준비됨"
    }

    @MainActor
    func insertDrawerAlbum(id: AlbumSnapshot.ID, into side: CassetteSide) async {
        guard let album = drawerAlbums.first(where: { $0.id == id }) else { return }
        await insertAlbum(album, into: side)
    }

    @MainActor
    func deleteDrawerAlbum(_ album: AlbumSnapshot) {
        drawerAlbums.removeAll { $0.id == album.id }
        if cassetteSideA?.id == album.id {
            cassetteSideA = nil
        }
        if cassetteSideB?.id == album.id {
            cassetteSideB = nil
        }
        if selectedCassetteAlbum == nil {
            activeCassetteSide = nil
            activeCassetteTrackIndex = nil
            mySpace.currentTrack = nil
            mySpace.playbackState = .idle
            mySpace.playbackStartedAt = nil
            mySpace.positionAtAnchor = 0
        }
        appleMusicShelfStatusText = "\(album.title)을 내 서랍에서 지웠어요"
        musicStatusText = "내 서랍 정리됨"
    }

    var selectedCassetteAlbum: AlbumSnapshot? {
        album(for: selectedCassetteSide)
    }

    func album(for side: CassetteSide) -> AlbumSnapshot? {
        switch side {
        case .a: cassetteSideA
        case .b: cassetteSideB
        }
    }

    @MainActor
    func playSelectedCassetteSide(startingAt track: TrackSnapshot? = nil, startTime: TimeInterval = 0) async {
        guard let album = selectedCassetteAlbum else {
            musicStatusText = "\(selectedCassetteSide.title)에 앨범이 없어요"
            return
        }

        do {
            let startIndex = track.flatMap { selectedTrack in
                album.tracks.firstIndex(where: { $0.matches(selectedTrack) })
            } ?? 0
            musicStatusText = "\(selectedCassetteSide.title) 재생 준비 중"
            let resolvedTracks = try await musicService.play(album: album, startIndex: startIndex, startTime: startTime)
            guard !resolvedTracks.isEmpty else {
                musicStatusText = "\(selectedCassetteSide.title)에 재생할 곡이 없어요"
                return
            }
            let safeStartIndex = min(max(0, startIndex), resolvedTracks.count - 1)
            let firstTrack = resolvedTracks[safeStartIndex]
            storeResolvedTracks(resolvedTracks, forAlbumID: album.id)

            isTransportStoppedManually = false
            isMusicPlaybackActive = true
            activeCassetteSide = selectedCassetteSide
            activeCassetteTrackIndex = safeStartIndex
            clearActiveMonoPlaylist()
            await publish(.started(track: firstTrack, position: startTime, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: firstTrack,
                position: startTime,
                playbackState: .playing
            )
            musicStatusText = "\(selectedCassetteSide.title) · \(album.title) 재생 중"
            startPlayerSync()
        } catch let error as AppleMusicPlaybackError {
            isMusicPlaybackActive = false
            musicStatusText = error.errorDescription ?? "카세트 재생 실패"
        } catch {
            isMusicPlaybackActive = false
            musicStatusText = musicPlaybackFailureMessage(for: error)
        }
    }

    @MainActor
    func flipCassetteSide() {
        selectedCassetteSide = selectedCassetteSide == .a ? .b : .a
        musicStatusText = "\(selectedCassetteSide.title) 선택됨"
    }

    @MainActor
    func resumeCassettePlayback() async {
        guard let side = activeCassetteSide ?? (selectedCassetteAlbum == nil ? nil : selectedCassetteSide) else {
            await playCurrentTrack()
            return
        }

        selectedCassetteSide = side
        if let currentTrack = mySpace.currentTrack {
            await playSelectedCassetteSide(startingAt: currentTrack, startTime: mySpace.currentPosition())
        } else {
            await playSelectedCassetteSide()
        }
    }

    @MainActor
    func pressPreviousButton() async {
        let wasPlaying = pressedCassetteButtons.contains(.play) && !pressedCassetteButtons.contains(.pause)
        let currentPosition = mySpace.currentPosition()

        if wasPlaying, currentPosition > 2 {
            pressedCassetteButtons = [.previous]
            if let currentTrack = mySpace.currentTrack {
                await playSelectedCassetteSide(startingAt: currentTrack, startTime: 0)
            }
            pressedCassetteButtons = wasPlaying ? [.play] : []
            return
        }

        let moved = await moveCassetteTrack(offset: -1, shouldPlay: wasPlaying)
        if moved {
            pressedCassetteButtons = wasPlaying ? [.play] : []
        } else {
            await releaseCassetteTransport()
        }
    }

    @MainActor
    func pressPlayButton() async {
        if pressedCassetteButtons.contains(.pause) {
            let position = currentPlaybackPosition()
            pressedCassetteButtons = [.play]
            await resumeCurrentPlayback(at: position)
            return
        }

        if pressedCassetteButtons == [.play] {
            await releaseCassetteTransport()
            return
        }

        let shouldStartFromBeginning = pressedCassetteButtons.contains(.stop)
        pressedCassetteButtons = [.play]

        if activeCassetteSide != nil || selectedCassetteAlbum != nil {
            selectedCassetteSide = activeCassetteSide ?? selectedCassetteSide
            if let currentTrack = mySpace.currentTrack {
                await playSelectedCassetteSide(
                    startingAt: currentTrack,
                    startTime: shouldStartFromBeginning ? 0 : mySpace.currentPosition()
                )
            } else {
                await playSelectedCassetteSide()
            }
        } else if mySpace.currentTrack != nil {
            if shouldStartFromBeginning {
                mySpace.positionAtAnchor = 0
            }
            await playCurrentTrack()
        } else {
            await connectAppleMusic()
        }
    }

    @MainActor
    func pressPauseButton() async {
        guard !isHandlingPauseButton else { return }
        isHandlingPauseButton = true
        defer { isHandlingPauseButton = false }

        guard pressedCassetteButtons.contains(.play) else {
            musicStatusText = "재생 중일 때만 일시정지할 수 있어요"
            return
        }

        if pressedCassetteButtons.contains(.pause) {
            let position = currentPlaybackPosition()
            pressedCassetteButtons = [.play]
            await resumeCurrentPlayback(at: position)
        } else {
            let position = currentPlaybackPosition()
            pressedCassetteButtons = [.play, .pause]
            await pauseCurrentTrack(at: position)
        }
    }

    @MainActor
    func pressNextButton() async {
        let wasPlaying = pressedCassetteButtons.contains(.play) && !pressedCassetteButtons.contains(.pause)
        let moved = await moveCassetteTrack(offset: 1, shouldPlay: wasPlaying)
        if moved {
            pressedCassetteButtons = wasPlaying ? [.play] : []
        } else {
            await releaseCassetteTransport()
        }
    }

    @MainActor
    func pressStopButton() async {
        if pressedCassetteButtons.isEmpty {
            musicStatusText = "내 서랍 열기"
            return
        }

        if pressedCassetteButtons == [.stop] {
            await releaseCassetteTransport()
            return
        }

        pressedCassetteButtons = [.stop]
        await stopCurrentTrack(resetPosition: true)
    }

    @MainActor
    func releaseCassetteTransport() async {
        pressedCassetteButtons = []
        if isMusicPlaybackActive {
            await pauseCurrentTrack()
        } else {
            isMusicPlaybackActive = false
        }
        musicStatusText = "제로 상태"
    }

    @MainActor
    func loadLibraryPlaylists() async {
        playlistLoadGeneration += 1
        let generation = playlistLoadGeneration
        isLoadingAppleMusicShelf = true
        appleMusicShelfStatusText = "플레이리스트 불러오는 중"

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            guard generation == playlistLoadGeneration, isLoadingAppleMusicShelf else { return }
            isLoadingAppleMusicShelf = false
            appleMusicShelfStatusText = "플레이리스트 응답이 늦어요. Apple Music 앱에서 보관함을 확인한 뒤 다시 시도해 주세요."
        }

        do {
            let playlists = try await musicService.libraryPlaylists()
            guard generation == playlistLoadGeneration else { return }
            libraryPlaylists = playlists
            appleMusicShelfStatusText = libraryPlaylists.isEmpty ? "표시할 플레이리스트가 없어요" : "\(libraryPlaylists.count)개 플레이리스트"
        } catch let error as AppleMusicPlaybackError {
            guard generation == playlistLoadGeneration else { return }
            appleMusicShelfStatusText = error.errorDescription ?? "플레이리스트를 불러오지 못했어요"
        } catch {
            guard generation == playlistLoadGeneration else { return }
            appleMusicShelfStatusText = musicPlaybackFailureMessage(for: error)
        }
        guard generation == playlistLoadGeneration else { return }
        isLoadingAppleMusicShelf = false
    }

    @MainActor
    func loadRecentlyPlayedTracks() async {
        do {
            isLoadingAppleMusicShelf = true
            appleMusicShelfStatusText = "최근 기록 불러오는 중"
            recentlyPlayedTracks = try await musicService.recentlyPlayedTracks()
            appleMusicShelfStatusText = recentlyPlayedTracks.isEmpty ? "표시할 최근 기록이 없어요" : "\(recentlyPlayedTracks.count)곡 최근 기록"
        } catch let error as AppleMusicPlaybackError {
            appleMusicShelfStatusText = error.errorDescription ?? "최근 기록을 불러오지 못했어요"
        } catch {
            appleMusicShelfStatusText = musicPlaybackFailureMessage(for: error)
        }
        isLoadingAppleMusicShelf = false
    }

    @MainActor
    func createMonoPlaylist() {
        let nextNumber = monoPlaylists.count + 1
        let now = Date()
        let playlist = MonoPlaylist(
            id: UUID().uuidString,
            title: "모노플리 \(nextNumber)",
            tracks: [],
            createdAt: now,
            updatedAt: now
        )
        monoPlaylists.insert(playlist, at: 0)
        selectedMonoPlaylistID = playlist.id
        appleMusicShelfStatusText = "\(playlist.title) 만들었어요"
    }

    @MainActor
    func renameMonoPlaylist(id: MonoPlaylist.ID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let index = monoPlaylists.firstIndex(where: { $0.id == id }) else { return }

        monoPlaylists[index].title = trimmedTitle
        monoPlaylists[index].updatedAt = .now
        appleMusicShelfStatusText = "모노플리 이름을 바꿨어요"
    }

    @MainActor
    func deleteTracksFromSelectedMonoPlaylist(at offsets: IndexSet) {
        guard let index = selectedMonoPlaylistIndex else { return }
        for offset in offsets.sorted(by: >) {
            monoPlaylists[index].tracks.remove(at: offset)
        }
        monoPlaylists[index].updatedAt = .now
        appleMusicShelfStatusText = "모노플리에서 곡을 뺐어요"
    }

    @MainActor
    func deleteTrackFromSelectedMonoPlaylist(_ track: TrackSnapshot) {
        guard let index = selectedMonoPlaylistIndex else { return }
        monoPlaylists[index].tracks.removeAll { $0.id == track.id }
        monoPlaylists[index].updatedAt = .now
        appleMusicShelfStatusText = "\(track.title)을 모노플리에서 뺐어요"
    }

    @MainActor
    func addTrackToSelectedMonoPlaylist(_ track: TrackSnapshot) {
        ensureSelectedMonoPlaylist()
        guard let index = selectedMonoPlaylistIndex else { return }

        if !monoPlaylists[index].tracks.contains(where: { $0.id == track.id }) {
            monoPlaylists[index].tracks.append(track)
            monoPlaylists[index].updatedAt = .now
            appleMusicShelfStatusText = "\(track.title)을 \(monoPlaylists[index].title)에 담았어요"
        } else {
            appleMusicShelfStatusText = "이미 모노플리에 있는 곡이에요"
        }
    }

    @MainActor
    func importAppleMusicPlaylistToSelectedMonoPlaylist(_ playlist: MusicCollectionSnapshot) async {
        shelfOperationGeneration += 1
        let generation = shelfOperationGeneration
        isLoadingAppleMusicShelf = true
        appleMusicShelfStatusText = "\(playlist.title) 가져오는 중"
        watchShelfOperation(generation: generation, message: "플레이리스트 응답이 늦어요. 잠시 뒤 다시 시도해 주세요.")

        do {
            ensureSelectedMonoPlaylist()
            let tracks = try await musicService.tracks(in: playlist)
            guard generation == shelfOperationGeneration else { return }
            addTracksToSelectedMonoPlaylist(tracks)
            appleMusicShelfStatusText = tracks.isEmpty ? "가져올 곡이 없어요" : "\(tracks.count)곡을 모노플리에 담았어요"
        } catch let error as AppleMusicPlaybackError {
            guard generation == shelfOperationGeneration else { return }
            appleMusicShelfStatusText = error.errorDescription ?? "플레이리스트를 가져오지 못했어요"
        } catch {
            guard generation == shelfOperationGeneration else { return }
            appleMusicShelfStatusText = musicPlaybackFailureMessage(for: error)
        }
        guard generation == shelfOperationGeneration else { return }
        isLoadingAppleMusicShelf = false
    }

    @MainActor
    func importAppleMusicPlaylistToDrawer(_ playlist: MusicCollectionSnapshot) async {
        let album = AlbumSnapshot(
            id: "monosync-playlist-album:\(playlist.sourceID)",
            title: playlist.title,
            artistName: playlist.subtitle,
            releaseYear: "플레이리스트",
            artworkURL: playlist.artworkURL,
            tracks: []
        )
        addAlbumToDrawer(album)
        appleMusicShelfStatusText = "\(playlist.title)을 내 서랍에 넣었어요"
        isLoadingAppleMusicShelf = false
    }

    @MainActor
    func playSelectedMonoPlaylist(startingAt track: TrackSnapshot? = nil) async {
        guard let playlist = selectedMonoPlaylist else {
            appleMusicShelfStatusText = "재생할 모노플리가 없어요"
            return
        }

        guard !playlist.tracks.isEmpty else {
            appleMusicShelfStatusText = "모노플리에 곡이 없어요"
            return
        }

        let startIndex = track.flatMap { selectedTrack in
            playlist.tracks.firstIndex(where: { $0.id == selectedTrack.id })
        } ?? 0
        let firstTrack = playlist.tracks[startIndex]

        do {
            musicStatusText = "\(playlist.title) 재생 준비 중"
            appleMusicShelfStatusText = "\(playlist.title) 재생 중"
            try await musicService.play(tracks: playlist.tracks, startIndex: startIndex, startTime: 0)
            isTransportStoppedManually = false
            isMusicPlaybackActive = true
            activeMonoPlaylistID = playlist.id
            activeMonoPlaylistTrackIndex = startIndex
            activeMonoPlaylistTrackID = firstTrack.id
            await publish(.started(track: firstTrack, position: 0, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: firstTrack,
                position: 0,
                playbackState: .playing
            )
            musicStatusText = "\(playlist.title) 재생 중"
            startPlayerSync()
        } catch let error as AppleMusicPlaybackError {
            isMusicPlaybackActive = false
            musicStatusText = error.errorDescription ?? "모노플리 재생 실패"
            appleMusicShelfStatusText = musicStatusText
        } catch {
            isMusicPlaybackActive = false
            musicStatusText = musicPlaybackFailureMessage(for: error)
            appleMusicShelfStatusText = musicStatusText
        }
    }

    var selectedMonoPlaylist: MonoPlaylist? {
        guard let selectedMonoPlaylistID else { return monoPlaylists.first }
        return monoPlaylists.first(where: { $0.id == selectedMonoPlaylistID }) ?? monoPlaylists.first
    }

    var isSelectedMonoPlaylistPlaying: Bool {
        activeMonoPlaylistID == selectedMonoPlaylist?.id && isMusicPlaybackActive
    }

    @MainActor
    func playCurrentTrack() async {
        guard let track = mySpace.currentTrack else { return }

        do {
            musicStatusText = "애플뮤직 재생 준비 중"
            try await musicService.play(track: track, startTime: mySpace.currentPosition())
            isTransportStoppedManually = false
            isMusicPlaybackActive = true
            let position = mySpace.currentPosition()
            await publish(.resumed(position: position, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: track,
                position: position,
                playbackState: .playing
            )
            musicStatusText = musicService.canPlayCatalogContent ? "애플뮤직 재생 중" : "구독 상태 확인 필요"
            startPlayerSync()
        } catch let error as AppleMusicPlaybackError {
            isMusicPlaybackActive = false
            musicStatusText = error.errorDescription ?? "애플뮤직 재생 실패"
        } catch {
            isMusicPlaybackActive = false
            musicStatusText = musicPlaybackFailureMessage(for: error)
        }
    }

    @MainActor
    func resumeCurrentPlayback(at position: TimeInterval) async {
        guard let track = mySpace.currentTrack else {
            isMusicPlaybackActive = false
            musicStatusText = "재개할 곡이 없어요"
            return
        }

        do {
            try await musicService.resume(startTime: position)
            isTransportStoppedManually = false
            isMusicPlaybackActive = true
            await publish(.resumed(position: position, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: track,
                position: position,
                playbackState: .playing
            )
            musicStatusText = "재생 중"
            startPlayerSync()
        } catch let error as AppleMusicPlaybackError {
            isMusicPlaybackActive = false
            musicStatusText = error.errorDescription ?? "재생 재개 실패"
        } catch {
            isMusicPlaybackActive = false
            musicStatusText = musicPlaybackFailureMessage(for: error)
        }
    }

    @MainActor
    func join(space: ListeningSpace) async {
        guard let track = space.currentTrack else {
            musicStatusText = "친구가 듣는 곡이 없어요"
            return
        }

        clearActiveMonoPlaylist()
        mySpace.currentTrack = track
        mySpace.positionAtAnchor = space.currentPosition()
        mySpace.playbackStartedAt = .now
        mySpace.playbackState = .playing
        mySpace.updatedAt = .now
        await playCurrentTrack()
        musicStatusText = "\(space.owner.displayName)의 스페이스에 맞춰 듣는 중"
    }

    @MainActor
    func pauseCurrentTrack(at capturedPosition: TimeInterval? = nil) async {
        guard mySpace.currentTrack != nil else {
            isMusicPlaybackActive = false
            musicStatusText = "일시정지할 곡이 없어요"
            return
        }

        do {
            let position = capturedPosition ?? mySpace.currentPosition()
            try await musicService.pause()
            isTransportStoppedManually = false
            isMusicPlaybackActive = false
            await publish(.paused(position: position, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: mySpace.currentTrack,
                position: position,
                playbackState: .paused
            )
            musicStatusText = "일시정지됨"
        } catch {
            musicStatusText = "일시정지 실패"
        }
    }

    @MainActor
    func stopCurrentTrack(resetPosition: Bool = false) async {
        guard mySpace.currentTrack != nil else {
            isMusicPlaybackActive = false
            musicStatusText = "정지할 곡이 없어요"
            return
        }

        do {
            let position = resetPosition ? 0 : mySpace.currentPosition()
            try await musicService.pause()
            isTransportStoppedManually = true
            isMusicPlaybackActive = false
            await publish(.stopped(position: position, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: mySpace.currentTrack,
                position: position,
                playbackState: .idle
            )
            musicStatusText = "정지됨"
        } catch {
            isTransportStoppedManually = true
            isMusicPlaybackActive = false
            let position = resetPosition ? 0 : mySpace.currentPosition()
            await publish(.stopped(position: position, at: .now))
            lastPublishedSnapshot = MusicPlayerSnapshot(
                track: mySpace.currentTrack,
                position: position,
                playbackState: .idle
            )
            musicStatusText = "정지됨"
        }
    }

    @MainActor
    func playPreviousTrack() async {
        if activeCassetteSide != nil {
            await playCassetteOffset(-1)
            return
        }

        guard let playlist = activeMonoPlaylist,
              !playlist.tracks.isEmpty,
              let currentIndex = activeTrackIndex(in: playlist) else {
            musicStatusText = "이전 곡이 없어요"
            return
        }

        let previousIndex = max(currentIndex - 1, 0)
        guard previousIndex != currentIndex else {
            musicStatusText = "모노플리의 첫 곡이에요"
            return
        }

        selectedMonoPlaylistID = playlist.id
        await playSelectedMonoPlaylist(startingAt: playlist.tracks[previousIndex])
    }

    @MainActor
    func playNextTrack() async {
        if activeCassetteSide != nil {
            await playCassetteOffset(1)
            return
        }

        guard let playlist = activeMonoPlaylist,
              !playlist.tracks.isEmpty,
              let currentIndex = activeTrackIndex(in: playlist) else {
            musicStatusText = "다음 곡이 없어요"
            return
        }

        let nextIndex = min(currentIndex + 1, playlist.tracks.count - 1)
        guard nextIndex != currentIndex else {
            musicStatusText = "모노플리의 마지막 곡이에요"
            return
        }

        selectedMonoPlaylistID = playlist.id
        await playSelectedMonoPlaylist(startingAt: playlist.tracks[nextIndex])
    }

    @MainActor
    private func playCassetteOffset(_ offset: Int) async {
        guard let side = activeCassetteSide,
              let album = album(for: side),
              !album.tracks.isEmpty else {
            musicStatusText = offset > 0 ? "다음 곡이 없어요" : "이전 곡이 없어요"
            return
        }

        let currentIndex = activeCassetteTrackIndex ?? album.tracks.firstIndex { track in
            guard let currentTrack = mySpace.currentTrack else { return false }
            return track.matches(currentTrack)
        } ?? 0

        let nextIndex = currentIndex + offset
        guard album.tracks.indices.contains(nextIndex) else {
            musicStatusText = offset > 0 ? "\(side.title)의 마지막 곡이에요" : "\(side.title)의 첫 곡이에요"
            return
        }

        selectedCassetteSide = side
        activeCassetteTrackIndex = nextIndex
        await playSelectedCassetteSide(startingAt: album.tracks[nextIndex])
    }

    @MainActor
    private func moveCassetteTrack(offset: Int, shouldPlay: Bool) async -> Bool {
        let side = activeCassetteSide ?? selectedCassetteSide
        guard let album = album(for: side),
              !album.tracks.isEmpty else {
            musicStatusText = offset > 0 ? "다음 곡이 없어요" : "이전 곡이 없어요"
            return false
        }

        let currentIndex = activeCassetteTrackIndex ?? album.tracks.firstIndex { track in
            guard let currentTrack = mySpace.currentTrack else { return false }
            return track.matches(currentTrack)
        } ?? 0

        let nextIndex = currentIndex + offset
        guard album.tracks.indices.contains(nextIndex) else {
            musicStatusText = offset > 0 ? "\(side.title)의 마지막 곡이에요" : "\(side.title)의 첫 곡이에요"
            return false
        }

        selectedCassetteSide = side
        activeCassetteSide = side
        activeCassetteTrackIndex = nextIndex
        let track = album.tracks[nextIndex]

        if shouldPlay {
            await playSelectedCassetteSide(startingAt: track)
        } else {
            do {
                try await musicService.pause()
            } catch {
                // 큐 이동만 하는 제로 상태에서는 오디오 정지 실패를 치명적으로 보지 않습니다.
            }
            isMusicPlaybackActive = false
            isTransportStoppedManually = true
            mySpace.currentTrack = track
            mySpace.positionAtAnchor = 0
            mySpace.playbackState = .idle
            mySpace.playbackStartedAt = nil
            mySpace.updatedAt = .now
            await spaceStore.publish(space: mySpace, event: .stopped(position: 0, at: .now))
            musicStatusText = "\(track.title) 준비됨"
        }

        return true
    }

    private func startPlayerSync() {
        guard playerSyncTask == nil else { return }

        playerSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await self?.syncPlayerSnapshot()
            }
        }
    }

    @MainActor
    private func syncPlayerSnapshot() async {
        let snapshot = musicService.currentSnapshot()
        isMusicPlaybackActive = snapshot.playbackState == .playing
        if isTransportStoppedManually, snapshot.playbackState == .paused {
            return
        }
        updateActiveMonoPlaylist(using: snapshot.track)

        guard shouldPublish(snapshot) else { return }
        lastPublishedSnapshot = snapshot

        switch snapshot.playbackState {
        case .playing:
            if let track = snapshot.track, track.id != mySpace.currentTrack?.id {
                await publish(.started(track: track, position: snapshot.position, at: .now))
            } else {
                await publish(.resumed(position: snapshot.position, at: .now))
            }
            musicStatusText = "애플뮤직 재생 중"
        case .paused:
            await publish(.paused(position: snapshot.position, at: .now))
            musicStatusText = "일시정지됨"
        case .idle:
            await publish(.stopped(position: snapshot.position, at: .now))
            musicStatusText = musicService.authorizationStatus == .authorized ? "재생 대기 중" : musicStatusText
        }
    }

    private func shouldPublish(_ snapshot: MusicPlayerSnapshot) -> Bool {
        guard let previous = lastPublishedSnapshot else { return true }

        if previous.track?.id != snapshot.track?.id { return true }
        if previous.playbackState != snapshot.playbackState { return true }

        return false
    }

    private func currentPlaybackPosition() -> TimeInterval {
        let modelPosition = mySpace.currentPosition()
        let snapshot = musicService.currentSnapshot()

        guard let currentTrack = mySpace.currentTrack,
              let snapshotTrack = snapshot.track,
              snapshotTrack.matches(currentTrack) else {
            return modelPosition
        }

        return max(modelPosition, snapshot.position)
    }

    private var selectedMonoPlaylistIndex: Int? {
        guard let selectedID = selectedMonoPlaylistID else { return monoPlaylists.indices.first }
        return monoPlaylists.firstIndex(where: { $0.id == selectedID }) ?? monoPlaylists.indices.first
    }

    private var activeMonoPlaylist: MonoPlaylist? {
        guard let activeMonoPlaylistID else { return nil }
        return monoPlaylists.first(where: { $0.id == activeMonoPlaylistID })
    }

    private func activeTrackIndex(in playlist: MonoPlaylist) -> Int? {
        if let activeMonoPlaylistTrackIndex,
           playlist.tracks.indices.contains(activeMonoPlaylistTrackIndex),
           isActiveTrack(playlist.tracks[activeMonoPlaylistTrackIndex]) {
            return activeMonoPlaylistTrackIndex
        }

        return playlist.tracks.firstIndex { isActiveTrack($0) }
    }

    private func updateActiveMonoPlaylist(using track: TrackSnapshot?) {
        updateActiveCassette(using: track)

        guard let track,
              let playlist = activeMonoPlaylist,
              let index = playlist.tracks.firstIndex(where: { $0.matches(track) }) else {
            return
        }

        activeMonoPlaylistTrackIndex = index
        activeMonoPlaylistTrackID = playlist.tracks[index].id
    }

    private func clearActiveMonoPlaylist() {
        activeMonoPlaylistID = nil
        activeMonoPlaylistTrackIndex = nil
        activeMonoPlaylistTrackID = nil
    }

    private func updateActiveCassette(using track: TrackSnapshot?) {
        guard let track,
              let activeCassetteSide,
              let album = album(for: activeCassetteSide),
              let index = album.tracks.firstIndex(where: { $0.matches(track) }) else {
            return
        }

        activeCassetteTrackIndex = index
    }

    private func isActiveTrack(_ track: TrackSnapshot) -> Bool {
        if let activeMonoPlaylistTrackID, track.id == activeMonoPlaylistTrackID {
            return true
        }

        if let currentTrack = mySpace.currentTrack, track.matches(currentTrack) {
            return true
        }

        return false
    }

    private func ensureSelectedMonoPlaylist() {
        if monoPlaylists.isEmpty {
            createMonoPlaylist()
        }
        if selectedMonoPlaylistID == nil {
            selectedMonoPlaylistID = monoPlaylists.first?.id
        }
    }

    private func addTracksToSelectedMonoPlaylist(_ tracks: [TrackSnapshot]) {
        guard let index = selectedMonoPlaylistIndex else { return }
        let existingIDs = Set(monoPlaylists[index].tracks.map(\.id))
        let newTracks = tracks.filter { !existingIDs.contains($0.id) }
        monoPlaylists[index].tracks.append(contentsOf: newTracks)
        monoPlaylists[index].updatedAt = .now
    }

    private func storeResolvedTracks(_ tracks: [TrackSnapshot], forAlbumID albumID: AlbumSnapshot.ID) {
        guard !tracks.isEmpty else { return }

        if let index = drawerAlbums.firstIndex(where: { $0.id == albumID }) {
            drawerAlbums[index].tracks = tracks
            if drawerAlbums[index].artworkURL == nil {
                drawerAlbums[index].artworkURL = tracks.first?.artworkURL
            }
        }

        if cassetteSideA?.id == albumID {
            cassetteSideA?.tracks = tracks
            if cassetteSideA?.artworkURL == nil {
                cassetteSideA?.artworkURL = tracks.first?.artworkURL
            }
        }

        if cassetteSideB?.id == albumID {
            cassetteSideB?.tracks = tracks
            if cassetteSideB?.artworkURL == nil {
                cassetteSideB?.artworkURL = tracks.first?.artworkURL
            }
        }
    }

    private func updateMusicStatus(status: MusicAuthorization.Status) {
        switch status {
        case .authorized:
            musicStatusText = musicService.canPlayCatalogContent ? "애플뮤직 연결됨" : "애플뮤직 구독 확인 필요"
        case .denied:
            musicStatusText = "음악 접근 권한 거부됨"
        case .restricted:
            musicStatusText = "음악 접근 제한됨"
        case .notDetermined:
            musicStatusText = "애플뮤직 연결 전"
        @unknown default:
            musicStatusText = "애플뮤직 상태 확인 필요"
        }
    }

    private func watchShelfOperation(generation: Int, message: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            guard generation == shelfOperationGeneration, isLoadingAppleMusicShelf else { return }
            isLoadingAppleMusicShelf = false
            appleMusicShelfStatusText = message
        }
    }

    private func musicPlaybackFailureMessage(for error: Error) -> String {
        let detail = "\(error.localizedDescription) \(String(describing: error))"
        if detail.localizedCaseInsensitiveContains("DeveloperToken")
            || detail.localizedCaseInsensitiveContains("client identifier")
            || detail.localizedCaseInsensitiveContains("client not found") {
            return "개발자 계정에서 MusicKit 설정 필요"
        }

        if detail.localizedCaseInsensitiveContains("not entitled")
            || detail.localizedCaseInsensitiveContains("account store")
            || detail.localizedCaseInsensitiveContains("PermissionDenied")
            || detail.localizedCaseInsensitiveContains("-7013")
            || detail.localizedCaseInsensitiveContains("privacy acknowledgement") {
            return "Apple Music 계정 또는 보관함 권한 확인 필요"
        }

        return "재생 실패: 애플뮤직 확인 필요"
    }

}
