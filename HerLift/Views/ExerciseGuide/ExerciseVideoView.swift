import AVKit
import SwiftUI

/// Silent demonstration clip that starts automatically and loops without a gap.
/// `fillsFrame` crops the clip's empty side margins so the lifter appears larger in a narrow frame.
struct ExerciseVideoView: UIViewControllerRepresentable {
    let url: URL
    var fillsFrame = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVQueuePlayer()
        player.isMuted = true
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))

        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.allowsPictureInPicturePlayback = false
        controller.videoGravity = fillsFrame ? .resizeAspectFill : .resizeAspect
        controller.view.backgroundColor = .clear
        player.play()
        return controller
    }

    /// Restarts playback if the player was paused, for example when the screen reappears after navigation.
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.videoGravity = fillsFrame ? .resizeAspectFill : .resizeAspect
        if controller.player?.timeControlStatus == .paused { controller.player?.play() }
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause()
        coordinator.looper?.disableLooping()
    }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }
}
