import SwiftUI

struct AlbumInfoSheetView: View {
    let album: AlbumSnapshot
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    
    @State private var isNotesExpanded = false
    @State private var loadedTracks: [TrackSnapshot]?

    private var memoBinding: Binding<String> {
        Binding(
            get: { appModel.albumMemos[album.id]?.text ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    appModel.albumMemos.removeValue(forKey: album.id)
                } else {
                    appModel.albumMemos[album.id] = AlbumMemo(album: album, text: newValue, updatedAt: Date())
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AlbumArtworkView(url: album.artworkURL, cornerRadius: 12)
                        .frame(width: 200, height: 200)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                    VStack(spacing: 8) {
                        Text(album.title)
                            .font(MonoTheme.title)
                            .foregroundStyle(MonoTheme.paper)
                            .multilineTextAlignment(.center)
                        
                        NavigationLink(destination: ArtistInfoView(artistName: album.artistName)) {
                            HStack(spacing: 4) {
                                Text(album.artistName)
                                    .font(MonoTheme.compactTitle)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(MonoTheme.mist)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 16) {
                        if let year = album.releaseYear {
                            infoRow(title: "발매", value: year)
                        }
                        if let genres = album.genreNames, !genres.isEmpty {
                            infoRow(title: "장르", value: genres.joined(separator: ", "))
                        }
                        if let label = album.recordLabelName {
                            infoRow(title: "레이블", value: label)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("나의 메모")
                                .font(Font.custom("Paperlogy-7Bold", size: 14))
                                .foregroundStyle(MonoTheme.mist)
                            
                            TextField("나만 볼 수 있는 메모를 남겨보세요.", text: memoBinding, axis: .vertical)
                                .font(Font.custom("NotoSansKR-Regular", size: 14))
                                .foregroundStyle(MonoTheme.paper)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.top, 8)

                        if let notes = album.editorialNotes {
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    withAnimation {
                                        isNotesExpanded.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("에디터 노트")
                                            .font(Font.custom("Paperlogy-7Bold", size: 14))
                                            .foregroundStyle(MonoTheme.mist)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .rotationEffect(.degrees(isNotesExpanded ? 90 : 0))
                                            .foregroundStyle(MonoTheme.mist)
                                    }
                                }
                                .buttonStyle(.plain)

                                if isNotesExpanded {
                                    JustifiedText(text: formatMarkdown(notes))
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    
                    // Track List
                    let tracksToDisplay = !album.tracks.isEmpty ? album.tracks : (loadedTracks ?? [])
                    if !tracksToDisplay.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("곡 목록")
                                    .font(Font.custom("Paperlogy-7Bold", size: 16))
                                    .foregroundStyle(MonoTheme.paper)
                                Spacer()
                                let isInDrawer = appModel.drawerAlbums.contains(where: { $0.id == album.id })
                                Button {
                                    if isInDrawer {
                                        appModel.deleteDrawerAlbum(id: album.id, title: album.title)
                                    } else {
                                        Task { await appModel.addSearchAlbumToDrawer(album) }
                                    }
                                } label: {
                                    Image(systemName: isInDrawer ? "tray.full.fill" : "tray.and.arrow.down")
                                        .foregroundStyle(isInDrawer ? MonoTheme.paper : MonoTheme.mist)
                                        .frame(width: 34, height: 34)
                                        .background(isInDrawer ? MonoTheme.accent : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isInDrawer ? "서랍 선택 취소" : "서랍에 담기")
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(tracksToDisplay.enumerated()), id: \.element.id) { index, track in
                                    let isCurrentTrack = appModel.mySpace.currentTrack.map { track.matches($0) } ?? false
                                    HStack {
                                        if isCurrentTrack {
                                            Image(systemName: "waveform")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(MonoTheme.accent)
                                                .frame(width: 24, alignment: .leading)
                                                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: appModel.mySpace.playbackState == .playing)
                                        } else {
                                            Text("\(index + 1)")
                                                .font(Font.custom("NotoSansKR-Regular", size: 13))
                                                .foregroundStyle(MonoTheme.mist)
                                                .frame(width: 24, alignment: .leading)
                                        }
                                        
                                        Text(track.title)
                                            .font(Font.custom("NotoSansKR-Medium", size: 15))
                                            .foregroundStyle(isCurrentTrack ? MonoTheme.accent : MonoTheme.paper)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text(timeString(from: track.duration))
                                            .font(Font.custom("NotoSansKR-Regular", size: 13))
                                            .foregroundStyle(MonoTheme.mist)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    
                                    if index < tracksToDisplay.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 24)
                        }
                    } else if album.tracks.isEmpty && loadedTracks == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.vertical, 32)
            }
            .task {
                if album.tracks.isEmpty {
                    loadedTracks = try? await appModel.musicService.tracks(in: album)
                }
            }
            .background(MonoTheme.ink.ignoresSafeArea())
            .navigationTitle("앨범 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(MonoTheme.paper)
                }
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(Font.custom("Paperlogy-7Bold", size: 14))
                .foregroundStyle(MonoTheme.mist)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(Font.custom("NotoSansKR-Regular", size: 14))
                .foregroundStyle(MonoTheme.paper)
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
            
        var attr: AttributedString
        if let parsed = try? AttributedString(markdown: cleanedText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            attr = parsed
        } else {
            attr = AttributedString(cleanedText)
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        attr.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
        
        return attr
    }
}

private struct JustifiedText: UIViewRepresentable {
    let text: AttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInset = .zero
        textView.layoutMargins = .zero
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .never
        }
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        do {
            let nsAttrStr = try NSMutableAttributedString(text, including: \.uiKit)
            
            let fullRange = NSRange(location: 0, length: nsAttrStr.length)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .justified
            paragraphStyle.lineSpacing = 4
            
            if let customFont = UIFont(name: "NotoSansKR-Regular", size: 13) {
                nsAttrStr.addAttribute(.font, value: customFont, range: fullRange)
            } else {
                nsAttrStr.addAttribute(.font, value: UIFont.systemFont(ofSize: 13), range: fullRange)
            }
            
            nsAttrStr.addAttribute(.foregroundColor, value: UIColor(MonoTheme.paper), range: fullRange)
            nsAttrStr.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            
            uiView.attributedText = nsAttrStr
        } catch {
            uiView.text = String(text.characters)
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let targetSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let size = uiView.sizeThatFits(targetSize)
        return CGSize(width: width, height: size.height)
    }
}
