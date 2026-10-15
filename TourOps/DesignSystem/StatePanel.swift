//
//  StatePanel.swift
//  TourOps
//
//  Shared loading, failed and empty panels for the list screens. The three
//  states stay distinct: callers choose which one to show and what each
//  action does.
//

import SwiftUI

// MARK: - Failed / empty panel

struct StatePanel: View {

    let symbol: String
    let title: String
    let message: String

    var actionTitle: String? = nil
    var isPrimaryAction = true
    var action: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .title) private var iconWell: CGFloat = 76

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.surfaceRaised)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.title.weight(.medium))
                            .foregroundStyle(Palette.chipAccent)
                    }
                    .frame(width: iconWell, height: iconWell)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.primaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.body)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(PillButtonStyle(isProminent: isPrimaryAction))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Loading panel

struct LoadingPanel: View {

    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Palette.secondaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pill button

struct PillButtonStyle: ButtonStyle {

    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? Palette.onAccent : Palette.primaryText)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background {
                Capsule()
                    .fill(isProminent ? Palette.accent : Palette.surfaceRaised)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

#if DEBUG
#Preview("Empty, light") {
    StatePanel(
        symbol: "music.mic",
        title: "No shows yet",
        message: "Add a performance to start building this tour’s schedule.",
        actionTitle: "Create Show",
        action: {}
    )
    .background(Palette.canvas)
    .preferredColorScheme(.light)
}

#Preview("Empty, dark") {
    StatePanel(
        symbol: "music.mic",
        title: "No shows yet",
        message: "Add a performance to start building this tour’s schedule.",
        actionTitle: "Create Show",
        action: {}
    )
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Failed, large text") {
    StatePanel(
        symbol: "exclamationmark.triangle",
        title: "Couldn’t load shows",
        message: "The local database could not be read.",
        actionTitle: "Try Again",
        isPrimaryAction: false,
        action: {}
    )
    .background(Palette.canvas)
    .dynamicTypeSize(.accessibility3)
}

#Preview("Loading") {
    LoadingPanel(message: "Loading shows…")
        .background(Palette.canvas)
}
#endif
