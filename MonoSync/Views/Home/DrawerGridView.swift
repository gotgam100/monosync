import SwiftUI

/// 플레이어 상단의 서랍. 앨범 카드가 중앙을 기준으로 겹겹이 쌓인 캐러셀(Card Stack) 방식입니다.
/// 가운데 카드를 아래로 쓸어내리면(Swipe Down) 카세트에 삽입되고,
/// 빈 자리의 '+' 카드를 누르면 앨범 찾기로 연결됩니다.
struct DrawerStackView: View {
    @Environment(AppModel.self) private var appModel
    let albums: [AlbumSnapshot]
    let activeAlbumID: String?
    let isPlaying: Bool
    let onAddAlbum: () -> Void
    let onDeleteAlbum: (AlbumSnapshot) -> Void
    let onInsertAlbum: (AlbumSnapshot) -> Void

    @State private var albumForInfo: AlbumSnapshot?
    @State private var scrolledID: String?
    @State private var isEditingStack: Bool = false

    private var cells: [DrawerCell] {
        var items: [DrawerCell] = albums.map { .album($0) }
        items.append(.add)
        return items
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            
            // 앨범 아트 크기를 화면에서 텍스트가 잘리지 않는 선에서 최대한으로 키움
            let cardWidth = min(w * 0.75, h - 55)
            let cardHeight = cardWidth + 50

            let selectedIndex = cells.firstIndex(where: { $0.id == scrolledID }) ?? 0

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -cardWidth * 0.65) { // 더 여러장이 보이도록 겹침 간격을 좁힘
                        ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                            cellView(cell, cardWidth: cardWidth, cardHeight: cardHeight)
                                .frame(width: cardWidth, height: cardHeight)
                                .scrollTransition(axis: .horizontal) { view, phase in
                                    view
                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.75)
                                        .opacity(phase.isIdentity ? 1.0 : 0.6)
                                        .blur(radius: phase.isIdentity ? 0 : 8)
                                        // 좌우로 갈수록 살짝 회전하는 3D 커버플로우 효과
                                        .rotation3DEffect(.degrees(phase.value * -25), axis: (x: 0, y: 1, z: 0))
                                }
                                .zIndex(-Double(abs(index - selectedIndex)))
                                .id(cell.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 12) // 드래그 애니메이션을 위한 상하 여백
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .safeAreaPadding(.horizontal, (w - cardWidth) / 2) // 첫/마지막 카드가 가운데 오도록 패딩
                .scrollPosition(id: $scrolledID, anchor: .center)
                .onChange(of: scrolledID) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
                .onChange(of: isPlaying) {
                    if isPlaying, let activeID = activeAlbumID {
                        if cells.contains(where: { $0.id == activeID }) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                scrolledID = activeID
                            }
                        }
                    }
                }
                .onChange(of: appModel.drawerFocusTrigger) {
                    if appModel.prefersDrawerGrid, let activeID = activeAlbumID {
                        if cells.contains(where: { $0.id == activeID }) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                scrolledID = activeID
                            }
                        }
                    }
                }
                .onAppear {
                    if isPlaying, let activeID = activeAlbumID, cells.contains(where: { $0.id == activeID }) {
                        scrolledID = activeID
                    } else if scrolledID == nil {
                        scrolledID = cells.first?.id
                    }
                }
                // 찾기 화면에서 돌아올 때 스택이 중앙에 스냅되도록 복원합니다.
                .onChange(of: appModel.drawerSnapTrigger) {
                    guard let current = scrolledID else { return }
                    // scrollProxy를 사용해 애니메이션 없이 즉시 지정된 셀로 스크롤하여 흔들림 방지
                    scrollProxy.scrollTo(current, anchor: .center)
                }
            }
            .onChange(of: albums.count) { oldCount, newCount in
                // 앨범이 추가될 때 → 새로 추가된 앨범(마지막)으로 스크롤
                if newCount > oldCount, let lastAlbum = albums.last {
                    scrolledID = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            scrolledID = lastAlbum.id
                        }
                    }
                }
                // 앨범이 삭제될 때 → 현재 스크롤이 유효하지 않으면 첫 번째로
                else if newCount < oldCount {
                    if !cells.contains(where: { $0.id == scrolledID }) {
                        scrolledID = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                scrolledID = cells.first?.id
                            }
                        }
                    }
                }
            }
            } // end GeometryReader
            
            if isEditingStack {
                Button("확인".localized(to: appModel.selectedLanguage)) {
                    withAnimation { isEditingStack = false }
                }
                .buttonStyle(.borderedProminent)
                .tint(MonoTheme.accent)
                .foregroundStyle(Color.black)
                .font(Font.custom("NotoSansKR-Medium", size: 14))
                .padding(.top, 20)
                .padding(.trailing, 20)
                .transition(.opacity.combined(with: .scale))
            }
        } // end ZStack
        .sheet(item: $albumForInfo) { album in
            AlbumInfoSheetView(album: album)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func cellView(_ cell: DrawerCell, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let isCenter = cell.id == scrolledID

        switch cell {
        case let .album(album):
            let currentIndex = appModel.drawerAlbums.firstIndex(where: { $0.id == album.id }) ?? 0
            let canMoveLeft = currentIndex > 0
            let canMoveRight = currentIndex < appModel.drawerAlbums.count - 1

            AlbumStackCardView(
                album: album,
                isCenter: isCenter,
                isEditingStack: isEditingStack,
                onInfo: { albumForInfo = album },
                onEdit: { withAnimation { isEditingStack = true } },
                onDelete: { onDeleteAlbum(album) },
                onInsert: { onInsertAlbum(album) },
                onMoveLeft: canMoveLeft ? {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    let targetID = album.id
                    appModel.drawerAlbums.swapAt(currentIndex, currentIndex - 1)
                    scrolledID = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            scrolledID = targetID
                        }
                    }
                } : nil,
                onMoveRight: canMoveRight ? {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    let targetID = album.id
                    appModel.drawerAlbums.swapAt(currentIndex, currentIndex + 1)
                    scrolledID = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            scrolledID = targetID
                        }
                    }
                } : nil
            )
        case .add:
            VStack {
                AddCardView(action: onAddAlbum)
                    .frame(width: cardWidth, height: cardWidth)
                Spacer()
            }
            .frame(width: cardWidth, height: cardHeight)
        }
    }
}

