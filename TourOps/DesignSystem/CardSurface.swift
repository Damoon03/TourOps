//
//  CardSurface.swift
//  TourOps
//

import SwiftUI

extension View {

    /// The standard TourOps card: a filled continuous rounded rectangle with a
    /// subtle hairline border. Light Mode adds a soft shadow; Dark Mode is
    /// border-only. The shape is also used as the hit-test shape.
    func cardSurface(
        radius: CGFloat = Radius.card,
        fill: Color = Palette.surface
    ) -> some View {
        modifier(CardSurfaceModifier(radius: radius, fill: fill))
    }
}

private struct CardSurfaceModifier: ViewModifier {

    let radius: CGFloat
    let fill: Color

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(
                        color: colorScheme == .dark
                            ? .clear
                            : Color.black.opacity(0.06),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.7)
            }
            .contentShape(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}

// MARK: - Round icon button

/// The round surface-colored label used for header actions such as "…".
struct RoundIconLabel: View {

    let systemName: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Palette.primaryText)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(Palette.surface)
                    .shadow(
                        color: colorScheme == .dark ? .clear : Color.black.opacity(0.07),
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            }
            .overlay {
                Circle().strokeBorder(Palette.hairline, lineWidth: 0.7)
            }
            .contentShape(Circle())
    }
}

// MARK: - Press feedback

/// Subtle press feedback for tappable cards inside a scroll view.
struct CardPressStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
