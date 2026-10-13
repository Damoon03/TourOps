//
//  ShowTimeStatus.swift
//  TourOps
//

import SwiftUI

/// Where a show sits relative to today. Day granularity: a show later today
/// is "Today" until the day ends.
enum ShowTimeStatus: Equatable {
    case upcoming
    case today
    case past

    init(
        date: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
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
            Palette.statusActive
        case .past:
            Palette.secondaryText
        }
    }

    /// Today's and future shows.
    var isUpcoming: Bool {
        self != .past
    }
}
