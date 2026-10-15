//
//  TourView.swift
//  TourOps
//
//  Created by Damoon saber on 7/21/1405 AP.
//

import SwiftUI

// MARK: - List card

struct TourView: View {

    let tour: Tour

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var iconTile: CGFloat = 48

    private var status: TourTimelineStatus {
        TourTimelineStatus(tour: tour)
    }

    /// One announcement: name, status and the full date range.
    static func accessibilityLabel(
        for tour: Tour,
        status: TourTimelineStatus
    ) -> String {
        let start = tour.startDate.formatted(date: .long, time: .omitted)
        let end = tour.endDate.formatted(date: .long, time: .omitted)

        return "\(tour.name.trimmed), \(status.title), starts \(start), ends \(end)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(
                    cornerRadius: Radius.field,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.20))
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: iconTile, height: iconTile)

                VStack(alignment: .leading, spacing: 6) {
                    Text(tour.name)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    StatusBadge(title: status.title, color: status.color)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.top, 4)
            }

            HairlineDivider()

            dateRange
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: tour, status: status))
    }

    @ViewBuilder
    private var dateRange: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))

        layout {
            dateColumn(title: "STARTS", date: tour.startDate)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.top, 14)

                Spacer(minLength: 0)
            }

            dateColumn(title: "ENDS", date: tour.endDate)
        }
    }

    private func dateColumn(title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .eyebrowStyle()

            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Date range editor

struct TourDateRangeEditor: View {

    @Binding var startDate: Date
    @Binding var endDate: Date

    private var earliestEndDate: Date {
        Calendar.current.startOfDay(for: startDate)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DateField(
                title: "Starts",
                date: $startDate,
                components: .date,
                includesYear: true
            )

            DateField(
                title: "Ends",
                date: $endDate,
                components: .date,
                includesYear: true,
                range: earliestEndDate...Date.distantFuture
            )
        }
        .onChange(of: startDate) { _, newStartDate in
            // Same clamping rule as `TourDraft.setStartDate`.
            endDate = TourDateRange.normalizedEnd(
                start: newStartDate,
                end: endDate
            )
        }
    }
}

#if DEBUG
#Preview("Upcoming, current, past") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 12) {
                TourView(tour: PreviewData.upcomingTour)
                TourView(tour: PreviewData.currentTour)
                TourView(tour: PreviewData.pastTour)
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Long text, large type") {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            TourView(tour: PreviewData.longTour)
                .padding(20)
        }
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
