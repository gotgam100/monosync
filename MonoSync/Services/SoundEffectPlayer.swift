import AVFoundation
import Foundation

@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    enum Effect {
        case button
        case insert

        var fileName: String {
            switch self {
            case .button: "Button_1_204715"
            case .insert: "INOUT_510085"
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

    func play(_ effect: Effect) {
        guard let url = Bundle.main.url(forResource: effect.fileName, withExtension: "wav") else {
            return
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
        } catch {
            return
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
