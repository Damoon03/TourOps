//
//  TeamImagePicker.swift
//  TourOps
//
//  Shared local image picker for team creation and editing.
//

import PhotosUI
import SwiftUI
import UIKit

struct TeamImagePicker: View {

    @Binding var imageData: Data?

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ARTIST IMAGE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.secondaryText)

                Text("Give the artist a visual identity.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }

            HStack(spacing: 16) {
                imagePreview

                VStack(alignment: .leading, spacing: 10) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            imageData == nil
                                ? "Choose Image"
                                : "Change Image",
                            systemImage: "photo"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 42)
                        .background(
                            Palette.accent,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)

                    if imageData != nil {
                        Button(role: .destructive) {
                            selectedItem = nil
                            imageData = nil
                        } label: {
                            Label(
                                "Remove Image",
                                systemImage: "trash"
                            )
                            .font(.footnote.weight(.medium))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }

            Text("Stored on this device only; cloud image sync is not implemented yet.")
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
        .task(id: selectedItem) {
            guard let selectedItem else { return }

            do {
                guard
                    let sourceData = try await selectedItem
                        .loadTransferable(type: Data.self),
                    let compressedData = Self.compressedJPEG(
                        from: sourceData
                    ),
                    !Task.isCancelled
                else {
                    return
                }

                imageData = compressedData
            } catch {
                // Keep the current image if loading fails.
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .strokeBorder(
                        Palette.hairline,
                        lineWidth: 0.8
                    )
                }
                .accessibilityLabel("Selected artist image")
        } else {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(Palette.surfaceRaised)
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(width: 88, height: 88)
            .accessibilityLabel("No artist image selected")
        }
    }

    private static func compressedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let maxPixelDimension: CGFloat = 1_200
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largestDimension = max(pixelWidth, pixelHeight)

        guard largestDimension > 0 else {
            return nil
        }

        let scale = min(1, maxPixelDimension / largestDimension)
        let targetSize = CGSize(
            width: max(1, (pixelWidth * scale).rounded(.down)),
            height: max(1, (pixelHeight * scale).rounded(.down))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: targetSize,
            format: format
        )

        return renderer.jpegData(withCompressionQuality: 0.82) {
            context in
            UIColor.black.setFill()
            context.fill(
                CGRect(origin: .zero, size: targetSize)
            )
            image.draw(
                in: CGRect(origin: .zero, size: targetSize)
            )
        }
    }
}

#Preview {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        TeamImagePicker(imageData: .constant(nil))
            .padding(20)
    }
    .preferredColorScheme(.dark)
}
