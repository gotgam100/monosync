import Foundation
import MusicKit

enum AppleMusicPlaybackError: LocalizedError {
    case realDeviceRequired
    case authorizationRequired
    case subscriptionRequired
    case songNotFound

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
        }
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

    @discardableResult
    func requestAuthorization() async -> MusicAuthorization.Status {
        authorizationStatus = await MusicAuthorization.request()
        if authorizationStatus == .authorized {
            await refreshSubscription()
        }
        return authorizationStatus
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

        let resolvedSongs = try await resolveSongs(for: tracks)
        guard !resolvedSongs.isEmpty else {
            throw AppleMusicPlaybackError.songNotFound
        }

        let safeStartIndex = min(max(0, startIndex), resolvedSongs.count - 1)
        player.queue = ApplicationMusicPlayer.Queue(
            for: resolvedSongs,
            startingAt: resolvedSongs[safeStartIndex]
        )
        player.playbackTime = max(0, startTime)
        try await player.play()
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

        let songs: [Song]
        if album.id.hasPrefix("monosync-playlist-album:") {
            let sourceID = album.id.replacingOccurrences(of: "monosync-playlist-album:", with: "")
            let rawID = sourceID.replacingOccurrences(of: "applemusic-playlist:", with: "")
            if let cached = cachedLibraryPlaylists[rawID] {
                let loaded = try await cached.with(.tracks)
                songs = loaded.tracks?.compactMap(\.songValue) ?? []
            } else {
                songs = try await AppleMusicLibraryTrackLoader.playlistSongs(sourceID: sourceID)
            }
        } else if album.id.hasPrefix("applemusic-album:") {
            songs = try await AppleMusicLibraryTrackLoader.catalogAlbumSongs(albumID: album.id)
        } else {
            let tracks = album.tracks
            try await play(tracks: tracks, startIndex: startIndex, startTime: startTime)
            return tracks
        }

        guard !songs.isEmpty else {
            throw AppleMusicPlaybackError.songNotFound
        }

        let safeStartIndex = min(max(0, startIndex), songs.count - 1)
        player.queue = ApplicationMusicPlayer.Queue(
            for: songs,
            startingAt: songs[safeStartIndex]
        )
        player.playbackTime = max(0, startTime)
        try await player.play()
        return songs.map(TrackSnapshot.init(song:))
#endif
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

        var searchRequest = MusicCatalogSearchRequest(term: trimmedTerm, types: [Album.self])
        searchRequest.limit = 12
        let response = try await searchRequest.response()

        var albums: [AlbumSnapshot] = []
        for album in response.albums {
            let albumWithTracks = try await album.with(.tracks)
            albums.append(AlbumSnapshot(album: albumWithTracks))
        }
        return albums
    }

    func libraryPlaylists() async throws -> [MusicCollectionSnapshot] {
        try await ensureMusicAccess()

        var request = MusicLibraryRequest<Playlist>()
        request.limit = 20
        request.sort(by: \.name, ascending: true)
        let response = try await request.response()

        for playlist in response.items {
            cachedLibraryPlaylists[playlist.id.rawValue] = playlist
        }

        return response.items.map(MusicCollectionSnapshot.init(playlist:))
    }

    func tracks(in playlist: MusicCollectionSnapshot) async throws -> [TrackSnapshot] {
        try await ensureMusicAccess()
        let rawID = playlist.sourceID.replacingOccurrences(of: "applemusic-playlist:", with: "")

        if let cached = cachedLibraryPlaylists[rawID] {
            let loaded = try await cached.with(.tracks)
            let songs = loaded.tracks?.compactMap(\.songValue) ?? []
            return songs.map(TrackSnapshot.init(song:))
        }

        return try await AppleMusicLibraryTrackLoader.playlistTracks(sourceID: playlist.sourceID)
    }

    func tracks(in album: AlbumSnapshot) async throws -> [TrackSnapshot] {
        if album.id.hasPrefix("monosync-playlist-album:") {
            try await ensureMusicAccess()
            let sourceID = album.id.replacingOccurrences(of: "monosync-playlist-album:", with: "")
            let tracks = try await AppleMusicLibraryTrackLoader.playlistTracks(sourceID: sourceID)
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

        var request = MusicRecentlyPlayedRequest<Song>()
        request.limit = 20
        let response = try await request.response()
        return response.items.map(TrackSnapshot.init(song:))
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
        var songs: [Song] = []
        for track in tracks {
            if let song = try await resolveSong(for: track) {
                songs.append(song)
            }
        }
        return songs
    }
}

private extension MusicPlayer.PlaybackStatus {
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

private extension MusicPlayer.Queue.Entry {
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

    static func catalogAlbumSongs(albumID: AlbumSnapshot.ID) async throws -> [Song] {
        let rawID = albumID.replacingOccurrences(of: "applemusic-album:", with: "")
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(rawID))
        let response = try await request.response()
        guard let catalogAlbum = response.items.first else { return [] }

        let albumWithTracks = try await catalogAlbum.with(.tracks)
        return albumWithTracks.tracks?.compactMap(\.songValue) ?? []
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
    init(album: Album) {
        self.init(
            id: "applemusic-album:\(album.id.rawValue)",
            title: album.title,
            artistName: album.artistName,
            releaseYear: album.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
            artworkURL: album.artwork?.url(width: 800, height: 800),
            tracks: album.tracks?.compactMap(TrackSnapshot.init(track:)) ?? []
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
