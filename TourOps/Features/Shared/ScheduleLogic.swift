//
//  ScheduleLogic.swift
//  TourOps
//
//  Pure ordering, summary and message logic shared by the Teams, Tours and
//  Shows screens. Nothing here touches SwiftUI or persistence.
//

import Foundation

// MARK: - Shows

enum ShowSchedule {

    struct Sections: Equatable {
        /// Today's and future shows, soonest first.
        var upcoming: [Show]
        /// Earlier shows, most recent first.
        var past: [Show]

        var isEmpty: Bool {
            upcoming.isEmpty && past.isEmpty
        }
    }

    static func sections(
        from shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Sections {
        var upcoming: [Show] = []
        var past: [Show] = []

        for show in shows {
            let status = ShowTimeStatus(
                date: show.date,
                referenceDate: now,
                calendar: calendar
            )

            if status.isUpcoming {
                upcoming.append(show)
            } else {
                past.append(show)
            }
        }

        upcoming.sort { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.date < rhs.date
        }

        past.sort { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.date > rhs.date
        }

        return Sections(upcoming: upcoming, past: past)
    }

    /// The earliest show that has not been over for a whole day, keeping the
    /// first one found when two share the same date.
    static func nextShow(
        in shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Show? {
        let today = calendar.startOfDay(for: now)
        var next: Show?

        for show in shows where calendar.startOfDay(for: show.date) >= today {
            if let current = next, current.date <= show.date {
                continue
            }

            next = show
        }

        return next
    }
}

// MARK: - Tours

enum TourSchedule {

    struct Sections: Equatable {
        /// In-progress and upcoming tours, earliest start first.
        var upcoming: [Tour]
        /// Completed tours, most recently finished first.
        var past: [Tour]

        var isEmpty: Bool {
            upcoming.isEmpty && past.isEmpty
        }
    }

    static func sections(
        from tours: [Tour],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Sections {
        var upcoming: [Tour] = []
        var past: [Tour] = []

        for tour in tours {
            let status = TourTimelineStatus(
                tour: tour,
                referenceDate: now,
                calendar: calendar
            )

            if status.isCurrentOrUpcoming {
                upcoming.append(tour)
            } else {
                past.append(tour)
            }
        }

        upcoming.sort { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.startDate < rhs.startDate
        }

        past.sort { lhs, rhs in
            if lhs.endDate == rhs.endDate {
                return lhs.createdAt > rhs.createdAt
            }

            return lhs.endDate > rhs.endDate
        }

        return Sections(upcoming: upcoming, past: past)
    }

    struct ShowSummary: Equatable {
        var showCount: Int
        var nextShow: Show?
    }

    static func showSummary(
        forTourID tourID: UUID,
        shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ShowSummary {
        let tourShows = shows.filter { $0.tourID == tourID }

        return ShowSummary(
            showCount: tourShows.count,
            nextShow: ShowSchedule.nextShow(
                in: tourShows,
                now: now,
                calendar: calendar
            )
        )
    }
}

// MARK: - Teams

enum TeamSchedule {

    /// The next upcoming show for each team, resolved through its tours.
    /// Used by the Teams list and, for a single team, by Team detail so both
    /// screens agree.
    static func nextShowsByTeamID(
        tours: [Tour],
        shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [UUID: Show] {
        let teamIDByTourID = Dictionary(
            tours.map { ($0.id, $0.teamID) },
            uniquingKeysWith: { first, _ in first }
        )

        let today = calendar.startOfDay(for: now)
        var upcoming: [UUID: Show] = [:]

        for show in shows where calendar.startOfDay(for: show.date) >= today {
            guard let teamID = teamIDByTourID[show.tourID] else {
                continue
            }

            if let current = upcoming[teamID], current.date <= show.date {
                continue
            }

            upcoming[teamID] = show
        }

        return upcoming
    }

    struct Summary: Equatable {
        var tourCount: Int
        var showCount: Int
        var nextShow: Show?
    }

    static func summary(
        forTeamID teamID: UUID,
        tours: [Tour],
        shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Summary {
        let teamTours = tours.filter { $0.teamID == teamID }
        let tourIDs = Set(teamTours.map(\.id))
        let teamShows = shows.filter { tourIDs.contains($0.tourID) }

        return Summary(
            tourCount: teamTours.count,
            showCount: teamShows.count,
            nextShow: nextShowsByTeamID(
                tours: teamTours,
                shows: teamShows,
                now: now,
                calendar: calendar
            )[teamID]
        )
    }
}

// MARK: - Delete confirmation text

/// Deleting a team or tour removes only that record. Related tours and shows
/// stay in the local store (there is no cascade), but nothing in the app can
/// reach them any more. The messages say exactly that.
enum DeletionMessage {

    private static let closing = "This action cannot be undone."

    static func team(tourCount: Int?, showCount: Int?) -> String {
        guard let tourCount, let showCount else {
            return "Tours and shows that belong to this team are not deleted with it, but you will no longer be able to open them in the app. \(closing)"
        }

        guard tourCount > 0 else {
            return closing
        }

        let related = "\(count(tourCount, "tour")) and \(count(showCount, "show"))"

        return "This team has \(related). They are not deleted with the team, but you will no longer be able to open them in the app. \(closing)"
    }

    static func tour(showCount: Int?) -> String {
        guard let showCount else {
            return "Shows that belong to this tour are not deleted with it, but you will no longer be able to open them in the app. \(closing)"
        }

        guard showCount > 0 else {
            return closing
        }

        return "This tour has \(count(showCount, "show")). They are not deleted with the tour, but you will no longer be able to open them in the app. \(closing)"
    }

    static func show() -> String {
        closing
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        value == 1 ? "1 \(noun)" : "\(value) \(noun)s"
    }
}
