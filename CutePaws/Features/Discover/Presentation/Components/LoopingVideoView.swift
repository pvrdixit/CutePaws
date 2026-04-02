import AVFoundation
import SwiftUI
import UIKit

struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    var isMuted: Bool = true
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        context.coordinator.attach(to: view, url: url, isMuted: isMuted, videoGravity: videoGravity)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        context.coordinator.attach(to: uiView, url: url, isMuted: isMuted, videoGravity: videoGravity)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private var queuePlayer: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?
        private weak var hostView: PlayerContainerView?

        func attach(to view: PlayerContainerView, url: URL, isMuted: Bool, videoGravity: AVLayerVideoGravity) {
            hostView = view
            view.playerLayer.videoGravity = videoGravity

            if currentURL != url || queuePlayer == nil {
                let asset = AVURLAsset(url: url)
                let item = AVPlayerItem(asset: asset)
                let player = AVQueuePlayer()
                player.actionAtItemEnd = .none
                player.isMuted = isMuted
                looper = AVPlayerLooper(player: player, templateItem: item)
                queuePlayer = player
                currentURL = url
                view.playerLayer.player = player
                player.play()
            } else {
                queuePlayer?.isMuted = isMuted
                if queuePlayer?.timeControlStatus != .playing {
                    queuePlayer?.play()
                }
            }
        }

        func detach() {
            queuePlayer?.pause()
            looper = nil
            queuePlayer = nil
            currentURL = nil
            hostView?.playerLayer.player = nil
        }
    }
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer")
        }
        return layer
    }
}
