//
//  Palette.swift
//  TourOps
//
//  Shared design tokens. TourOps is deliberately a dark-only app: the
//  appearance is forced once, at the app root (see TourOpsApp), and every
//  token below is defined for that dark appearance only.
//
//  Contrast (WCAG 2.x) of the text tokens against the three surfaces was
//  computed from these exact values:
//  - primaryText:   >= 14.4:1
//  - secondaryText: >= 6.2:1
//  - chipAccent:    >= 7.4:1
//  - destructive:   >= 5.9:1
//  - genre / continent colors: >= 5.0:1
//  - white on accent: 6.3:1
//

import SwiftUI

enum Palette {
    // Restrained near-black surfaces with indigo accents.
    static let canvas = Color(red: 0.043, green: 0.043, blue: 0.071)       // #0B0B12
    static let surface = Color(red: 0.090, green: 0.090, blue: 0.125)      // #171720
    static let surfaceRaised = Color(red: 0.137, green: 0.133, blue: 0.180)
    static let hairline = Color.white.opacity(0.085)

    static let primaryText = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let secondaryText = Color(red: 0.64, green: 0.63, blue: 0.70)

    static let accent = Color(red: 0.318, green: 0.251, blue: 0.937)       // #5140EF
    static let chipAccent = Color(red: 0.70, green: 0.66, blue: 1.00)
    static let highlight = Color(red: 0.94, green: 0.95, blue: 0.30)

    // Status colors. Kept separate from the genre palette so a status never
    // changes color just because a genre color is adjusted.
    static let statusActive = Color(red: 0.55, green: 0.86, blue: 0.68)    // mint
    static let destructive = Color(red: 1.00, green: 0.45, blue: 0.42)

    // Genre-family colors and continent colors deliberately use separate palettes.
    // This prevents adjacent genre/location chips from accidentally matching.
    static let genreRock = Color(red: 0.72, green: 0.62, blue: 1.00)       // lavender
    static let genrePop = Color(red: 1.00, green: 0.48, blue: 0.68)        // rose
    static let genreElectronic = Color(red: 0.35, green: 0.82, blue: 0.98) // cyan
    static let genreHipHop = Color(red: 1.00, green: 0.60, blue: 0.38)    // coral-orange
    static let genreJazz = Color(red: 0.55, green: 0.86, blue: 0.68)      // mint
    static let genreFolk = Color(red: 0.90, green: 0.78, blue: 0.42)      // gold
    static let genreOther = Color(red: 0.88, green: 0.66, blue: 0.96)     // lilac-pink

    // One stable color per continent. These differ from every genre-family color.
    static let africa = Color(red: 0.96, green: 0.68, blue: 0.25)         // amber
    static let asia = Color(red: 0.96, green: 0.38, blue: 0.38)            // red
    static let europe = Color(red: 0.40, green: 0.78, blue: 0.55)          // green
    static let americas = Color(red: 0.34, green: 0.60, blue: 0.96)        // blue
    static let oceania = Color(red: 0.94, green: 0.48, blue: 0.27)        // orange
}

// MARK: - Radii

enum Radius {
    /// Hero cards at the top of detail screens.
    static let hero: CGFloat = 24
    /// Standard cards: list rows, detail sections, form groups.
    static let card: CGFloat = 22
    /// Tiles, icon wells and large buttons inside a card.
    static let control: CGFloat = 16
    /// Text fields.
    static let field: CGFloat = 14
}
