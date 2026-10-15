//
//  EditorField.swift
//  TourOps
//
//  The single text field used by every Teams, Tours and Shows form, plus the
//  caption and box styling shared by the other form fields (see
//  FormComponents.swift).
//

import SwiftUI

// MARK: - Shared field chrome

/// A small caption above a form control.
struct FieldLabel<Content: View>: View {

    let title: String
    var isRequired = false
    private let content: Content

    init(
        title: String,
        isRequired: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isRequired = isRequired
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.secondaryText)

                if isRequired {
                    Text("· Required")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText.opacity(0.85))
                }
            }
            .accessibilityHidden(true)

            content
        }
    }
}

private struct FieldBoxModifier: ViewModifier {

    let isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 52

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(
                        color: colorScheme == .dark ? .clear : Color.black.opacity(0.05),
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(
                        isFocused ? Palette.accent : Palette.hairline,
                        lineWidth: isFocused ? 1.5 : 0.7
                    )
            }
            .contentShape(Rectangle())
    }
}

extension View {

    /// The rounded surface every form control sits in.
    func fieldBox(isFocused: Bool = false) -> some View {
        modifier(FieldBoxModifier(isFocused: isFocused))
    }
}

// MARK: - Text field

struct EditorField: View {

    /// Purpose of the field. Used as the visible caption and as the
    /// accessibility label, so VoiceOver announces "Artist / Band Name"
    /// rather than the example placeholder.
    let title: String

    /// Example text shown while the field is empty.
    let prompt: String

    var isRequired = false
    var capitalization: TextInputAutocapitalization = .words

    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        FieldLabel(title: title, isRequired: isRequired) {
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
            .fieldBox(isFocused: isFocused)
            .onTapGesture {
                isFocused = true
            }
        }
    }
}

#if DEBUG
#Preview("Empty and filled, light") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        VStack(spacing: 18) {
            EditorField(
                title: "Artist / Band Name",
                prompt: "e.g. Silver Echo",
                isRequired: true,
                text: .constant("")
            )

            EditorField(
                title: "City",
                prompt: "e.g. London",
                text: .constant(
                    "The Extraordinarily Long Named Touring Orchestra of Somewhere"
                )
            )
        }
        .padding(20)
    }
    .preferredColorScheme(.light)
}

#Preview("Empty and filled, dark") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        VStack(spacing: 18) {
            EditorField(
                title: "Artist / Band Name",
                prompt: "e.g. Silver Echo",
                isRequired: true,
                text: .constant("")
            )

            EditorField(
                title: "City",
                prompt: "e.g. London",
                text: .constant("Copenhagen")
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
            isRequired: true,
            text: .constant("Silver Echo")
        )
        .padding(20)
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
