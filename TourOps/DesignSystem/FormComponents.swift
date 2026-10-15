//
//  FormComponents.swift
//  TourOps
//
//  Form building blocks for the create and edit bottom sheets: the sheet
//  scaffold, a menu picker and a date or time field.
//

import SwiftUI

// MARK: - Sheet scaffold

/// The bottom-sheet layout shared by every create and edit form: grabber,
/// Cancel and title on top, scrolling fields, and a primary Save button with
/// a caption pinned at the bottom.
///
/// Each form keeps its own state and submission logic and passes in the
/// pieces it needs; this view only draws them.
struct FormSheet<Content: View>: View {

    let title: String
    let saveTitle: String
    let canSave: Bool
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    private let content: Content

    init(
        title: String,
        saveTitle: String,
        canSave: Bool,
        isSaving: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.canSave = canSave
        self.isSaving = isSaving
        self.onCancel = onCancel
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .background(Palette.canvas.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Palette.canvas)
        .environment(\.floatingNavInset, 0)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(Palette.primaryText)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(Capsule().fill(Palette.chipFill))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSaving)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: onSave) {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(Palette.onAccent)
                            .accessibilityLabel("Saving")
                    } else {
                        Text(saveTitle)
                            .font(.headline)
                            .foregroundStyle(Palette.onAccent)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(Palette.primaryGradient))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .opacity(canSave || isSaving ? 1 : 0.35)

            Text("Saved on this device first, then synced.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }
}

// MARK: - Menu picker

struct PickerOption: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String?
}

/// Picks one of several options from a menu, styled like the other fields.
struct PickerField: View {

    let title: String
    let options: [PickerOption]
    @Binding var selection: UUID

    private var selected: PickerOption? {
        options.first { $0.id == selection }
    }

    var body: some View {
        FieldLabel(title: title) {
            Menu {
                ForEach(options) { option in
                    Button {
                        selection = option.id
                    } label: {
                        if option.id == selection {
                            Label(menuText(option), systemImage: "checkmark")
                        } else {
                            Text(menuText(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected?.title ?? "Select")
                            .font(.body)
                            .foregroundStyle(Palette.primaryText)
                            .lineLimit(1)

                        if let subtitle = selected?.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .accessibilityHidden(true)
                }
                .fieldBox()
            }
            .accessibilityLabel(title)
            .accessibilityValue(selected?.title ?? "None selected")
        }
    }

    private func menuText(_ option: PickerOption) -> String {
        guard let subtitle = option.subtitle, !subtitle.isEmpty else {
            return option.title
        }

        return "\(option.title) · \(subtitle)"
    }
}

// MARK: - Date and time field

/// Shows a date or a time in a field. Tapping it opens the system picker in
/// a popover.
struct DateField: View {

    let title: String
    @Binding var date: Date
    let components: DatePickerComponents
    var includesYear = false
    var range: ClosedRange<Date> = Date.distantPast...Date.distantFuture

    @State private var isPresenting = false

    private var displayText: String {
        if components.contains(.date) {
            if includesYear {
                return date.formatted(
                    .dateTime.weekday(.abbreviated).day().month(.abbreviated).year()
                )
            }

            return date.formatted(
                .dateTime.weekday(.abbreviated).day().month(.abbreviated)
            )
        }

        return date.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        FieldLabel(title: title) {
            Button {
                isPresenting = true
            } label: {
                Text(displayText)
                    .font(.body)
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fieldBox(isFocused: isPresenting)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(displayText)
            .accessibilityHint("Opens a picker")
            .popover(isPresented: $isPresenting) {
                picker
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        if components.contains(.date) {
            DatePicker(
                title,
                selection: $date,
                in: range,
                displayedComponents: components
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(minWidth: 300)
        } else {
            DatePicker(
                title,
                selection: $date,
                in: range,
                displayedComponents: components
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(minWidth: 240)
        }
    }
}

#if DEBUG
private struct FormSheetPreview: View {

    @State private var date = Date()
    @State private var tourID = UUID()

    var body: some View {
        FormSheet(
            title: "New show",
            saveTitle: "Save show",
            canSave: true,
            isSaving: false,
            onCancel: {},
            onSave: {}
        ) {
            PickerField(
                title: "Tour",
                options: [
                    PickerOption(id: tourID, title: "Afterglow Tour", subtitle: "Midnight Parade")
                ],
                selection: $tourID
            )

            EditorField(
                title: "City",
                prompt: "e.g. Copenhagen",
                isRequired: true,
                text: .constant("Copenhagen")
            )

            HStack(spacing: 12) {
                DateField(title: "Date", date: $date, components: .date)
                DateField(title: "Time", date: $date, components: .hourAndMinute)
            }
        }
    }
}

#Preview("Form sheet, light") {
    FormSheetPreview()
        .preferredColorScheme(.light)
}

#Preview("Form sheet, dark") {
    FormSheetPreview()
        .preferredColorScheme(.dark)
}
#endif
