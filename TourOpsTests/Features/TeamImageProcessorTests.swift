//
//  TeamImageProcessorTests.swift
//  TourOpsTests
//

import Foundation
import Testing
import UIKit
@testable import TourOps

struct TeamImageProcessorTests {

    private func jpeg(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )

        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test
    func invalidDataThrowsFriendlyError() {
        #expect(throws: TeamImageError.self) {
            _ = try TeamImageProcessor.compressedJPEG(from: Data([0, 1, 2, 3]))
        }
    }

    @Test
    func largeImagesAreScaledToLongestEdgeLimit() throws {
        let output = try TeamImageProcessor.compressedJPEG(from: jpeg(width: 2400, height: 1200))
        let image = try #require(UIImage(data: output))
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)

        #expect(longest <= CGFloat(TeamImageProcessor.maxPixelDimension))
    }

    @Test
    func smallImagesAreNotUpscaled() throws {
        let output = try TeamImageProcessor.compressedJPEG(from: jpeg(width: 300, height: 200))
        let image = try #require(UIImage(data: output))
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)

        #expect(longest <= 300)
    }
}
