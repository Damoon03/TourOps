//
//  ShowView.swift
//  TourOps
//
//  Created by Damoon saber on 7/21/1405 AP.
//

import SwiftUI

enum ShowTimeStatus {
    case upcoming
    case today
    case past

    init(date: Date, referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let showDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: referenceDate)

        if showDay < today {
            self = .past
        } else if showDay == today {
            self = .today
        } else {
            self = .upcoming
        }
    }

    var title: String {
        switch self {
        case .upcoming:
            "Upcoming"
        case .today:
            "Today"
        case .past:
            "Past"
        }
    }

    var color: Color {
        switch self {
        case .upcoming:
            Palette.chipAccent
        case .today:
            Palette.genreJazz
        case .past:
            Palette.secondaryText
        }
    }
}

struct ShowStatusBadge: View {

    let status: ShowTimeStatus

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

struct ShowView: View {

    let show: Show

    private var status: ShowTimeStatus {
        ShowTimeStatus(date: show.date)
    }

    private var venue: String {
        show.venue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var city: String {
        show.city.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            dateTile

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    Text(show.name)
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

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(
                            .system(size: 11, weight: .semibold)
                        )
                        .foregroundStyle(Palette.secondaryText)
                        .padding(.top, 4)
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .medium))

                    Text(locationSummary)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Text(
                        show.date.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.primaryText)

                    ShowStatusBadge(status: status)
                }
            }
        }
        .padding(14)
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

    private var dateTile: some View {
        VStack(spacing: 3) {
            Text(
                show.date.formatted(
                    .dateTime.month(.abbreviated)
                )
                .uppercased()
            )
            .font(.system(size: 10, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(Palette.chipAccent)

            Text(
                show.date.formatted(
                    .dateTime.day()
                )
            )
            .font(
                .system(
                    size: 27,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(Palette.primaryText)

            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(width: 62, height: 86)
        .background {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(Palette.surfaceRaised)
        }
        .accessibilityHidden(true)
    }

    private var locationSummary: String {
        switch (venue.isEmpty, city.isEmpty) {
        case (false, false):
            "\(venue) · \(city)"
        case (false, true):
            venue
        case (true, false):
            city
        case (true, true):
            "Location not set"
        }
    }
}

struct ShowEditorField: View {

    let title: String
    let prompt: String
    let symbol: String

    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Palette.secondaryText)

            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.chipAccent)
                    .frame(width: 22)

                TextField(prompt, text: $text)
                    .font(.body)
                    .foregroundStyle(Palette.primaryText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(Palette.canvas.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .strokeBorder(
                    Palette.hairline,
                    lineWidth: 0.7
                )
            }
        }
    }
}

struct ShowDateTimeEditor: View {

    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SCHEDULE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.secondaryText)

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
    }
}

#Preview {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 12) {
                ShowView(
                    show: Show(
                        id: UUID(),
                        tourID: UUID(),
                        name: "Live in London",
                        venue: "Roundhouse",
                        city: "London",
                        date: .now.addingTimeInterval(86_400 * 7),
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
