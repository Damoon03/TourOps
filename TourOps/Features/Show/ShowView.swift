//
//  ShowView.swift
//  TourOps
//
//  Created by Damoon saber on 7/21/1405 AP.
//

import SwiftUI

// MARK: - List card

struct ShowView: View {

    let show: Show

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var tileMinWidth: CGFloat = 62

    private var status: ShowTimeStatus {
        ShowTimeStatus(date: show.date)
    }

    /// One VoiceOver announcement for the whole card, including the full date
    /// (the visual date tile is hidden from accessibility so nothing is read
    /// twice).
    static func accessibilityLabel(
        for show: Show,
        status: ShowTimeStatus
    ) -> String {
        var parts = [
            show.name.trimmed,
            show.date.formatted(date: .complete, time: .shortened)
        ]

        if let location = show.spokenLocation {
            parts.append(location)
        }

        parts.append(status.title)

        return parts.joined(separator: ", ")
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
    }

    var body: some View {
        layout {
            dateTile

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    Text(show.name)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .padding(.top, 3)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption.weight(.medium))

                    Text(show.locationSummary ?? "Location not set")
                        .font(.subheadline)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        timeText
                        StatusBadge(title: status.title, color: status.color)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        timeText
                        StatusBadge(title: status.title, color: status.color)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Self.accessibilityLabel(for: show, status: status)
        )
    }

    private var timeText: some View {
        Text(show.date.formatted(date: .omitted, time: .shortened))
            .font(.caption.weight(.medium))
            .foregroundStyle(Palette.primaryText)
    }

    private var dateTile: some View {
        VStack(spacing: 3) {
            Text(show.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .eyebrowStyle(Palette.chipAccent)

            Text(show.date.formatted(.dateTime.day()))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.primaryText)

            Image(systemName: "calendar")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(minWidth: tileMinWidth)
        .fixedSize()
        .background {
            RoundedRectangle(
                cornerRadius: Radius.control,
                style: .continuous
            )
            .fill(Palette.surfaceRaised)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Date and time editor

struct ShowDateTimeEditor: View {

    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                SectionHeading("SCHEDULE")

                Text("Date and time")
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
            }

            DatePicker(
                "Show date and time",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .tint(Palette.accent)
            .foregroundStyle(Palette.primaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

#if DEBUG
#Preview("Upcoming, today, past") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 12) {
                ShowView(show: PreviewData.upcomingShow)
                ShowView(show: PreviewData.todayShow)
                ShowView(show: PreviewData.pastShow)
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Long text") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            ShowView(show: PreviewData.longShow)
                .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 12) {
                ShowView(show: PreviewData.upcomingShow)
                ShowView(show: PreviewData.longShow)
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
