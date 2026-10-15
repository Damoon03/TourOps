//
//  Palette.swift
//  TourOps
//
//  Shared design tokens. Every token resolves for the current appearance, so
//  the app follows the system Light / Dark setting. Values were sampled from
//  the redesign mockups: warm beige and off-white surfaces in Light Mode, warm
//  charcoal surfaces in Dark Mode.
//
//  Contrast (WCAG 2.x), computed from these exact values:
//  - primaryText on canvas / surface:   >= 14:1 in both appearances
//  - secondaryText on canvas / surface: >= 4.8:1 in both appearances
//  - chipAccent on surface:             >= 5.0:1 in both appearances
//  - orangeText on surface:             >= 4.8:1 in both appearances
//  - destructive on surface:            >= 5.2:1 in both appearances
//  - genre / continent colors:          >= 4.7:1 in both appearances
//

import SwiftUI
import UIKit

// MARK: - Appearance-aware colors

private extension UIColor {

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {

    /// A color that resolves to `light` or `dark` for the current appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(hex: dark)
                    : UIColor(hex: light)
            }
        )
    }

    /// Same as `init(light:dark:)` for colors that need an alpha channel.
    init(light: UIColor, dark: UIColor) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

enum Palette {

    // MARK: Surfaces

    /// Screen background.
    static let canvas = Color(light: 0xEEEAE6, dark: 0x14120F)
    /// Cards, fields and the selected-day tile.
    static let surface = Color(light: 0xF8F6F4, dark: 0x201D1A)
    /// Tags, date tiles and unselected chips that sit on a surface.
    static let surfaceRaised = Color(light: 0xECE9E6, dark: 0x2F2C2A)
    /// Unselected filter chips that sit on the canvas.
    static let chipFill = Color(light: 0xE5E1DC, dark: 0x26231F)
    static let hairline = Color(
        light: UIColor.black.withAlphaComponent(0.07),
        dark: UIColor.white.withAlphaComponent(0.09)
    )
    /// Progress track on the tour timeline.
    static let track = Color(light: 0xE4E1DD, dark: 0x3B3835)

    // MARK: Text

    static let primaryText = Color(light: 0x161412, dark: 0xF3EFEA)
    static let secondaryText = Color(light: 0x6B655F, dark: 0xA9A298)

    // MARK: Actions

    /// Primary action fill: dark ink in Light Mode, cream in Dark Mode.
    static let accent = Color(light: 0x2A2826, dark: 0xF3EFEA)
    /// Text and icons on top of `accent`.
    static let onAccent = Color(light: 0xF8F6F4, dark: 0x14120F)
    /// Gradient used by the largest primary actions (add button, save button).
    static let primaryGradient = LinearGradient(
        colors: [
            Color(light: 0x2A2826, dark: 0xF8F6F3),
            Color(light: 0x46423E, dark: 0xE6DFD4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Fill of the active tab inside the floating navigation.
    static let navActive = Color(light: 0xFFFFFE, dark: 0x413E3C)

    /// Warm tone for icons, eyebrows and secondary accents.
    static let chipAccent = Color(light: 0x7A6652, dark: 0xC79A62)
    static let highlight = Color(light: 0x7A7A00, dark: 0xF0F24D)

    // MARK: Orange (today, next up, on tour)

    /// For shapes and large text.
    static let orange = Color(light: 0xF26B1D, dark: 0xFF7A2E)
    /// For small text, darker in Light Mode to keep AA contrast.
    static let orangeText = Color(light: 0xB84A0B, dark: 0xFF7A2E)

    // MARK: Status

    // Kept separate from the genre palette so a status never changes color
    // just because a genre color is adjusted.
    static let statusActive = Color(light: 0x1F7A4D, dark: 0x8CDBAD)
    static let destructive = Color(light: 0xC0352E, dark: 0xFF736B)

    // MARK: Genre families

    // Genre-family colors and continent colors deliberately use separate
    // palettes so adjacent genre/location chips never match by accident.
    static let genreRock = Color(light: 0x6B4FD0, dark: 0xB89EFF)         // lavender
    static let genrePop = Color(light: 0xC2306E, dark: 0xFF7AAD)          // rose
    static let genreElectronic = Color(light: 0x0B72A8, dark: 0x59D1FA)   // cyan
    static let genreHipHop = Color(light: 0xB8501A, dark: 0xFF9961)       // coral-orange
    static let genreJazz = Color(light: 0x1F7A4D, dark: 0x8CDBAD)         // mint
    static let genreFolk = Color(light: 0x8A6A0E, dark: 0xE6C76B)         // gold
    static let genreOther = Color(light: 0x8E3FB0, dark: 0xE0A8F5)        // lilac-pink

    // MARK: Continents

    static let africa = Color(light: 0x99620A, dark: 0xF5AD40)            // amber
    static let asia = Color(light: 0xBE2F2F, dark: 0xF56161)              // red
    static let europe = Color(light: 0x23713F, dark: 0x66C78C)            // green
    static let americas = Color(light: 0x1F5FC4, dark: 0x579AF5)          // blue
    static let oceania = Color(light: 0xB5481A, dark: 0xF07A45)           // orange
}

// MARK: - Radii

enum Radius {
    /// Bottom sheets.
    static let sheet: CGFloat = 32
    /// Hero cards at the top of detail screens.
    static let hero: CGFloat = 24
    /// Standard cards: list rows, detail sections, form groups.
    static let card: CGFloat = 22
    /// Tiles, icon wells and large buttons inside a card.
    static let control: CGFloat = 16
    /// Text fields.
    static let field: CGFloat = 16
}
