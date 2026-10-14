//
//  TeamImageProcessor.swift
//  TourOps
//
//  Downsamples and compresses a chosen photo for local storage. Uses ImageIO
//  thumbnail decoding so a full-resolution photo is never decoded into memory,
//  and is `nonisolated` so callers can run it off the main actor.
//

import ImageIO
import UIKit

nonisolated enum TeamImageError: LocalizedError, Equatable {

    /// The photo library returned no data for the selection.
    case unreadable

    /// The data is not a decodable image.
    case invalidImage

    /// The work was cancelled (for example by Remove or Cancel). Never shown.
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "That photo couldn’t be loaded. Choose a different image."
        case .invalidImage:
            "That file isn’t a supported image. Choose a different photo."
        case .cancelled:
            nil
        }
    }
}

nonisolated enum TeamImageProcessor {

    /// Longest edge, in pixels, of the stored image.
    static var maxPixelDimension: Int { 1_200 }

    static var compressionQuality: CGFloat { 0.82 }

    /// Returns opaque JPEG data whose longest edge is at most
    /// `maxPixelDimension`. Images that are already smaller are not enlarged.
    static func compressedJPEG(from data: Data) throws -> Data {
        guard !data.isEmpty else {
            throw TeamImageError.invalidImage
        }

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        guard
            let source = CGImageSourceCreateWithData(
                data as CFData,
                sourceOptions as CFDictionary
            ),
            CGImageSourceGetCount(source) > 0
        else {
            throw TeamImageError.invalidImage
        }

        let originalLongestEdge = longestEdge(of: source)

        guard originalLongestEdge > 0 else {
            throw TeamImageError.invalidImage
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(
                originalLongestEdge,
                maxPixelDimension
            )
        ]

        guard
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            ),
            cgImage.width > 0,
            cgImage.height > 0
        else {
            throw TeamImageError.invalidImage
        }

        let size = CGSize(width: cgImage.width, height: cgImage.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let jpeg = renderer.jpegData(
            withCompressionQuality: compressionQuality
        ) { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIImage(cgImage: cgImage).draw(
                in: CGRect(origin: .zero, size: size)
            )
        }

        guard !jpeg.isEmpty else {
            throw TeamImageError.invalidImage
        }

        return jpeg
    }

    private static func longestEdge(of source: CGImageSource) -> Int {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
            ) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return 0
        }

        return max(width, height)
    }
}
