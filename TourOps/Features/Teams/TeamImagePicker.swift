//
//  TeamImagePicker.swift
//
//  Local image picker shared by team creation and editing.
//

import PhotosUI
import SwiftUI
import UIKit

struct TeamImagePicker: View {

    enum Phase: Equatable {
        case idle
        case processing
        case failed(String)
    }

    @Binding var imageData: Data?

    /// Mirrors whether an image is being prepared, so the surrounding form can
    /// hold Save until the result (or failure) is known.
    @Binding var isBusy: Bool

    @State private var selectedItem: PhotosPickerItem?
    @State private var phase: Phase
    @State private var loadTask: Task<Void, Never>?
    @State private var generation = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var previewSize: CGFloat = 88

    init(
        imageData: Binding<Data?>,
        isBusy: Binding<Bool> = .constant(false),
        initialPhase: Phase = .idle
    ) {
        _imageData = imageData
        _isBusy = isBusy
        _phase = State(initialValue: initialPhase)
    }

    private var isProcessing: Bool {
        phase == .processing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                SectionHeading("ARTIST IMAGE")

                Text("Give the artist a visual identity.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }

            controlsLayout {
                imagePreview
                controls
            }

            statusLine

            Text("Artist images are kept on this device only and don’t appear on your other devices.")
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .onChange(of: selectedItem) { _, newItem in
            if let newItem {
                startLoading(newItem)
            }
        }
        .onChange(of: phase) { _, newPhase in
            isBusy = newPhase == .processing
        }
        .onDisappear {
            cancelPendingWork()
        }
    }

    // MARK: - Layout

    private var controlsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 4) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    imageData == nil ? "Choose Image" : "Change Image",
                    systemImage: "photo"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Palette.accent, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.5 : 1)

            if isProcessing {
                secondaryAction(
                    title: "Cancel",
                    symbol: "xmark",
                    color: Palette.primaryText,
                    action: cancelProcessing
                )
            }

            if imageData != nil {
                secondaryAction(
                    title: "Remove Image",
                    symbol: "trash",
                    color: Palette.destructive,
                    action: removeImage
                )
                .accessibilityHint("Removes the artist image")
            }
        }
    }

    private func secondaryAction(
        title: String,
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch phase {
        case .idle:
            EmptyView()

        case .processing:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Palette.chipAccent)

                Text("Processing photo…")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            .accessibilityElement(children: .combine)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.destructive)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var imagePreview: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: previewSize, height: previewSize)
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
                        .strokeBorder(Palette.hairline, lineWidth: 0.8)
                    }
                    .accessibilityLabel("Selected artist image")
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.surfaceRaised)
                    .overlay {
                        Image(systemName: "music.mic")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    .frame(width: previewSize, height: previewSize)
                    .accessibilityLabel("No artist image selected")
            }
        }
        .overlay {
            if isProcessing {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Work

    private func startLoading(_ item: PhotosPickerItem) {
        loadTask?.cancel()
        generation += 1

        let current = generation
        phase = .processing

        loadTask = Task {
            let outcome = await Self.process(item)

            // A newer selection, Cancel, Remove, or leaving the screen has
            // superseded this work: drop the result.
            guard !Task.isCancelled, current == generation else {
                return
            }

            switch outcome {
            case .success(let data):
                imageData = data
                phase = .idle

            case .failure(.cancelled):
                phase = .idle

            case .failure(let error):
                // The previous image is left untouched on failure.
                let message = error.errorDescription
                    ?? "That photo couldn’t be used."
                phase = .failed(message)
                AccessibilityNotification.Announcement(message).post()
            }

            // Allow the same photo to be chosen again.
            selectedItem = nil
            loadTask = nil
        }
    }

    private func cancelPendingWork() {
        loadTask?.cancel()
        loadTask = nil
        generation += 1
    }

    private func cancelProcessing() {
        cancelPendingWork()
        selectedItem = nil
        phase = .idle
    }

    private func removeImage() {
        cancelPendingWork()
        selectedItem = nil
        phase = .idle
        imageData = nil
    }

    private static func process(
        _ item: PhotosPickerItem
    ) async -> Result<Data, TeamImageError> {
        do {
            guard
                let source = try await item.loadTransferable(type: Data.self),
                !source.isEmpty
            else {
                return .failure(.unreadable)
            }

            let compressed = try await Task.detached(
                priority: .userInitiated
            ) {
                try TeamImageProcessor.compressedJPEG(from: source)
            }
            .value

            return .success(compressed)
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch let error as TeamImageError {
            return .failure(error)
        } catch {
            return .failure(.unreadable)
        }
    }
}

#if DEBUG
#Preview("No image") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        TeamImagePicker(imageData: .constant(nil))
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Image present") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        TeamImagePicker(imageData: .constant(PreviewData.sampleImageData))
            .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Processing") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        TeamImagePicker(
            imageData: .constant(PreviewData.sampleImageData),
            initialPhase: .processing
        )
        .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Failed, large text") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            TeamImagePicker(
                imageData: .constant(nil),
                initialPhase: .failed(
                    "That photo couldn’t be loaded. Choose a different image."
                )
            )
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
