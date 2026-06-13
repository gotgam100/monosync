import SwiftUI
import WidgetKit

struct MonoSyncWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }
    
    private var smallView: some View {
        ZStack {
            if let artworkData = entry.artworkData, let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(white: 0.15)
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
            
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.isPlaying ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                        .shadow(color: entry.isPlaying ? Color.green : Color.red, radius: 2)
                    
                    Text(entry.isPlaying ? "PLAYING" : "STOPPED")
                        .font(.custom("Paperlogy-5Medium", size: 8))
                        .foregroundColor(entry.isPlaying ? .green : .red)
                }
                
                Text(entry.trackTitle == "NO TAPE" ? "INSERT TAPE" : entry.trackTitle)
                    .font(.custom("Cafe24PROSlimAir", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(entry.artistName)
                    .font(.custom("Paperlogy-5Medium", size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Album Artwork or Empty State
            ZStack {
                if entry.trackTitle != "NO TAPE" {
                    if let artworkData = entry.artworkData, let uiImage = UIImage(data: artworkData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    } else {
                        // Fallback to tape if image fails to load
                        Image(entry.tapeStyle)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110)
                    }
                } else {
                    // Empty deck state
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(white: 0.25), lineWidth: 1)
                        )
                    
                    Text("INSERT TAPE")
                        .font(.custom("Paperlogy-7Bold", size: 14))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 120, height: 120)
            
            // Right: Indicators
            VStack(alignment: .leading, spacing: 14) {
                Text("MONOSYNC DECK")
                    .font(.custom("Paperlogy-7Bold", size: 10))
                    .foregroundColor(.gray)
                
                HStack {
                    Text(entry.side)
                        .font(.custom("Paperlogy-6SemiBold", size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.trackTitle)
                        .font(.custom("Cafe24PROSlimAir", size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(entry.artistName)
                        .font(.custom("Paperlogy-5Medium", size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // LED Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.isPlaying ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: entry.isPlaying ? Color.green : Color.red, radius: 3)
                    
                    Text(entry.isPlaying ? "PLAYING" : "STOPPED")
                        .font(.custom("Paperlogy-5Medium", size: 9))
                        .foregroundColor(entry.isPlaying ? .green : .red)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .containerBackground(for: .widget) {
            ZStack {
                Color(white: 0.1)
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