private enum DrawerCell: Identifiable {
    case album(AlbumSnapshot)
    case add
    
    var id: String {
        switch self {
        case .album(let album): return album.id
        case .add: return "add_button"
        }
    }
}

private struct InsertedAlbumArtwork: View {
    let artworkURL: URL?
    let isInserted: Bool

    var body: some View {
        AlbumArtworkView(url: artworkURL, cornerRadius: 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isInserted ? MonoTheme.accent : Color.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
            .compositingGroup()
            .animation(nil, value: isInserted)
    }
}

/// 캐러셀에 들어가는 개별 앨범 카드 뷰
private struct AlbumStackCardView: View {
    @Environment(AppModel.self) private var appModel
    let album: AlbumSnapshot
    let isCenter: Bool
    let isEditingStack: Bool
    let onInfo: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onInsert: () -> Void
    let onMoveLeft: (() -> Void)?
    let onMoveRight: (() -> Void)?

    @State private var dragOffset: CGSize = .zero
    @State private var wiggleDegrees: Double = 0

    var body: some View {
        let isInserted = appModel.cassetteSideA?.id == album.id || appModel.cassetteSideB?.id == album.id

        VStack(spacing: 6) {
            ZStack(alignment: .center) {
                ZStack(alignment: .topTrailing) {
                    // 앨범 아트
                    InsertedAlbumArtwork(
                        artworkURL: album.artworkURL,
                        isInserted: isInserted
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 10)

                    // 앨범 정보 버튼 (가운데 있을 때만 활성화)
                    if isCenter && !isEditingStack {
                        Button(action: onInfo) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.white)
                                .padding(6)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(8)
                        .transition(.opacity)
                    }
                }
                
                if isEditingStack {
                    HStack {
                        if let onMoveLeft = onMoveLeft {
                            Button(action: onMoveLeft) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 40))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.white.opacity(0.95), Color.black.opacity(0.5))
                            }
                        }
                        Spacer()
                        if let onMoveRight = onMoveRight {
                            Button(action: onMoveRight) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 40))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color.white.opacity(0.95), Color.black.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // 앨범 제목과 발매연도
            VStack(spacing: -2) {
                Text(album.title)
                    .font(Font.custom("NotoSansKR-Medium", size: 14))
                    .foregroundStyle(MonoTheme.paper)
                    .lineLimit(1)
                Text(album.releaseYear ?? "연도 미상".localized(to: appModel.selectedLanguage))
                    .font(Font.custom("NotoSansKR-Regular", size: 11))
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }
            .opacity(isCenter ? 1.0 : 0.0) // 가운데 카드만 글씨가 보이도록 처리
        }
        // 제스처에 따른 이동
        .offset(y: dragOffset.height)
        .rotationEffect(.degrees(wiggleDegrees))
        .onChange(of: isEditingStack) {
            if isEditingStack {
                wiggleDegrees = 2
                withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                    wiggleDegrees = -2
                }
            } else {
                withAnimation {
                    wiggleDegrees = 0
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20) // 가로 스크롤 방해 방지
                .onChanged { value in
                    if isEditingStack { return }
                    // 가로 이동보다 세로 이동이 클 때만(쓸어내리기) 허용
                    if isCenter, value.translation.height > 0, value.translation.height > abs(value.translation.width) {
                        dragOffset.height = value.translation.height
                    }
                }
                .onEnded { value in
                    if isEditingStack { return }
                    if isCenter {
                        if value.translation.height > 80 {
                            // 임계값 이상 쓸어내리면 앨범 삽입
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset.height = 300 // 화면 아래로 날아가는 효과
                            }
                            // 날아간 후 원래 위치 복원 및 삽입 로직 실행
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onInsert()
                                dragOffset = .zero
                            }
                        } else {
                            // 원위치로 복귀
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
                }
        )
        .contextMenu {
            Button {
                onInfo()
            } label: {
                Label("앨범 정보".localized(to: appModel.selectedLanguage), systemImage: "info.circle")
            }
            Button {
                onEdit()
            } label: {
                Label("서랍 위치 변경".localized(to: appModel.selectedLanguage), systemImage: "arrow.up.arrow.down")
            }
            Button(role: .destructive, action: onDelete) {
                Label("서랍에서 삭제".localized(to: appModel.selectedLanguage), systemImage: "trash")
            }
        }
    }
}

/// 빈 자리 '+' 카드
private struct AddCardView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12)) // 배경이 뚫려있지 않게 채움
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .foregroundStyle(MonoTheme.mist.opacity(0.5))
                Image(systemName: "plus")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(MonoTheme.mist)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("앨범 찾기")
    }
}
