import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Shrinks photos and caps audio so Watch glances stay offline and small.
public enum WatchMediaPreview: Sendable {
    public static let maxThumbnailBytes = 24_000
    public static let maxAudioBytes = 120_000
    public static let thumbnailMaxPixel = 180

    public static func jpegThumbnail(from data: Data) -> Data? {
        guard data.isEmpty == false else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        for quality in [0.55, 0.4, 0.28] as [CGFloat] {
            let destData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                destData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else { return nil }
            let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
            CGImageDestinationAddImage(destination, image, props as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { continue }
            if destData.length <= maxThumbnailBytes, destData.length > 0 {
                return destData as Data
            }
        }
        return nil
    }

    public static func shortAudio(from data: Data) -> Data? {
        guard data.isEmpty == false, data.count <= maxAudioBytes else { return nil }
        return data
    }
}
