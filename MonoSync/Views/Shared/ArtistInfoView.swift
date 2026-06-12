import SwiftUI

struct ArtistInfoView: View {
    let artistName: String
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    
    @State private var artist: ArtistSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isNotesExpanded = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundStyle(MonoTheme.mist)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let artist = artist {
                artistContentView(artist)
            } else {
                Color.clear
            }
        }
        .background(MonoTheme.ink.ignoresSafeArea())
        .navigationTitle(artist?.name ?? "뮤지션 정보")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
                    .foregroundStyle(MonoTheme.paper)
            }
        }
        .task {
            await loadArtist()
        }
    }
    
    @ViewBuilder
    private func artistContentView(_ artist: ArtistSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    if let url = artist.artworkURL {
                        AlbumArtworkView(url: url, cornerRadius: 100)
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 160, height: 160)
                            .overlay {
                                Image(systemName: "music.mic")
                                    .font(.system(size: 60))
                                    .foregroundStyle(MonoTheme.mist)
                            }
                    }
                    
                    VStack(spacing: 8) {
                        Text(artist.name)
                            .font(MonoTheme.title)
                            .foregroundStyle(MonoTheme.paper)
                            .multilineTextAlignment(.center)
                        
                        Text("아티스트")
                            .font(MonoTheme.small)
                            .foregroundStyle(MonoTheme.mist)
                    }
                }
                .padding(.top, 24)
                
                // Notes
                if let notes = artist.editorialNotes {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation {
                                isNotesExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text("소개")
                                    .font(Font.custom("Paperlogy-7Bold", size: 16))
                                    .foregroundStyle(MonoTheme.paper)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(isNotesExpanded ? 90 : 0))
                                    .foregroundStyle(MonoTheme.mist)
                            }
                        }
                        .buttonStyle(.plain)

                        if isNotesExpanded {
                            Text(formatMarkdown(notes))
                                .font(Font.custom("NotoSansKR-Regular", size: 14))
                                .foregroundStyle(MonoTheme.mist.opacity(0.9))
                                .lineSpacing(4)
                                .padding(.top, 8)
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }
                
                // Albums
                if !artist.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("발매 앨범")
                            .font(Font.custom("Paperlogy-7Bold", size: 16))
                            .foregroundStyle(MonoTheme.paper)
                            .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(artist.albums) { album in
                                    NavigationLink(destination: AlbumInfoSheetView(album: album)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            AlbumArtworkView(url: album.artworkURL, cornerRadius: 8)
                                                .frame(width: 140, height: 140)
                                            
                                            Text(album.title)
                                                .font(MonoTheme.bodyMedium)
                                                .foregroundStyle(MonoTheme.paper)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            
                                            if let year = album.releaseYear {
                                                Text(year)
                                                    .font(MonoTheme.small)
                                                    .foregroundStyle(MonoTheme.mist)
                                            }
                                        }
                                        .frame(width: 140)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
                
                // Similar Artists
                if !artist.similarArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("관련 뮤지션")
                            .font(Font.custom("Paperlogy-7Bold", size: 16))
                            .foregroundStyle(MonoTheme.paper)
                            .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 20) {
                                ForEach(artist.similarArtists) { similarArtist in
                                    NavigationLink(destination: ArtistInfoView(artistName: similarArtist.name)) {
                                        VStack(alignment: .center, spacing: 8) {
                                            if let url = similarArtist.artworkURL {
                                                AlbumArtworkView(url: url, cornerRadius: 50)
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color.white.opacity(0.05))
                                                    .frame(width: 100, height: 100)
                                                    .overlay {
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 40))
                                                            .foregroundStyle(MonoTheme.mist)
                                                    }
                                            }
                                            
                                            Text(similarArtist.name)
                                                .font(MonoTheme.bodyMedium)
                                                .foregroundStyle(MonoTheme.paper)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 100)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private func loadArtist() async {
        guard artist == nil else { return }
        isLoading = true
        do {
            artist = try await appModel.musicService.fetchArtist(name: artistName)
            isLoading = false
        } catch {
            errorMessage = "뮤지션 정보를 불러올 수 없습니다."
            isLoading = false
        }
    }
    
    private func formatMarkdown(_ text: String) -> AttributedString {
        let cleanedText = text
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<b>", with: "**")
            .replacingOccurrences(of: "</b>", with: "**")
            .replacingOccurrences(of: "<i>", with: "*")
            .replacingOccurrences(of: "</i>", with: "*")
            
        if let parsed = try? AttributedString(markdown: cleanedText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return parsed
        }
        return AttributedString(cleanedText)
    }
}
