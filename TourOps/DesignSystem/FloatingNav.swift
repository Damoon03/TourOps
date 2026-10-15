//
//  FloatingNav.swift
//  TourOps
//
//  The floating capsule navigation, the round add button and the compact
//  create menu, as shown in the redesign mockups.
//

import SwiftUI

// MARK: - Layout metrics

enum FloatingNavMetrics {
    /// Height of the capsule and the diameter of the add button.
    static let barHeight: CGFloat = 64
    /// Distance from the bottom edge of the screen.
    static let bottomPadding: CGFloat = 22
    static let horizontalPadding: CGFloat = 10
    /// Bottom space scrolling content needs to clear the floating controls.
    static let contentInset: CGFloat = barHeight + bottomPadding + 20
}

private struct FloatingNavInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {

    /// Extra bottom space scrolling screens reserve so their last row can
    /// scroll clear of the floating navigation. Zero outside the app shell,
    /// for example inside sheets.
    var floatingNavInset: CGFloat {
        get { self[FloatingNavInsetKey.self] }
        set { self[FloatingNavInsetKey.self] = newValue }
    }
}

// MARK: - Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case schedule
    case teams

    var id: String { rawValue }

    var title: String {
        switch self {
        case .schedule: "Schedule"
        case .teams: "Teams"
        }
    }

    var symbol: String {
        switch self {
        case .schedule: "calendar"
        case .teams: "person.2"
        }
    }
}

// MARK: - Capsule

struct FloatingNavBar: View {

    @Binding var selection: AppTab

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var activeTabNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .frame(height: FloatingNavMetrics.barHeight)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Palette.hairline, lineWidth: 0.7)
        }
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 6
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.snappy(duration: 0.25)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.symbol)
                    .font(
                        dynamicTypeSize.isAccessibilitySize
                            ? Font.system(size: 24, weight: .medium)
                            : Font.body.weight(.medium)
                    )

                // At accessibility sizes the capsule cannot hold both labels
                // beside the add button, so it shows icons only. The tabs keep
                // their VoiceOver labels and the 52 pt touch target.
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(tab.title)
                        .font(.body.weight(isSelected ? .bold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(isSelected ? Palette.primaryText : Palette.secondaryText)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Palette.navActive)
                        .shadow(
                            color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
                            radius: 6,
                            x: 0,
                            y: 2
                        )
                        .matchedGeometryEffect(id: "activeTab", in: activeTabNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Add button

struct FloatingAddButton: View {

    let isOpen: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.onAccent)
                .rotationEffect(.degrees(isOpen ? 45 : 0))
                .frame(
                    width: FloatingNavMetrics.barHeight,
                    height: FloatingNavMetrics.barHeight
                )
                .background {
                    Circle().fill(Palette.primaryGradient)
                }
                .shadow(
                    color: colorScheme == .dark ? .clear : Color.black.opacity(0.18),
                    radius: 14,
                    x: 0,
                    y: 6
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Close menu" : "Add")
        .accessibilityHint(isOpen ? "" : "Opens a menu to add a show, tour or team")
    }
}

// MARK: - Create menu

enum CreateAction: String, Identifiable {
    case show
    case tour
    case team

    var id: String { rawValue }
}

struct CreateMenu: View {

    let canCreateShow: Bool
    let canCreateTour: Bool
    let onSelect: (CreateAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var iconWell: CGFloat = 32

    var body: some View {
        VStack(spacing: 2) {
            row(
                title: "New show",
                symbol: "calendar",
                action: .show,
                isEnabled: canCreateShow,
                isEmphasized: true,
                disabledHint: "Create a tour first"
            )

            row(
                title: "New tour",
                symbol: "point.topleft.down.curvedto.point.bottomright.up",
                action: .tour,
                isEnabled: canCreateTour,
                isEmphasized: false,
                disabledHint: "Create a team first"
            )

            row(
                title: "New team",
                symbol: "person.2",
                action: .team,
                isEnabled: true,
                isEmphasized: false,
                disabledHint: ""
            )
        }
        .padding(8)
        // A fixed 208 pt at normal sizes; the full width when text is large.
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 208)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.7)
        }
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.12),
            radius: 20,
            x: 0,
            y: 8
        )
    }

    private func row(
        title: String,
        symbol: String,
        action: CreateAction,
        isEnabled: Bool,
        isEmphasized: Bool,
        disabledHint: String
    ) -> some View {
        Button {
            onSelect(action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.primaryText)
                    .frame(width: iconWell, height: iconWell)
                    .background(Circle().fill(Palette.surfaceRaised))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background {
                if isEmphasized {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityHint(isEnabled ? "" : disabledHint)
    }
}
