//
//  DetailComponents.swift
//  TourOps
//
//  Small building blocks shared by the Teams, Tours and Shows screens.
//  Each domain still composes its own hero card and screen layout.
//

import SwiftUI

// MARK: - Scrolling screen

/// Dark canvas plus a hidden-indicator scroll view with the standard gutters.
struct ScreenScroll<Content: View>: View {

    private let topPadding: CGFloat
    private let spacing: CGFloat
    private let content: Content

    /// Space reserved so the last row can scroll clear of the floating
    /// navigation. Zero inside sheets.
    @Environment(\.floatingNavInset) private var navInset

    init(
        topPadding: CGFloat = 16,
        spacing: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.topPadding = topPadding
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
                .padding(.bottom, 36 + navInset)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Headings

struct SectionHeading: View {

    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .eyebrowStyle()
            .accessibilityAddTraits(.isHeader)
    }
}

/// Eyebrow, title and optional subtitle used at the top of forms and lists.
struct ScreenHeader: View {

    let eyebrow: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .eyebrowStyle(Palette.chipAccent)

            Text(title)
                .font(.heroTitle)
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Detail card and rows

struct HairlineDivider: View {

    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 0.7)
            .accessibilityHidden(true)
    }
}

/// A titled card that stacks `DetailRow`s separated by hairlines.
struct DetailCard<Content: View>: View {

    let heading: String
    private let content: Content

    init(
        heading: String,
        @ViewBuilder content: () -> Content
    ) {
        self.heading = heading
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(heading)
                .padding(.bottom, 7)

            content
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

/// Icon, caption and value. Reads as one VoiceOver element ("Start date, ...").
struct DetailRow: View {

    let title: String
    let value: String
    let symbol: String

    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 23

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.chipAccent)
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Navigation card

/// Label for a card that pushes a related list (Tours, Shows).
struct NavigationCardLabel: View {

    let symbol: String
    let title: String
    let lines: [String]

    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = 52

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(
                cornerRadius: Radius.control,
                style: .continuous
            )
            .fill(Palette.accent.opacity(0.20))
            .overlay {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.chipAccent)
            }
            .frame(width: tileSize, height: tileSize)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)

                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Destructive button

struct DestructiveButton: View {

    let title: String
    let hint: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.destructive)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(
                        cornerRadius: Radius.control,
                        style: .continuous
                    )
                    .fill(Palette.destructive.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: Radius.control,
                        style: .continuous
                    )
                    .strokeBorder(
                        Palette.destructive.opacity(0.30),
                        lineWidth: 0.8
                    )
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityHint(hint)
    }
}
