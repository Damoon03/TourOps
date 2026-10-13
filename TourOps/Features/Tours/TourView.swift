//
//  TourView.swift
//  TourOps
//
//  Created by Damoon saber on 7/21/1405 AP.
//

import SwiftUI

enum TourTimelineStatus {
    case upcoming
    case inProgress
    case completed

    init(tour: Tour, referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let start = calendar.startOfDay(for: tour.startDate)
        let end = calendar.startOfDay(for: tour.endDate)

        if today < start {
            self = .upcoming
        } else if today > end {
            self = .completed
        } else {
            self = .inProgress
        }
    }

    var title: String {
        switch self {
        case .upcoming:
            "Upcoming"
        case .inProgress:
            "In progress"
        case .completed:
            "Completed"
        }
    }

    var color: Color {
        switch self {
        case .upcoming:
            Palette.chipAccent
        case .inProgress:
            Palette.genreJazz
        case .completed:
            Palette.secondaryText
        }
    }

    var symbol: String {
        switch self {
        case .upcoming:
            "calendar"
        case .inProgress:
            "waveform"
        case .completed:
            "checkmark.circle"
        }
    }
}

struct TourStatusBadge: View {

    let status: TourTimelineStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            Text(status.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay {
            Capsule()
                .strokeBorder(
                    status.color.opacity(0.65),
                    lineWidth: 0.8
                )
        }
        .fixedSize()
    }
}

struct TourView: View {

    let tour: Tour

    private var status: TourTimelineStatus {
        TourTimelineStatus(tour: tour)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.20))
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text(tour.name)
                        .font(
                            .system(
                                .headline,
                                design: .rounded,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(Palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    TourStatusBadge(status: status)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.top, 4)
            }

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.7)

            HStack(spacing: 0) {
                dateColumn(
                    title: "STARTS",
                    date: tour.startDate
                )

                Spacer(minLength: 12)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)

                Spacer(minLength: 12)

                dateColumn(
                    title: "ENDS",
                    date: tour.endDate
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }

    private func dateColumn(
        title: String,
        date: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Palette.secondaryText)

            Text(
                date.formatted(
                    date: .abbreviated,
                    time: .omitted
                )
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Shared tour date editor

struct TourDateRangeEditor: View {

    @Binding var startDate: Date
    @Binding var endDate: Date

    private var earliestEndDate: Date {
        Calendar.current.startOfDay(for: startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SCHEDULE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.secondaryText)

                Text("Tour dates")
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
            }

            DatePicker(
                "Starts",
                selection: $startDate,
                displayedComponents: .date
            )
            .tint(Palette.accent)

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.7)

            DatePicker(
                "Ends",
                selection: $endDate,
                in: earliestEndDate...,
                displayedComponents: .date
            )
            .tint(Palette.accent)
        }
        .font(.subheadline)
        .foregroundStyle(Palette.primaryText)
        .padding(18)
        .background {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
        .onChange(of: startDate) { _, newStartDate in
            let calendar = Calendar.current
            let newStartDay = calendar.startOfDay(
                for: newStartDate
            )
            let currentEndDay = calendar.startOfDay(
                for: endDate
            )

            if currentEndDay < newStartDay {
                endDate = newStartDay
            }
        }
    }
}

#Preview {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 16) {
                TourView(
                    tour: Tour(
                        id: UUID(),
                        teamID: UUID(),
                        name: "World Tour 2026",
                        startDate: .now.addingTimeInterval(
                            60 * 60 * 24 * 20
                        ),
                        endDate: .now.addingTimeInterval(
                            60 * 60 * 24 * 60
                        ),
                        createdAt: .now,
                        version: 1
                    )
                )
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}
