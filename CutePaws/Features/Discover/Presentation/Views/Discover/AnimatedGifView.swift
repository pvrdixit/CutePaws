import ImageIO
import SwiftUI
import UIKit

struct AnimatedGifView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        configure(imageView: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        configure(imageView: uiView)
    }

    private func configure(imageView: UIImageView) {
        guard let data = try? Data(contentsOf: fileURL) else {
            imageView.image = nil
            imageView.stopAnimating()
            return
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            imageView.image = nil
            imageView.stopAnimating()
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            imageView.image = nil
            imageView.stopAnimating()
            return
        }

        var frames: [UIImage] = []
        frames.reserveCapacity(frameCount)
        var totalDuration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            totalDuration += frameDuration(from: source, at: index)
        }

        guard !frames.isEmpty else {
            imageView.image = nil
            imageView.stopAnimating()
            return
        }

        imageView.animationImages = frames
        imageView.animationDuration = max(totalDuration, 0.2)
        imageView.animationRepeatCount = 0
        imageView.image = frames.first
        if !imageView.isAnimating {
            imageView.startAnimating()
        }
    }

    private func frameDuration(from source: CGImageSource, at index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? 0.1
        return duration > 0.011 ? duration : 0.1
    }
}

