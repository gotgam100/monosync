import SwiftUI

struct TrackSearchView: View {
    @Environment(AppModel.self) private var appModel

    enum SearchMode: String, CaseIterable {
        case album = "앨범 찾기"
        case memo = "메모 찾기"
    }

    @State private var searchMode: SearchMode = .album
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedAlbumForInfo: AlbumSnapshot?
    @FocusState private var isSearchFocused: Bool
    @State private var dragOffset: CGFloat = 0
    
    let isShowing: Bool
    let onClose: () -> Void
    let onDone: () -> Void

    private var filteredMemos: [AlbumMemo] {
        let memos = Array(appModel.albumMemos.values).sorted(by: { $0.updatedAt > $1.updatedAt })
        if query.isEmpty {
            return memos
        } else {
            return memos.filter { $0.text.localizedCaseInsensitiveContains(query) || $0.album.title.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text("찾기".localized(to: appModel.selectedLanguage))
                        .font(MonoTheme.point)
                        .foregroundStyle(MonoTheme.paper)
                    Spacer()
                    Picker("검색 모드".localized(to: appModel.selectedLanguage), selection: $searchMode) {
                        ForEach(SearchMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue.localized(to: appModel.selectedLanguage)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MonoTheme.paper)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(FixedPressButtonStyle())
                    .accessibilityLabel("닫기")
                }
                
                Text((searchMode == .album ? "앨범 단위로만 불러올 수 있습니다." : "나만 볼 수 있는 메모를 검색하세요.").localized(to: appModel.selectedLanguage))
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MonoTheme.mist)
                
                TextField((searchMode == .album ? "아티스트, 앨범 등" : "나의 메모 내용").localized(to: appModel.selectedLanguage), text: $query)
                    .font(MonoTheme.body)
                    .foregroundStyle(MonoTheme.paper)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !query.isEmpty { search() }
                    }
                    .onChange(of: query) { _, newValue in
                        if newValue.isEmpty {
                            appModel.albumSearchResults.removeAll()
                        } else {
                            scheduleSearch(for: newValue)
                        }
                    }
                    .submitLabel(.search)
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(MonoTheme.mist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(MonoTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text(searchMode == .album ? appModel.searchStatusText.localized(to: appModel.selectedLanguage) : "%d개의 메모".localized(to: appModel.selectedLanguage, filteredMemos.count))
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                Spacer()
                if searchMode == .album && appModel.isSearchingTracks {
                    ProgressView()
                        .tint(MonoTheme.accent)
                }
            }

            ScrollView {
                if searchMode == .memo {
                    LazyVStack(spacing: 8) {
                        if filteredMemos.isEmpty {
                            Text((query.isEmpty ? "작성한 메모가 없습니다." : "검색 결과가 없습니다.").localized(to: appModel.selectedLanguage))
                                .font(MonoTheme.body)
                                .foregroundStyle(MonoTheme.mist)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredMemos) { memo in
                                AlbumMemoRow(
                                    memo: memo,
                                    isInDrawer: isAlbumInDrawer(memo.album),
                                    onAdd: { addAlbum(memo.album) },
                                    onLongPress: { selectedAlbumForInfo = memo.album }
                                )
                            }
                        }
                    }
                } else {
                    if query.isEmpty && !appModel.recentSearchTerms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                 Text("최근 검색어".localized(to: appModel.selectedLanguage))
                                    .font(Font.custom("Paperlogy-7Bold", size: 14))
                                    .foregroundStyle(MonoTheme.mist)
                                Spacer()
                                Button("전체 삭제".localized(to: appModel.selectedLanguage)) {
                                    appModel.recentSearchTerms.removeAll()
                                }
                                .font(Font.custom("NotoSansKR-Regular", size: 12))
                                .foregroundStyle(MonoTheme.mist)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            
                            ForEach(appModel.recentSearchTerms, id: \.self) { term in
                                HStack {
                                    Text(term)
                                        .font(Font.custom("NotoSansKR-Regular", size: 15))
                                        .foregroundStyle(MonoTheme.paper)
                                    Spacer()
                                    Button {
                                        appModel.recentSearchTerms.removeAll(where: { $0 == term })
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(MonoTheme.mist)
                                    }
                                    .padding(.leading, 12)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.045))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    query = term
                                    search()
                                }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(appModel.albumSearchResults) { album in
                                AlbumResultRow(
                                    album: album,
                                    isInDrawer: isAlbumInDrawer(album),
                                    onAdd: { addAlbum(album) },
                                    onLongPress: { selectedAlbumForInfo = album }
                                )
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonoTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                        
                        // 찾기창을 아래로 드래그하여 쓸어내리면 키보드를 즉시 내림
                        if isSearchFocused {
                            isSearchFocused = false
                        }
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        onClose()
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
        )
        .preferredColorScheme(.dark)
        .sheet(item: $selectedAlbumForInfo) { album in
            AlbumInfoSheetView(album: album)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: isShowing) { _, newValue in
            if newValue {
                isSearchFocused = true
            } else {
                isSearchFocused = false
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func search() {
        guard searchMode == .album else { return }
        searchTask?.cancel()
        Task { await appModel.searchTracks(term: query, saveRecentSearch: true) }
    }

    private func scheduleSearch(for term: String) {
        guard searchMode == .album else { return }
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            await appModel.searchTracks(term: term)
        }
    }

    private func addAlbum(_ album: AlbumSnapshot) {
        if appModel.drawerAlbums.contains(where: { $0.id == album.id }) {
            appModel.deleteDrawerAlbum(id: album.id, title: album.title)
            appModel.searchStatusText = "%@ 선택을 취소했어요".localized(to: appModel.selectedLanguage, album.title)
        } else {
            Task { await appModel.addSearchAlbumToDrawer(album) }
        }
    }

    private func isAlbumInDrawer(_ album: AlbumSnapshot) -> Bool {
        appModel.drawerAlbums.contains(where: { $0.id == album.id })
    }
}

private struct AlbumResultRow: View {
    @Environment(AppModel.self) private var appModel
    let album: AlbumSnapshot
    let isInDrawer: Bool
    let onAdd: () -> Void
    let onLongPress: () -> Void

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
            .accessibilityLabel((isInDrawer ? "서랍 선택 취소" : "서랍에 담기").localized(to: appModel.selectedLanguage))
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 50, perform: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            onLongPress()
        })
    }
}

private struct FixedPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(nil, value: configuration.isPressed)
    }
}

struct AlbumMemoRow: View {
    @Environment(AppModel.self) private var appModel
    let memo: AlbumMemo
    let isInDrawer: Bool
    let onAdd: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(url: memo.album.artworkURL, cornerRadius: 4)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.album.title)
                    .font(Font.custom("Paperlogy-7Bold", size: 14))
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                
                Text(memo.text)
                    .font(Font.custom("NotoSansKR-Regular", size: 13))
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(2)
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
            .accessibilityLabel((isInDrawer ? "서랍 선택 취소" : "서랍에 담기").localized(to: appModel.selectedLanguage))
        }
        .padding(12)
        .background(MonoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onLongPressGesture {
            onLongPress()
        }
    }
}
