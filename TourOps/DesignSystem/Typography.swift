//
//  Typography.swift
//  TourOps
//
//  Branded type styles built on system text styles (SF Pro) so they follow
//  Dynamic Type.
//

import SwiftUI

extension Font {

    /// Small uppercase label that sits above a title or section.
    static let eyebrow = Font.caption2.weight(.bold)

    /// Large title used for the top of each tab screen.
    static let screenTitle = Font.largeTitle.weight(.bold)

    /// Title used for hero cards and detail headers.
    static let heroTitle = Font.title.weight(.bold)

    /// Title used for list cards.
    static let cardTitle = Font.headline.weight(.bold)
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
