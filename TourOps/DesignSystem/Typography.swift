//
//  Typography.swift
//  TourOps
//
//  Branded type styles built on system text styles so they follow Dynamic Type.
//

import SwiftUI

extension Font {

    /// Small uppercase label that sits above a title or section.
    static let eyebrow = Font.caption2.weight(.bold)

    /// Large rounded title used for screen headers and hero cards.
    static let heroTitle = Font.system(.title, design: .rounded, weight: .bold)

    /// Rounded title used for list cards.
    static let cardTitle = Font.system(.headline, design: .rounded, weight: .bold)
}

extension View {

    /// Eyebrow label styling: scalable caption, bold, tracked.
    func eyebrowStyle(_ color: Color = Palette.secondaryText) -> some View {
        self
            .font(.eyebrow)
            .tracking(1.2)
            .foregroundStyle(color)
    }
}
