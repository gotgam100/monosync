import SwiftUI

struct YourStationView: View {
    @Environment(AppModel.self) private var appModel
    let onMenu: () -> Void
    
    @State private var searchText = ""
    
    private var filteredSpaces: [ListeningSpace] {
        if searchText.isEmpty {
            return appModel.friendSpaces
        } else {
            return appModel.friendSpaces.filter { space in
                let text = searchText.lowercased()
                return space.title.lowercased().contains(text) ||
                       space.owner.displayName.lowercased().contains(text) ||
                       space.owner.handle.lowercased().contains(text)
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: Bindable(appModel).yourStationNavigationPath) {
            VStack(alignment: .leading, spacing: 0) {
                MonoPageHeader(title: "유어스테이션".localized(to: appModel.selectedLanguage), subtitle: "친구들의 방송국".localized(to: appModel.selectedLanguage), onMenu: onMenu)
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 8) {
                        TextField("스테이션 이름, 닉네임 검색".localized(to: appModel.selectedLanguage), text: $searchText)
                            .font(Font.custom("NotoSansKR-Regular", size: 14))
                            .foregroundStyle(MonoTheme.paper)
                            .padding(12)
                            .background(Color.white.opacity(0.045))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 16)
                        if filteredSpaces.isEmpty {
                            Text(searchText.isEmpty ? "아직 추가된 친구가 없습니다.".localized(to: appModel.selectedLanguage) : "검색 결과가 없습니다.".localized(to: appModel.selectedLanguage))
                                .font(MonoTheme.bodyMedium)
                                .foregroundStyle(MonoTheme.mist)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredSpaces) { space in
                                NavigationLink(value: space) {
                                    FriendStationRow(space: space)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .contentShape(Rectangle())
            .onSwipeToChangeSection(current: .yourStation) { next in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    appModel.selectedSection = next
                }
            }
            .navigationDestination(for: ListeningSpace.self) { space in
                YourStationDetailView(space: space)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
    }
}

private struct FriendStationRow: View {
    @Environment(AppModel.self) private var appModel
    let space: ListeningSpace
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(space.isLive ? MonoTheme.live : MonoTheme.panel)
                .frame(width: 46, height: 46)
                .overlay {
                    Text(String(space.owner.displayName.prefix(1)))
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(space.owner.displayName)
                        .font(MonoTheme.bodyMedium)
                        .foregroundStyle(MonoTheme.paper)
                    
                    Text(space.isLive ? "방송 중".localized(to: appModel.selectedLanguage) : "오프라인".localized(to: appModel.selectedLanguage))
                        .font(MonoTheme.pointSmall)
                        .foregroundStyle(space.isLive ? MonoTheme.live : MonoTheme.mist)
                }
                
                Text(space.currentTrack.map { "\($0.title) - \($0.artistName)" } ?? "지금 방송 중인 음악 없음".localized(to: appModel.selectedLanguage))
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MonoTheme.mist)
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct YourStationDetailView: View {
    @Environment(AppModel.self) private var appModel
    let space: ListeningSpace
    
    @State private var comments: [StationComment] = []
    @State private var newCommentText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Station Description Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("스테이션 소개".localized(to: appModel.selectedLanguage))
                            .font(Font.custom("Paperlogy-7Bold", size: 14))
                            .foregroundStyle(MonoTheme.mist)
                        
                        Text(space.stationDescription)
                            .font(Font.custom("NotoSansKR-Regular", size: 14))
                            .foregroundStyle(MonoTheme.paper)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.045))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal, 16)
                    
                    // 2. Currently Playing Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("현재 방송 중".localized(to: appModel.selectedLanguage))
                            .font(Font.custom("Paperlogy-7Bold", size: 14))
                            .foregroundStyle(MonoTheme.mist)
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 16) {
                            if let track = space.currentTrack, let url = track.artworkURL {
                                ReliableAsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.white.opacity(0.1)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 4) {
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
                                
                                // Play Button to join the space
                                Button {
                                    Task { await appModel.join(space: space) }
                                } label: {
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(MonoTheme.paper)
                                        .frame(width: 44, height: 44)
                                        .background(MonoTheme.accent)
                                        .clipShape(Circle())
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.white.opacity(0.045))
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .foregroundStyle(MonoTheme.mist)
                                    }
                                
                                Text("지금 방송 중인 곡이 없습니다.".localized(to: appModel.selectedLanguage))
                                    .font(MonoTheme.bodyMedium)
                                    .foregroundStyle(MonoTheme.mist)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 16)
                    }
                    
                    // 3. Comments Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("실시간 댓글".localized(to: appModel.selectedLanguage))
                                .font(Font.custom("Paperlogy-7Bold", size: 14))
                                .foregroundStyle(MonoTheme.mist)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        VStack(spacing: 8) {
                            ForEach(comments) { comment in
                                StationCommentRow(comment: comment)
                            }
                            
                            if comments.isEmpty {
                                Text("아직 댓글이 없습니다. 첫 댓글을 남겨보세요!".localized(to: appModel.selectedLanguage))
                                    .font(MonoTheme.small)
                                    .foregroundStyle(MonoTheme.mist)
                                    .padding(.vertical, 20)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.top, 16)
            }
        }
        .background(MonoTheme.ink.ignoresSafeArea())
        .navigationTitle("%@의 스테이션".localized(to: appModel.selectedLanguage, space.owner.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            // Comment Input
            HStack(spacing: 12) {
                TextField("댓글 남기기...".localized(to: appModel.selectedLanguage), text: $newCommentText)
                    .font(MonoTheme.bodyMedium)
                    .foregroundStyle(MonoTheme.paper)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .onSubmit {
                        postComment()
                    }
                
                Button {
                    postComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(newCommentText.isEmpty ? MonoTheme.mist : MonoTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .disabled(newCommentText.isEmpty)
            }
            .padding(16)
            .background(MonoTheme.ink)
        }
        .task {
            for await newComments in appModel.stationStore.observeComments(spaceID: space.id) {
                withAnimation {
                    self.comments = newComments
                }
            }
        }
    }
    
    private func postComment() {
        guard !newCommentText.isEmpty else { return }
        let text = newCommentText
        newCommentText = ""
        
        let comment = StationComment(
            authorUID: appModel.currentUser.id,
            authorDisplayName: appModel.currentUser.displayName,
            content: text,
            trackContext: space.currentTrack
        )
        
        Task {
            try? await appModel.stationStore.postComment(spaceID: space.id, comment: comment)
        }
    }
}
