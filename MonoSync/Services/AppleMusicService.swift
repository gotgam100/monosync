import Foundation
import MediaPlayer
import MusicKit
import UIKit

enum AppleMusicPlaybackError: LocalizedError {
    case realDeviceRequired
    case authorizationRequired
    case subscriptionRequired
    case songNotFound
    case timedOut

    var errorDescription: String? {
        switch self {
        case .realDeviceRequired:
            "애플뮤직 재생은 실제 iPhone에서 확인해야 합니다."
        case .authorizationRequired:
            "애플뮤직 접근 권한이 필요합니다."
        case .subscriptionRequired:
            "애플뮤직 구독 상태를 확인해야 합니다."
        case .songNotFound:
            "애플뮤직에서 곡을 찾지 못했습니다."
        case .timedOut:
            "Apple Music 응답 없음 (보관함 동기화/계정 확인 필요)"
        }
    }
}

/// 주어진 비동기 작업을 제한 시간 안에 끝내지 못하면 timedOut을 던집니다.
/// MusicKit의 .with(.tracks) 등이 스토어프론트 문제로 무한 대기에 빠지는 것을 막습니다.
func withMusicTimeout<T: Sendable>(
    seconds: TimeInterval = 15,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw AppleMusicPlaybackError.timedOut
        }
        guard let result = try await group.next() else {
            throw AppleMusicPlaybackError.timedOut
        }
        group.cancelAll()
        return result
    }
}

struct MusicPlayerSnapshot: Equatable, Sendable {
    var track: TrackSnapshot?
    var position: TimeInterval
    var playbackState: PlaybackState
}

@MainActor
protocol AppleMusicServicing {
    var authorizationStatus: MusicAuthorization.Status { get }
    var canPlayCatalogContent: Bool { get }

    @discardableResult
    func requestAuthorization() async -> MusicAuthorization.Status
    func searchSongs(term: String) async throws -> [TrackSnapshot]
    func searchAlbums(term: String) async throws -> [AlbumSnapshot]
    func fetchArtist(name: String) async throws -> ArtistSnapshot
    func tracks(in album: AlbumSnapshot) async throws -> [TrackSnapshot]
    func libraryPlaylists() async throws -> [MusicCollectionSnapshot]
    func tracks(in playlist: MusicCollectionSnapshot) async throws -> [TrackSnapshot]
    func recentlyPlayedTracks() async throws -> [TrackSnapshot]
    func play(track: TrackSnapshot, startTime: TimeInterval) async throws
    func play(tracks: [TrackSnapshot], startIndex: Int, startTime: TimeInterval) async throws
    func play(album: AlbumSnapshot, startIndex: Int, startTime: TimeInterval) async throws -> [TrackSnapshot]
    func resume(startTime: TimeInterval?) async throws
    func pause() async throws
    func currentSnapshot() -> MusicPlayerSnapshot
}

@MainActor
@Observable
final class AppleMusicService: AppleMusicServicing {
    private let player = ApplicationMusicPlayer.shared

    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    var canPlayCatalogContent = true
    private var cachedLibraryPlaylists: [String: Playlist] = [:]
    private var hasPrimedSession = false

    @discardableResult
    func requestAuthorization() async -> MusicAuthorization.Status {
        authorizationStatus = await MusicAuthorization.request()
        if authorizationStatus == .authorized {
            await refreshSubscription()
            await primePlaybackSessionIfNeeded()
        }
        return authorizationStatus
    }

    /// 친구들 곡 재생이 하던 일(카탈로그 곡으로 재생 세션 초기화)을 미리 수행합니다.
    /// 이 세션 초기화 전에는 라이브러리 접근/카탈로그 상세 로딩이 콜드 상태에서 막힙니다.
    /// 소리는 내지 않고 prepareToPlay로 세션만 깨웁니다.
    private func primePlaybackSessionIfNeeded() async {
        guard !hasPrimedSession, authorizationStatus == .authorized else { return }
        do {
            var request = MusicCatalogSearchRequest(term: "music", types: [Song.self])
            request.limit = 1
            guard let song = try await request.response().songs.first else {
                NSLog("[MonoSync] 프라이밍용 카탈로그 곡 없음")
                return
            }
            player.queue = ApplicationMusicPlayer.Queue(for: [song])
            try await player.prepareToPlay()
            hasPrimedSession = true
            NSLog("[MonoSync] ✅ 재생 세션 프라이밍 완료")
        } catch {
            NSLog("[MonoSync] ⚠️ 재생 세션 프라이밍 실패: \(String(describing: error))")
        }
    }

