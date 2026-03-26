import SwiftUI
import UIKit
import CoreImage

struct CinematicBackdrop: View {
    let imagePath: String?
    let fallbackImageName: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var gradientColors: [Color] = [
        Color.accentColor.opacity(0.35),
        Color(uiColor: .systemBackground)
    ]

    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    var body: some View {
        let backgroundImage = resolveImage()

        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(colorScheme == .dark ? 0.18 : 0.12)
                    .blur(radius: 50)
                    .saturation(1.15)
            }

            Color.black.opacity(colorScheme == .dark ? 0.4 : 0.18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .task(id: imagePath ?? fallbackImageName) {
            let image = resolveImage()
            gradientColors = makeGradientColors(from: image)
        }
    }

    private func resolveImage() -> UIImage? {
        if let image = ImageCache.shared.image(forFilePath: imagePath) {
            return image
        }
        return UIImage(named: fallbackImageName)
    }

    private func makeGradientColors(from image: UIImage?) -> [Color] {
        guard let image, let average = averageUIColor(from: image) else {
            return [Color.accentColor.opacity(0.35), Color(uiColor: .systemBackground)]
        }

        let (h, s, b, a) = hsba(from: average)
        let top = UIColor(
            hue: h,
            saturation: min(1.0, s * 0.85 + 0.08),
            brightness: min(1.0, b * 0.95 + 0.08),
            alpha: a
        )
        let bottom = UIColor(
            hue: h,
            saturation: max(0.0, s * 0.55),
            brightness: max(0.0, b * 0.45),
            alpha: a
        )

        return [Color(uiColor: top), Color(uiColor: bottom)]
    }

    private func averageUIColor(from image: UIImage) -> UIColor? {
        guard let inputCIImage = CIImage(image: image) else { return nil }
        let extent = inputCIImage.extent
        guard !extent.isEmpty else { return nil }

        guard
            let filter = CIFilter(name: "CIAreaAverage")
        else {
            return nil
        }

        filter.setValue(inputCIImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: CGFloat(bitmap[3]) / 255.0
        )
    }

    private func hsba(from color: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }
}

