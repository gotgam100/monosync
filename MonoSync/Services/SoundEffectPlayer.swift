import AVFoundation
import Foundation

@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    enum Effect {
        case button
        case insert
        case rewind
        case fastForward
        case open

        var fileName: String {
            switch self {
            case .button: "Button_1_204715"
            case .insert: "INOUT_510085"
            case .rewind: "RWD"
            case .fastForward: "FWD"
            case .open: "Open"
            }
        }
    }

    private var players: [UUID: AVAudioPlayer] = [:]
    private var isAudioSessionConfigured = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isAudioSessionConfigured = false
            }
        }
    }

    @discardableResult
    func play(_ effect: Effect) -> TimeInterval {
        guard let url = Bundle.main.url(forResource: effect.fileName, withExtension: "wav") else {
            return 0
        }

        do {
            try configureAudioSession()
            let player = try AVAudioPlayer(contentsOf: url)
            let id = UUID()
            players[id] = player
            player.prepareToPlay()
            player.play()

            Task { [weak self] in
                let delay = max(player.duration, 0.3)
                try? await Task.sleep(for: .seconds(delay + 0.2))
                await MainActor.run {
                    self?.players[id] = nil
                }
            }
            return player.duration
        } catch {
            return 0
        }
    }

    private func configureAudioSession() throws {
        guard !isAudioSessionConfigured else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        isAudioSessionConfigured = true
    }
}
