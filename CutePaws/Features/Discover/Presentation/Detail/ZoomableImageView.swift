import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let imagePath: String?
    let imageID: String
    let isSelected: Bool
    let onZoomStateChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onZoomStateChanged: onZoomStateChanged)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 2.5
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast

        let imageView = context.coordinator.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onZoomStateChanged = onZoomStateChanged
        context.coordinator.update(
            scrollView: scrollView,
            imagePath: imagePath,
            imageID: imageID,
            isSelected: isSelected
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        var onZoomStateChanged: (Bool) -> Void

        private var currentImageID: String?
        private var lastBoundsSize: CGSize = .zero

        init(onZoomStateChanged: @escaping (Bool) -> Void) {
            self.onZoomStateChanged = onZoomStateChanged
        }

        func update(
            scrollView: UIScrollView,
            imagePath: String?,
            imageID: String,
            isSelected: Bool
        ) {
            var imageDidChange = false

            if currentImageID != imageID {
                if let imagePath {
                    imageView.image = ImageCache.shared.image(forFilePath: imagePath)
                } else {
                    imageView.image = nil
                }
                currentImageID = imageID
                lastBoundsSize = .zero
                scrollView.zoomScale = 1.0
                onZoomStateChanged(false)
                imageDidChange = true
            }

            if !isSelected, scrollView.zoomScale != 1.0 {
                scrollView.setZoomScale(1.0, animated: false)
                onZoomStateChanged(false)
            }

            if lastBoundsSize != scrollView.bounds.size || scrollView.zoomScale == 1.0 {
                layoutImage(in: scrollView)
            }

            if imageDidChange {
                DispatchQueue.main.async { [weak self, weak scrollView] in
                    guard let self, let scrollView else { return }
                    self.layoutImage(in: scrollView)
                }
            }

            scrollView.isScrollEnabled = scrollView.zoomScale > 1.01
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
            scrollView.isScrollEnabled = scrollView.zoomScale > 1.01
            onZoomStateChanged(scrollView.zoomScale > 1.01)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            if scale <= 1.01 {
                scrollView.setZoomScale(1.0, animated: false)
                layoutImage(in: scrollView)
                onZoomStateChanged(false)
            }
        }

        func layoutImage(in scrollView: UIScrollView) {
            guard
                let image = imageView.image,
                image.size.width > 0,
                image.size.height > 0,
                scrollView.bounds.width > 0,
                scrollView.bounds.height > 0
            else {
                return
            }

            let boundsSize = scrollView.bounds.size
            let horizontalRatio = boundsSize.width / image.size.width
            let verticalRatio = boundsSize.height / image.size.height
            let scale = min(horizontalRatio, verticalRatio)

            let fittedSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            imageView.frame = CGRect(origin: .zero, size: fittedSize)
            scrollView.contentSize = fittedSize
            centerImage(in: scrollView)
            lastBoundsSize = boundsSize
        }

        private func centerImage(in scrollView: UIScrollView) {
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            frameToCenter.origin.x = frameToCenter.width < boundsSize.width
                ? (boundsSize.width - frameToCenter.width) / 2
                : 0

            frameToCenter.origin.y = frameToCenter.height < boundsSize.height
                ? (boundsSize.height - frameToCenter.height) / 2
                : 0

            imageView.frame = frameToCenter
        }
    }
}

#Preview {
    ZoomableImageView(
        imagePath: nil,
        imageID: "preview",
        isSelected: true,
        onZoomStateChanged: { _ in }
    )
    .frame(height: 280)
    .background(Color(uiColor: .systemBackground))
}
