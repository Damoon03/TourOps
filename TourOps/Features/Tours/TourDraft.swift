//
//  TourDraft.swift
//  TourOps
//

import Foundation

/// Date-range rules for a tour, compared by calendar day.
enum TourDateRange {

    /// An end day on or after the start day.
    static func isValid(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.startOfDay(for: end) >= calendar.startOfDay(for: start)
    }

    /// The end date to use after the start date changes: unchanged if it is
    /// still valid, otherwise moved to the start day.
    static func normalizedEnd(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> Date {
        isValid(start: start, end: end, calendar: calendar)
            ? end
            : calendar.startOfDay(for: start)
    }
}

/// The editable state of the Create and Edit Tour forms.
struct TourDraft: Equatable {

    var name = ""
    var startDate = Date()
    var endDate = Date()

    init() {}

    init(tour: Tour) {
        name = tour.name
        startDate = tour.startDate
        endDate = tour.endDate
    }

    /// Changes the start date and keeps the end date valid.
    mutating func setStartDate(
        _ newStart: Date,
        calendar: Calendar = .current
    ) {
        startDate = newStart
        endDate = TourDateRange.normalizedEnd(
            start: newStart,
            end: endDate,
            calendar: calendar
        )
    }

    func isValid(calendar: Calendar = .current) -> Bool {
        !name.trimmed.isEmpty
            && TourDateRange.isValid(
                start: startDate,
                end: endDate,
                calendar: calendar
            )
    }

    /// Builds the tour to create, or `nil` if the draft is invalid.
    func newTour(
        id: UUID,
        teamID: UUID,
        createdAt: Date = Date(),
        calendar: Calendar = .current
    ) -> Tour? {
        guard isValid(calendar: calendar) else {
            return nil
        }

        return Tour(
            id: id,
            teamID: teamID,
            name: name.trimmed,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            version: 1
        )
    }

    /// Builds the updated tour, or `nil` if the draft is invalid.
    func updatedTour(
        from original: Tour,
        calendar: Calendar = .current
    ) -> Tour? {
        guard isValid(calendar: calendar) else {
            return nil
        }

        return Tour(
            id: original.id,
            teamID: original.teamID,
            name: name.trimmed,
            startDate: startDate,
            endDate: endDate,
            createdAt: original.createdAt,
            version: original.version
        )
    }
}
