import SwiftUI

struct MyStationView: View {
    @Environment(AppModel.self) private var appModel
    let onMenu: () -> Void
    
    @State private var nameText: String = ""
    @FocusState private var isNameFocused: Bool
    @State private var descriptionText: String = ""
    @FocusState private var isDescriptionFocused: Bool
    @State private var comments: [StationComment] = []
    @State private var newCommentText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                MonoPageHeader(title: "마이스테이션".localized(to: appModel.selectedLanguage), subtitle: "나의 방송국".localized(to: appModel.selectedLanguage), onMenu: onMenu)
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Station Information Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("스테이션 이름".localized(to: appModel.selectedLanguage))
                                .font(Font.custom("Paperlogy-7Bold", size: 14))
                                .foregroundStyle(MonoTheme.mist)
                            
                            TextField("스테이션 이름을 입력하세요".localized(to: appModel.selectedLanguage), text: $nameText)
                                .font(Font.custom("NotoSansKR-Regular", size: 14))
                                .foregroundStyle(MonoTheme.paper)
                                .padding(12)
                                .background(Color.white.opacity(0.045))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isNameFocused)
                                .onChange(of: isNameFocused) { _, isFocused in
                                    if !isFocused {
                                        Task { await appModel.updateStationTitle(nameText) }
                                    }
                                }
                                .onSubmit {
                                    isNameFocused = false
                                }

                            Text("스테이션 소개".localized(to: appModel.selectedLanguage))
                                .font(Font.custom("Paperlogy-7Bold", size: 14))
                                .foregroundStyle(MonoTheme.mist)
                                .padding(.top, 8)
                            
                            TextField("스테이션을 소개해보세요".localized(to: appModel.selectedLanguage), text: $descriptionText)
                                .font(Font.custom("NotoSansKR-Regular", size: 14))
                                .foregroundStyle(MonoTheme.paper)
                                .padding(12)
                                .background(Color.white.opacity(0.045))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isDescriptionFocused)
                                .onChange(of: isDescriptionFocused) { _, isFocused in
                                    if !isFocused {
                                        Task { await appModel.updateStationDescription(descriptionText) }
                                    }
                                }
                                .onSubmit {
                                    isDescriptionFocused = false
                                }
                        }
                        .padding(.horizontal, 16)
                        
                        // 2. Currently Playing Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("현재 방송 중".localized(to: appModel.selectedLanguage))
                                .font(Font.custom("Paperlogy-7Bold", size: 14))
                                .foregroundStyle(MonoTheme.mist)
                                .padding(.horizontal, 16)
                            
                            HStack(spacing: 16) {
                                if let track = appModel.mySpace.currentTrack, let url = track.artworkURL {
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
                                }
                                Spacer()
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
                                Text("청취자 %d명".localized(to: appModel.selectedLanguage, appModel.mySpace.listenerCount))
                                    .font(MonoTheme.small)
                                    .foregroundStyle(MonoTheme.accent)
                            }
                            .padding(.horizontal, 16)
                            
                            VStack(spacing: 8) {
                                ForEach(comments) { comment in
                                    StationCommentRow(comment: comment)
                                }
                                
                                if comments.isEmpty {
                                    Text("아직 댓글이 없습니다.".localized(to: appModel.selectedLanguage))
                                        .font(MonoTheme.small)
                                        .foregroundStyle(MonoTheme.mist)
                                        .padding(.vertical, 20)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .contentShape(Rectangle())
            .onSwipeToChangeSection(current: .myStation) { next in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    appModel.selectedSection = next
                }
            }
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
                for await newComments in appModel.stationStore.observeComments(spaceID: appModel.currentUser.id) {
                    withAnimation {
                        self.comments = newComments
                    }
                }
            }
            .onAppear {
                nameText = appModel.mySpace.title
                descriptionText = appModel.mySpace.stationDescription
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
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
            trackContext: appModel.mySpace.currentTrack
        )
        
        Task {
            try? await appModel.stationStore.postComment(spaceID: appModel.currentUser.id, comment: comment)
        }
    }
}

struct StationCommentRow: View {
    let comment: StationComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(comment.authorDisplayName)
                    .font(MonoTheme.bodyMedium.bold())
                    .foregroundStyle(MonoTheme.paper)
                
                Spacer()
                
                Text(comment.createdAt, style: .time)
                    .font(MonoTheme.small)
                    .foregroundStyle(MonoTheme.mist)
            }
            
            Text(comment.content)
                .font(MonoTheme.bodyMedium)
                .foregroundStyle(MonoTheme.paper)
            
            if let track = comment.trackContext {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                    Text("\(track.title) - \(track.artistName)")
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundStyle(MonoTheme.mist)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
