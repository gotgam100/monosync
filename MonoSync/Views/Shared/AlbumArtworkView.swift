import SwiftUI

struct AlbumArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 8
    var fallbackSystemName = "music.note"
    var showsLoadingIndicator = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        fallback
                    case .empty:
                        if showsLoadingIndicator {
                            ProgressView()
                                .tint(MonoTheme.accent)
                        } else {
                            fallback
                        }
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
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
