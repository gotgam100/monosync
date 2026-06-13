import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), trackTitle: "NO TAPE", artistName: "INSERT TAPE", albumTitle: "", tapeStyle: "tape_N2", isPlaying: false, side: "SIDE A", artworkData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = getCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = getCurrentEntry()
        // AppModel pushes updates via WidgetStateHelper, so we don't need frequent polling
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func getCurrentEntry() -> SimpleEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.baekmac.MonoSync") else {
            return SimpleEntry(date: Date(), trackTitle: "NO TAPE", artistName: "INSERT TAPE", albumTitle: "", tapeStyle: "tape_N2", isPlaying: false, side: "SIDE A", artworkData: nil)
        }
        
        let trackTitle = defaults.string(forKey: "trackTitle") ?? "NO TAPE"
        let artistName = defaults.string(forKey: "artistName") ?? "INSERT TAPE"
        let albumTitle = defaults.string(forKey: "albumTitle") ?? ""
        let tapeStyle = defaults.string(forKey: "tapeStyle") ?? "tape_N2"
        let isPlaying = defaults.bool(forKey: "isPlaying")
        let side = defaults.string(forKey: "side") ?? "SIDE A"
        let artworkURLString = defaults.string(forKey: "artworkURL")
        
        var artworkData: Data? = nil
        if let artworkURLString, let url = URL(string: artworkURLString) {
            artworkData = try? Data(contentsOf: url)
        }
        
        return SimpleEntry(
            date: Date(),
            trackTitle: trackTitle,
            artistName: artistName,
            albumTitle: albumTitle,
            tapeStyle: tapeStyle,
            isPlaying: isPlaying,
            side: side,
            artworkData: artworkData
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let trackTitle: String
    let artistName: String
    let albumTitle: String
    let tapeStyle: String
    let isPlaying: Bool
    let side: String
    let artworkData: Data?
}

@main
struct MonoSyncWidget: Widget {
    let kind: String = "MonoSyncWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MonoSyncWidgetView(entry: entry)
                .widgetURL(URL(string: "monosync://"))
        }
        .configurationDisplayName("MonoSync Deck")
        .description("Shows your current tape deck status.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // If targeting iOS 17+, we can use containerBackground
        .contentMarginsDisabled()
    }
}
