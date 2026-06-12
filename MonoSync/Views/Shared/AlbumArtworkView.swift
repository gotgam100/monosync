import SwiftUI

struct AlbumArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 8
    var fallbackSystemName = "music.note"
    var showsLoadingIndicator = false
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var imageReloadToken = UUID()

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let side = max(1, min(proxy.size.width, proxy.size.height))

                    ZStack {
                        if let url {
                            ReliableAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: side, height: side)
                                    .clipped()
                            } placeholder: {
                                if showsLoadingIndicator {
                                    ProgressView()
                                        .tint(MonoTheme.accent)
                                } else {
                                    fallback
                                }
                            }
                        } else {
                            fallback
                        }
                    }
                    .frame(width: side, height: side)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .clipped()
    }

    private var fallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: fallbackSystemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MonoTheme.mist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReliableAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: Image?

    var body: some View {
        Group {
            if let loadedImage {
                content(loadedImage)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            loadedImage = nil
            guard let url else {
                return
            }
            
            do {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let uiImage = UIImage(data: data) {
                    loadedImage = Image(uiImage: uiImage)
                }
            } catch {
                // Silently fallback to placeholder on failure
            }
        }
    }
}
