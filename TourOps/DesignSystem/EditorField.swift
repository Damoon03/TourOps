//
//  EditorField.swift
//  TourOps
//
//  The single text field used by every Teams, Tours and Shows form.
//

import SwiftUI

struct EditorField: View {

    /// Purpose of the field. Used as the visible caption and as the
    /// accessibility label, so VoiceOver announces "Artist / Band Name"
    /// rather than the example placeholder.
    let title: String

    /// Example text shown while the field is empty.
    let prompt: String

    var symbol: String? = nil
    var isRequired = false
    var capitalization: TextInputAutocapitalization = .words

    @Binding var text: String

    @FocusState private var isFocused: Bool

    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption
                .accessibilityHidden(true)

            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Palette.chipAccent)
                        .frame(width: iconWidth)
                        .accessibilityHidden(true)
                }

                TextField(
                    title,
                    text: $text,
                    prompt: Text(prompt)
                        .foregroundStyle(Palette.secondaryText)
                )
                .font(.body)
                .foregroundStyle(Palette.primaryText)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .focused($isFocused)
                .accessibilityLabel(title)
                .accessibilityHint(isRequired ? "Required" : "")
            }
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: Radius.field,
                    style: .continuous
                )
                .fill(Palette.canvas.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: Radius.field,
                    style: .continuous
                )
                .strokeBorder(
                    isFocused ? Palette.chipAccent : Palette.hairline,
                    lineWidth: isFocused ? 1.5 : 0.7
                )
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
    }

    private var caption: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .eyebrowStyle()

            if isRequired {
                Text("· REQUIRED")
                    .eyebrowStyle(Palette.secondaryText)
            }
        }
    }
}

#if DEBUG
#Preview("Empty and filled") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        VStack(spacing: 18) {
            EditorField(
                title: "Artist / Band Name",
                prompt: "e.g. Silver Echo",
                symbol: "music.mic",
                isRequired: true,
                text: .constant("")
            )

            EditorField(
                title: "City",
                prompt: "e.g. London",
                symbol: "mappin.and.ellipse",
                text: .constant(
                    "The Extraordinarily Long Named Touring Orchestra of Somewhere"
                )
            )
        }
        .padding(20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        EditorField(
            title: "Artist / Band Name",
            prompt: "e.g. Silver Echo",
            symbol: "music.mic",
            isRequired: true,
            text: .constant("Silver Echo")
        )
        .padding(20)
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
