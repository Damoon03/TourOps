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
