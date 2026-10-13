//
//  StatusBadge.swift
//  TourOps
//
//  Shared capsule badge. The domain-specific status calculations stay with
//  their features (ShowTimeStatus, TourTimelineStatus); this view only
//  renders a title and a color. The title is always shown as text, so the
//  status never depends on color alone.
//

import SwiftUI

struct StatusBadge: View {

    let title: String
    let color: Color

    /// Spoken before the title, e.g. "Status: Upcoming" or "Genre: Jazz".
    var accessibilityPrefix = "Status"

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay {
            Capsule()
                .strokeBorder(
                    color.opacity(0.65),
                    lineWidth: 0.8
                )
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityPrefix): \(title)")
    }
}

#if DEBUG
#Preview {
    HStack {
        StatusBadge(title: "Upcoming", color: Palette.chipAccent)
        StatusBadge(title: "In progress", color: Palette.statusActive)
        StatusBadge(title: "Past", color: Palette.secondaryText)
    }
    .padding(20)
    .background(Palette.canvas)
    .preferredColorScheme(.dark)
}
#endif
