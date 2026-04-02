import SwiftUI
import UIKit

@MainActor
enum PreviewData {
    static let mediaItems: [MediaItem] = [
        makeItem(assetName: "Dog1", urlString: "https://images.dog.ceo/breeds/ridgeback-rhodesian/n02087394_381.jpg"),
        makeItem(assetName: "Dog2", urlString: "https://images.dog.ceo/breeds/hound-afghan/n02088094_1003.jpg"),
        makeItem(assetName: "Dog3", urlString: "https://images.dog.ceo/breeds/husky/n02110185_1469.jpg"),
        makeItem(assetName: "Dog4", urlString: "https://images.dog.ceo/breeds/retriever-golden/n02099601_3004.jpg"),
        makeItem(assetName: "Dog5", urlString: "https://images.dog.ceo/breeds/terrier-norfolk/n02094114_1746.jpg"),
        makeItem(assetName: "Dog6", urlString: "https://images.dog.ceo/breeds/pointer-german/n02100236_3691.jpg"),
        makeItem(assetName: "Dog7", urlString: "https://images.dog.ceo/breeds/sheepdog-english/n02105641_793.jpg"),
        makeItem(assetName: "Dog8", urlString: "https://images.dog.ceo/breeds/spaniel-cocker/n02102318_4465.jpg")
    ]

    private static func makeItem(assetName: String, urlString: String) -> MediaItem {
        let image = UIImage(named: assetName) ?? fallbackImage(label: assetName)
        let imageData = image.jpegData(compressionQuality: 0.92) ?? Data()
        let aspectRatio = image.size.height > 0 ? image.size.width / image.size.height : 1.0
        let localFilePath = writePreviewImageData(imageData, assetName: assetName)

        return MediaItem(
            remoteURL: URL(string: urlString)!,
            localFilePath: localFilePath,
            aspectRatio: aspectRatio,
            createdAt: Date()
        )
    }

    private static func writePreviewImageData(_ data: Data, assetName: String) -> String? {
        let fileManager = FileManager.default
        let directoryURL = fileManager.temporaryDirectory.appendingPathComponent("CutePawsPreview", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            let fileURL = directoryURL.appendingPathComponent(assetName).appendingPathExtension("jpg")
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            return nil
        }
    }

    private static func fallbackImage(label: String) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.systemGray4.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 72),
                .foregroundColor: UIColor.white
            ]

            let text = NSString(string: label)
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