    func play(track: TrackSnapshot, startTime: TimeInterval = 0) async throws {
#if targetEnvironment(simulator)
        _ = startTime
        throw AppleMusicPlaybackError.realDeviceRequired
#else
        if authorizationStatus != .authorized {
            await requestAuthorization()
            if authorizationStatus != .authorized {
                throw AppleMusicPlaybackError.authorizationRequired
            }
        }
        await primePlaybackSessionIfNeeded()

        guard let song = try await resolveSong(for: track) else {
            throw AppleMusicPlaybackError.songNotFound
        }

        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        player.playbackTime = max(0, startTime)
        try await player.play()
#endif
    }

    func play(tracks: [TrackSnapshot], startIndex: Int = 0, startTime: TimeInterval = 0) async throws {
#if targetEnvironment(simulator)
        _ = tracks
        _ = startIndex
        _ = startTime
        throw AppleMusicPlaybackError.realDeviceRequired
#else
        if authorizationStatus != .authorized {
            await requestAuthorization()
            if authorizationStatus != .authorized {
                throw AppleMusicPlaybackError.authorizationRequired
            }
        }
        await primePlaybackSessionIfNeeded()

        let resolvedSongs = try await resolveSongs(for: tracks)
        guard !resolvedSongs.isEmpty else {
            throw AppleMusicPlaybackError.songNotFound
        }

        try await playSongsColdSafe(resolvedSongs, startIndex: startIndex, startTime: startTime)
#endif
    }

    func play(album: AlbumSnapshot, startIndex: Int = 0, startTime: TimeInterval = 0) async throws -> [TrackSnapshot] {
#if targetEnvironment(simulator)
        _ = album
        _ = startIndex
        _ = startTime
        throw AppleMusicPlaybackError.realDeviceRequired
#else
        if authorizationStatus != .authorized {
            await requestAuthorization()
            if authorizationStatus != .authorized {
                throw AppleMusicPlaybackError.authorizationRequired
            }
        }
        await primePlaybackSessionIfNeeded()

        if album.id.hasPrefix("monosync-playlist-album:") {
            let sourceID = album.id.replacingOccurrences(of: "monosync-playlist-album:", with: "")
            if sourceID.hasPrefix("mediaplayer-playlist:") {
                let playlistTracks = try await AppleMusicMediaLibraryLoader.tracks(sourceID: sourceID)
                guard !playlistTracks.isEmpty else {
                    throw AppleMusicPlaybackError.songNotFound
                }

                NSLog("[MonoSync] play(album:) MediaPlayer 플레이리스트 \(playlistTracks.count)곡 재생")
                try await play(tracks: playlistTracks, startIndex: startIndex, startTime: startTime)
                return playlistTracks
            }

            let songs = try await songsForLibraryPlaylist(sourceID: sourceID)
            guard !songs.isEmpty else {
                throw AppleMusicPlaybackError.songNotFound
            }

            NSLog("[MonoSync] play(album:) Apple Music 플레이리스트 \(songs.count)곡 직접 재생")
            try await playSongsColdSafe(songs, startIndex: startIndex, startTime: startTime)
            return songs.map(TrackSnapshot.init(song:))
        }

        // 앨범 단위 일괄 해석(.with(.tracks) at 재생)을 사용하지 않습니다.
        // 모든 앨범/플레이리스트는 담는 시점에 album.tracks가 채워지므로, 친구 곡 경로와
        // 동일하게 트랙 단위로 재생합니다. 비어 있으면 그때만 한 번 로드합니다.
        var albumTracks = album.tracks
        if albumTracks.isEmpty {
            albumTracks = (try? await tracks(in: album)) ?? []
        }
        guard !albumTracks.isEmpty else {
            throw AppleMusicPlaybackError.songNotFound
        }
        NSLog("[MonoSync] play(album:) \(albumTracks.count)곡 트랙 단위 재생")
        try await play(tracks: albumTracks, startIndex: startIndex, startTime: startTime)
        return albumTracks
#endif
    }

