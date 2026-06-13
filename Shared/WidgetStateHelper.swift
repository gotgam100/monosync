import Foundation
import WidgetKit

public struct WidgetStateHelper {
    public static let sharedUserDefaults = UserDefaults(suiteName: "group.com.baekmac.MonoSync")

    public static func update(
        trackTitle: String?,
        artistName: String?,
        albumTitle: String?,
        tapeStyle: String,
        isPlaying: Bool,
        side: String?,
        artworkURL: String?
    ) {
        guard let defaults = sharedUserDefaults else { return }
        
        defaults.set(trackTitle ?? "NO TAPE", forKey: "trackTitle")
        defaults.set(artistName ?? "INSERT TAPE", forKey: "artistName")
        defaults.set(albumTitle ?? "", forKey: "albumTitle")
        defaults.set(tapeStyle, forKey: "tapeStyle")
        defaults.set(isPlaying, forKey: "isPlaying")
        defaults.set(side ?? "SIDE A", forKey: "side")
        defaults.set(artworkURL, forKey: "artworkURL")
        defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdated")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
