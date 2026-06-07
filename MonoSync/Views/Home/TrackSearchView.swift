import SwiftUI

struct TrackSearchView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var addedAlbumIDs: Set<AlbumSnapshot.ID> = []
    @FocusState private var isSearchFocused: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MonoTheme.mist)

                TextField("곡 제목, 앨범, 아티스트", text: $query)
                    .font(MonoTheme.body)
                    .foregroundStyle(MonoTheme.paper)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit(search)
                    .onChange(of: query) { _, newValue in
                        scheduleSearch(for: newValue)
                    }

                Button(action: search) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MonoTheme.paper)
                        .frame(width: 32, height: 32)
                        .background(MonoTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("검색")
            }
            .padding(12)
            .background(MonoTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text(appModel.searchStatusText)
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                Spacer()
                if appModel.isSearchingTracks {
                    ProgressView()
                        .tint(MonoTheme.accent)
                }
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appModel.albumSearchResults) { album in
                        AlbumResultRow(
                            album: album,
                            isInDrawer: isAlbumInDrawer(album),
                            onAdd: {
                                addAlbum(album)
                            }
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(MonoTheme.ink.ignoresSafeArea())
        .navigationTitle("앨범 찾기")
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                    onDone()
                } label: {
                    Image(systemName: "checkmark")
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(addedAlbumIDs.isEmpty ? MonoTheme.mist : MonoTheme.paper)
                        .frame(width: 34, height: 34)
                        .background(addedAlbumIDs.isEmpty ? Color.white.opacity(0.04) : MonoTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(addedAlbumIDs.isEmpty)
                .accessibilityLabel("서랍으로 이동")
            }
        }
        .preferredColorScheme(.dark)
        .task {
            isSearchFocused = true
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func search() {
        searchTask?.cancel()
        Task { await appModel.searchTracks(term: query) }
    }

    private func scheduleSearch(for term: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            await appModel.searchTracks(term: term)
        }
    }

    private func addAlbum(_ album: AlbumSnapshot) {
        appModel.addAlbumToDrawer(album)
        addedAlbumIDs.insert(album.id)
    }

    private func isAlbumInDrawer(_ album: AlbumSnapshot) -> Bool {
        addedAlbumIDs.contains(album.id) || appModel.drawerAlbums.contains(where: { $0.id == album.id })
    }
}

private struct AlbumResultRow: View {
    let album: AlbumSnapshot
    let isInDrawer: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(url: album.artworkURL)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)

                Text(album.artistName)
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)

                Text(album.albumFactText)
                    .font(Font.custom("Paperlogy-4Regular", size: 11))
                    .foregroundStyle(MonoTheme.mist.opacity(0.82))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: isInDrawer ? "tray.full.fill" : "tray.and.arrow.down")
                    .foregroundStyle(isInDrawer ? MonoTheme.paper : MonoTheme.mist)
                    .frame(width: 34, height: 34)
                    .background(isInDrawer ? MonoTheme.accent : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isInDrawer)
            .accessibilityLabel(isInDrawer ? "서랍에 담김" : "서랍에 담기")
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