    /// 콜드 상태의 ApplicationMusicPlayer는 다중 곡 큐로는 재생 연결이 establish되지 않는
    /// 경우가 있습니다(_establishConnectionIfNeeded timeout). 친구들의 단일 곡 재생처럼
    /// 먼저 단일 곡으로 큐를 시작해 연결을 깨운 뒤, 나머지 곡을 큐에 이어붙입니다.
    private func playSongsColdSafe(_ songs: [Song], startIndex: Int, startTime: TimeInterval) async throws {
        guard !songs.isEmpty else { throw AppleMusicPlaybackError.songNotFound }
        let safe = min(max(0, startIndex), songs.count - 1)

        player.queue = ApplicationMusicPlayer.Queue(for: [songs[safe]])
        player.playbackTime = max(0, startTime)
        try await player.play()
        NSLog("[MonoSync] ▶️ playSongsColdSafe: 1차 play 후 playbackStatus=\(player.state.playbackStatus)")

        // 콜드 연결은 첫 play()에서 establish만 되고 재생이 시작되지 않는 경우가 있습니다.
        // 실제로 재생 중이 아니면 잠깐 뒤 한 번 더 시도합니다.
        var attempt = 0
        while player.state.playbackStatus != .playing, attempt < 3 {
            attempt += 1
            try? await Task.sleep(for: .milliseconds(400))
            try? await player.play()
            NSLog("[MonoSync] ▶️ playSongsColdSafe: 재시도 \(attempt) 후 playbackStatus=\(player.state.playbackStatus)")
        }

        let rest = Array(songs[(safe + 1)...])
        if !rest.isEmpty {
            try? await player.queue.insert(rest, position: .tail)
        }
        NSLog("[MonoSync] ▶️ playSongsColdSafe: \(rest.count)곡 큐에 추가 완료, playbackStatus=\(player.state.playbackStatus)")
    }

    func pause() async throws {
        player.pause()
    }

    func resume(startTime: TimeInterval? = nil) async throws {
#if targetEnvironment(simulator)
        _ = startTime
        throw AppleMusicPlaybackError.realDeviceRequired
#else
        if authorizationStatus != .authorized {
            await requestAuthorization()
            if authorizationStatus != .authorized {
                throw AppleMusicPlaybackError.authorizationRequired
            }
        }
        await primePlaybackSessionIfNeeded()

        if let startTime {
            player.playbackTime = max(0, startTime)
        }
        try await player.play()
#endif
    }

    func searchSongs(term: String) async throws -> [TrackSnapshot] {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return [] }

