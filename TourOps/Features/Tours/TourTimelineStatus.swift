//
//  TourTimelineStatus.swift
//  TourOps
//

import SwiftUI

/// Where a tour sits relative to today, by calendar day. A tour is
/// in progress from its start day through its end day, inclusive.
enum TourTimelineStatus: Equatable {
    case upcoming
    case inProgress
    case completed

    init(
        tour: Tour,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
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
            Palette.statusActive
        case .completed:
            Palette.secondaryText
        }
    }

    /// Upcoming and in-progress tours.
    var isCurrentOrUpcoming: Bool {
        self != .completed
    }
}
