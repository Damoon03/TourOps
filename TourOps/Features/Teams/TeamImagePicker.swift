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
        Section("Artist Image") {
            HStack(spacing: 14) {
                imagePreview

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            imageData == nil ? "Choose Image" : "Change Image",
                            systemImage: "photo"
                        )
                    }
                    .buttonStyle(.bordered)

                    if imageData != nil {
                        Button(role: .destructive) {
                            selectedItem = nil
                            imageData = nil
                        } label: {
                            Label("Remove Image", systemImage: "trash")
                                .font(.footnote)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            Text("The image is saved on this device and is not synced to other devices yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .task(id: selectedItem) {
            guard let selectedItem else { return }

            do {
                guard
                    let sourceData = try await selectedItem.loadTransferable(type: Data.self),
                    let compressedData = Self.compressedJPEG(from: sourceData),
                    !Task.isCancelled
                else {
                    return
                }

                imageData = compressedData
            } catch {
                // Keep the current image if the photo library cannot load the selection.
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .accessibilityLabel("Selected artist image")
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 76, height: 76)
                .accessibilityLabel("No artist image selected")
        }
    }

    private static func compressedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let maxPixelDimension: CGFloat = 1_200
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largestDimension = max(pixelWidth, pixelHeight)

        guard largestDimension > 0 else { return nil }

        let scale = min(1, maxPixelDimension / largestDimension)
        let targetSize = CGSize(
            width: max(1, (pixelWidth * scale).rounded(.down)),
            height: max(1, (pixelHeight * scale).rounded(.down))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.jpegData(withCompressionQuality: 0.82) { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