        var searchRequest = MusicCatalogSearchRequest(term: trimmedTerm, types: [Song.self])
        searchRequest.limit = 12
        let response = try await searchRequest.response()
        return response.songs.map(TrackSnapshot.init(song:))
    }

    func searchAlbums(term: String) async throws -> [AlbumSnapshot] {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return [] }

        var searchRequest = MusicCatalogSearchRequest(term: trimmedTerm, types: [Album.self, Song.self])
        searchRequest.limit = 12
        let response = try await searchRequest.response()

        var finalAlbums: [Album] = Array(response.albums)
        var seenIDs: Set<String> = Set(finalAlbums.map(\.id.rawValue))
        
        let topSongs = response.songs.prefix(5)
        for song in topSongs {
            do {
                let songWithAlbums = try await song.with([.albums])
                if let songAlbums = songWithAlbums.albums {
                    for album in songAlbums {
                        if !seenIDs.contains(album.id.rawValue) {
                            finalAlbums.append(album)
                            seenIDs.insert(album.id.rawValue)
                        }
                    }
                }
            } catch {
                continue
            }
        }

        return finalAlbums.prefix(15).map { AlbumSnapshot(album: $0, trackCount: $0.trackCount) }
    }

    func fetchArtist(name: String) async throws -> ArtistSnapshot {
        try await ensureMusicAccess()
        
        var searchRequest = MusicCatalogSearchRequest(term: name, types: [Artist.self])
        searchRequest.limit = 1
        let response = try await searchRequest.response()
        
        guard let firstArtist = response.artists.first else {
            throw AppleMusicPlaybackError.songNotFound
        }
        
        let detailedArtist = try await firstArtist.with([.albums, .similarArtists])
        return ArtistSnapshot(artist: detailedArtist)
    }

    func libraryPlaylists() async throws -> [MusicCollectionSnapshot] {
        try await ensureMusicAccess()

        let mediaPlaylists = try await AppleMusicMediaLibraryLoader.playlists()
        if !mediaPlaylists.isEmpty {
            NSLog("[MonoSync] MediaPlayer 플레이리스트 \(mediaPlaylists.count)개 로드")
            return mediaPlaylists
        }

        // 라이브러리 요청은 메인 스레드를 붙잡으므로 반드시 메인 액터 밖에서 실행합니다.
        let items = try await Task.detached(priority: .userInitiated) { () -> [Playlist] in
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 20
            request.sort(by: \.name, ascending: true)
            let response = try await request.response()
            return Array(response.items)
        }.value

        for playlist in items {
            cachedLibraryPlaylists[playlist.id.rawValue] = playlist
        }

        return items.map(MusicCollectionSnapshot.init(playlist:))
    }

    func tracks(in playlist: MusicCollectionSnapshot) async throws -> [TrackSnapshot] {
        try await ensureMusicAccess()
        if playlist.sourceID.hasPrefix("mediaplayer-playlist:") {
            return try await AppleMusicMediaLibraryLoader.tracks(sourceID: playlist.sourceID)
        }

        let songs = try await songsForLibraryPlaylist(sourceID: playlist.sourceID)
        return songs.map(TrackSnapshot.init(song:))
    }

    func tracks(in album: AlbumSnapshot) async throws -> [TrackSnapshot] {
        if album.id.hasPrefix("monosync-playlist-album:") {
            if !album.tracks.isEmpty {
                return album.tracks
            }
            try await ensureMusicAccess()
            let sourceID = album.id.replacingOccurrences(of: "monosync-playlist-album:", with: "")
            if sourceID.hasPrefix("mediaplayer-playlist:") {
                let tracks = try await AppleMusicMediaLibraryLoader.tracks(sourceID: sourceID)
                return tracks.isEmpty ? album.tracks : tracks
            }

            let songs = try await songsForLibraryPlaylist(sourceID: sourceID)
            let tracks = songs.map(TrackSnapshot.init(song:))
            return tracks.isEmpty ? album.tracks : tracks
        }

        let rawID = album.id.replacingOccurrences(of: "applemusic-album:", with: "")
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(rawID))
        let response = try await request.response()
        guard let catalogAlbum = response.items.first else { return album.tracks }

        let albumWithTracks = try await catalogAlbum.with(.tracks)
        return albumWithTracks.tracks?.compactMap(TrackSnapshot.init(track:)) ?? album.tracks
    }

    func recentlyPlayedTracks() async throws -> [TrackSnapshot] {
        try await ensureMusicAccess()

        let items = try await Task.detached(priority: .userInitiated) { () -> [Song] in
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = 20
            let response = try await request.response()
            return Array(response.items)
        }.value
        return items.map(TrackSnapshot.init(song:))
    }

    func currentSnapshot() -> MusicPlayerSnapshot {
        MusicPlayerSnapshot(
            track: player.queue.currentEntry?.snapshot,
            position: player.playbackTime,
            playbackState: player.state.playbackStatus.monoPlaybackState
        )
    }

    private func refreshSubscription() async {
        do {
            let subscription = try await MusicSubscription.current
            canPlayCatalogContent = subscription.canPlayCatalogContent
            #if DEBUG
            print("[MonoSync] 구독 확인: canPlayCatalogContent=\(subscription.canPlayCatalogContent), hasActiveSubscription=\(subscription.canBecomeSubscriber == false)")
            #endif
        } catch {
            // -7013 등 계정 접근 실패가 여기서 잡힙니다.
            canPlayCatalogContent = true
            #if DEBUG
            print("[MonoSync] 구독 확인 실패(MusicKit 프로비저닝/계정 문제 의심):", String(describing: error))
            #endif
        }
    }

    private func ensureMusicAccess() async throws {
        if authorizationStatus != .authorized {
            await requestAuthorization()
            if authorizationStatus != .authorized {
                throw AppleMusicPlaybackError.authorizationRequired
            }
        }
        await primePlaybackSessionIfNeeded()
    }

    private func songsForLibraryPlaylist(sourceID: String) async throws -> [Song] {
        let rawID = sourceID.replacingOccurrences(of: "applemusic-playlist:", with: "")
        if let cached = cachedLibraryPlaylists[rawID] {
            return try await withMusicTimeout(seconds: 10) { () -> [Song] in
                let loaded = try await cached.with(.tracks)
                return loaded.tracks?.compactMap(\.songValue) ?? []
            }
        }

        return try await withMusicTimeout(seconds: 10) {
            try await AppleMusicLibraryTrackLoader.playlistSongs(sourceID: sourceID)
        }
    }

    private func resolveSong(for track: TrackSnapshot) async throws -> Song? {
        let rawID = track.id.replacingOccurrences(of: "applemusic:", with: "")
        if rawID.allSatisfy(\.isNumber) {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(rawID))
            let response = try await request.response()
            if let song = response.items.first {
                return song
            }
        }

        var searchRequest = MusicCatalogSearchRequest(
            term: "\(track.title) \(track.artistName)",
            types: [Song.self]
        )
        searchRequest.limit = 1
        let response = try await searchRequest.response()
        return response.songs.first
    }

    private func resolveSongs(for tracks: [TrackSnapshot]) async throws -> [Song] {
        // 곡별 카탈로그 검색을 병렬로 수행하고 원래 순서를 보존합니다.
        try await withThrowingTaskGroup(of: (Int, Song?).self) { group in
            for (index, track) in tracks.enumerated() {
                group.addTask { (index, try? await self.resolveSong(for: track)) }
            }
            var indexed: [(Int, Song)] = []
            for try await (index, song) in group {
                if let song { indexed.append((index, song)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

private extension MusicKit.MusicPlayer.PlaybackStatus {
    var monoPlaybackState: PlaybackState {
        switch self {
        case .playing, .seekingForward, .seekingBackward:
            .playing
        case .paused, .interrupted:
            .paused
        case .stopped:
            .idle
        @unknown default:
            .idle
        }
    }
}

private extension MusicKit.MusicPlayer.Queue.Entry {
    var snapshot: TrackSnapshot? {
        switch item {
        case let .song(song):
            TrackSnapshot(song: song)
        default:
            nil
        }
    }
}

private struct AppleMusicLibraryTrackLoader {
    static func playlistTracks(sourceID: String) async throws -> [TrackSnapshot] {
        let songs = try await playlistSongs(sourceID: sourceID)
        return songs.map(TrackSnapshot.init(song:))
    }

    static func playlistSongs(sourceID: String) async throws -> [Song] {
        let rawID = sourceID.replacingOccurrences(of: "applemusic-playlist:", with: "")
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 1
        request.filter(matching: \.id, equalTo: MusicItemID(rawID))
        let response = try await request.response()
        guard let libraryPlaylist = response.items.first else { return [] }

        let playlistWithTracks = try await libraryPlaylist.with(.tracks)
        return playlistWithTracks.tracks?.compactMap(\.songValue) ?? []
    }
}

private enum AppleMusicMediaLibraryLoader {
    static func playlists() async throws -> [MusicCollectionSnapshot] {
        try await ensureAuthorization()

        let playlists = (MPMediaQuery.playlists().collections as? [MPMediaPlaylist]) ?? []
        return playlists
            .filter { !$0.items.isEmpty }
            .prefix(30)
            .map { playlist in
                let representativeMusicItem = playlist.items.first(where: { $0.mediaType.contains(.music) })
                    ?? playlist.representativeItem
                let trackCount = playlist.items.filter { $0.mediaType.contains(.music) }.count
                let firstTitle = representativeMusicItem?.title ?? "첫 곡"
                let subtitle = trackCount > 1 ? "\(firstTitle) 외 \(trackCount - 1)곡" : firstTitle
                return MusicCollectionSnapshot(
                    id: "mediaplayer-playlist:\(playlist.persistentID)",
                    sourceID: "mediaplayer-playlist:\(playlist.persistentID)",
                    title: playlist.name ?? "Apple Music 플레이리스트",
                    subtitle: subtitle,
                    artworkURL: artworkURL(for: representativeMusicItem, cacheKey: "playlist-\(playlist.persistentID)")
                )
            }
    }

    static func tracks(sourceID: String) async throws -> [TrackSnapshot] {
        try await ensureAuthorization()

        let rawID = sourceID.replacingOccurrences(of: "mediaplayer-playlist:", with: "")
        guard let persistentID = MPMediaEntityPersistentID(rawID) else { return [] }
        let playlists = (MPMediaQuery.playlists().collections as? [MPMediaPlaylist]) ?? []
        guard let playlist = playlists.first(where: { $0.persistentID == persistentID }) else { return [] }

        return playlist.items.compactMap { item in
            guard item.mediaType.contains(.music) else { return nil }
            guard let title = item.title, !title.isEmpty else { return nil }
            let storeID = item.playbackStoreID
            let fallbackID = item.persistentID == 0 ? UUID().uuidString : "library:\(item.persistentID)"
            let id = storeID.isEmpty ? fallbackID : "applemusic:\(storeID)"
            return TrackSnapshot(
                id: id,
                title: title,
                artistName: item.artist ?? "알 수 없는 아티스트",
                albumTitle: item.albumTitle ?? "Apple Music",
                artworkURL: artworkURL(for: item, cacheKey: "track-\(item.persistentID)"),
                duration: item.playbackDuration > 0 ? item.playbackDuration : 1
            )
        }
    }

    private static func ensureAuthorization() async throws {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
            }
            if status == .authorized {
                return
            }
            throw AppleMusicPlaybackError.authorizationRequired
        case .denied, .restricted:
            throw AppleMusicPlaybackError.authorizationRequired
        @unknown default:
            throw AppleMusicPlaybackError.authorizationRequired
        }
    }

    private static func artworkURL(for item: MPMediaItem?, cacheKey: String) -> URL? {
        guard let image = item?.artwork?.image(at: CGSize(width: 600, height: 600)),
              let data = image.squareCroppedPNGData()
        else {
            return nil
        }

        do {
            let directory = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("MonoSyncArtwork", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("\(cacheKey).png")
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: .atomic)
            }
            return fileURL
        } catch {
            NSLog("[MonoSync] MediaPlayer artwork cache 실패: \(String(describing: error))")
            return nil
        }
    }
}

private extension UIImage {
    func squareCroppedPNGData() -> Data? {
        let side = min(size.width, size.height)
        guard side > 0 else { return pngData() }

        let cropRect = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { _ in
            draw(at: CGPoint(x: -cropRect.minX, y: -cropRect.minY))
        }
        return image.pngData()
    }
}

private extension Track {
    var songValue: Song? {
        switch self {
        case let .song(song):
            song
        case .musicVideo:
            nil
        @unknown default:
            nil
        }
    }
}

private extension TrackSnapshot {
    init(song: Song) {
        self.init(
            id: "applemusic:\(song.id.rawValue)",
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle ?? "Apple Music",
            artworkURL: song.artwork?.url(width: 600, height: 600),
            duration: song.duration ?? 1
        )
    }

    init?(track: Track) {
        switch track {
        case let .song(song):
            self.init(song: song)
        case .musicVideo:
            return nil
        @unknown default:
            return nil
        }
    }
}

private extension AlbumSnapshot {
    init(album: Album, trackCount: Int? = nil) {
        let releaseYear = album.releaseDate.map { String(Calendar.current.component(.year, from: $0)) }
        self.init(
            id: "applemusic-album:\(album.id.rawValue)",
            title: album.title,
            artistName: album.artistName,
            artistID: nil, // We rely on artistName for searching
            releaseYear: releaseYear,
            artworkURL: album.artwork?.url(width: 800, height: 800),
            tracks: album.tracks?.compactMap(TrackSnapshot.init(track:)) ?? [],
            trackCount: trackCount ?? album.tracks?.count,
            recordLabelName: album.recordLabelName,
            editorialNotes: album.editorialNotes?.standard ?? album.editorialNotes?.short,
            genreNames: !album.genreNames.isEmpty ? album.genreNames : nil,
            isCompilation: album.isCompilation
        )
    }
}

private extension MusicCollectionSnapshot {
    init(playlist: Playlist) {
        self.init(
            id: "applemusic-playlist:\(playlist.id.rawValue)",
            sourceID: "applemusic-playlist:\(playlist.id.rawValue)",
            title: playlist.name,
            subtitle: playlist.curatorName ?? "내 Apple Music 플레이리스트",
            artworkURL: playlist.artwork?.url(width: 600, height: 600)
        )
    }
}

private extension ArtistSnapshot {
    init(artist: Artist) {
        self.init(
            id: "applemusic-artist:\(artist.id.rawValue)",
            name: artist.name,
            artworkURL: artist.artwork?.url(width: 800, height: 800),
            editorialNotes: artist.editorialNotes?.standard ?? artist.editorialNotes?.short,
            albums: artist.albums?.compactMap { AlbumSnapshot(album: $0) } ?? [],
            similarArtists: artist.similarArtists?.compactMap { ArtistSnapshot(artist: $0) } ?? []
        )
    }
}
