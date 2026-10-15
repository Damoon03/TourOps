//
//  ScheduleAgenda.swift
//  TourOps
//
//  Pure derivations for the redesigned Schedule, Teams and Tour screens:
//  agenda grouping, week strips, team overviews and the tour timeline.
//  Everything here is computed from existing models on demand; nothing is
//  stored. No SwiftUI and no persistence.
//

import Foundation

// MARK: - Schedule

enum ScheduleAgenda {

    /// A show together with the tour and team it belongs to.
    struct Entry: Identifiable, Equatable {
        let show: Show
        let tour: Tour
        let team: Team

        var id: UUID { show.id }
    }

    struct DaySection: Identifiable, Equatable {
        let day: Date
        let entries: [Entry]

        var id: Date { day }
    }

    /// Shows joined with their tour and team, soonest first. A show whose
    /// tour or team no longer exists is dropped: deleting a team or tour does
    /// not cascade, and the app can no longer reach those shows.
    static func entries(
        shows: [Show],
        tours: [Tour],
        teams: [Team],
        teamFilter: UUID? = nil
    ) -> [Entry] {
        let toursByID = Dictionary(
            tours.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let teamsByID = Dictionary(
            teams.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var result: [Entry] = []

        for show in shows {
            guard
                let tour = toursByID[show.tourID],
                let team = teamsByID[tour.teamID]
            else {
                continue
            }

            if let teamFilter, team.id != teamFilter {
                continue
            }

            result.append(Entry(show: show, tour: tour, team: team))
        }

        result.sort { lhs, rhs in
            if lhs.show.date == rhs.show.date {
                return lhs.show.createdAt < rhs.show.createdAt
            }

            return lhs.show.date < rhs.show.date
        }

        return result
    }

    /// Day groups from `selectedDay` onward. The selected day is always the
    /// first group, even when it has no shows, so the screen can say so.
    /// Later days appear only when they have shows. `entries` must already
    /// be sorted, as returned by `entries(shows:tours:teams:teamFilter:)`.
    static func sections(
        entries: [Entry],
        from selectedDay: Date,
        calendar: Calendar = .current
    ) -> [DaySection] {
        let start = calendar.startOfDay(for: selectedDay)

        var grouped: [Date: [Entry]] = [:]

        for entry in entries {
            let day = calendar.startOfDay(for: entry.show.date)

            guard day >= start else {
                continue
            }

            grouped[day, default: []].append(entry)
        }

        var sections = grouped.keys.sorted().map { day in
            DaySection(day: day, entries: grouped[day] ?? [])
        }

        if sections.first?.day != start {
            sections.insert(DaySection(day: start, entries: []), at: 0)
        }

        return sections
    }

    /// The start of every day that has at least one show.
    static func daysWithShows(
        in entries: [Entry],
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.show.date) })
    }

    /// The seven days of the week that contains `date`, in the calendar's
    /// own week order.
    static func weekDays(
        containing date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let day = calendar.startOfDay(for: date)

        guard let week = calendar.dateInterval(of: .weekOfYear, for: day) else {
            return [day]
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: week.start)
        }
    }

    /// The first show that starts after `now`. `entries` must be sorted.
    static func nextUp(in entries: [Entry], now: Date = Date()) -> Entry? {
        entries.first { ShowSchedule.isAhead($0.show, of: now) }
    }

    /// The tour a new show most likely belongs to: the in-progress tour that
    /// started first, otherwise the next upcoming tour, otherwise the most
    /// recently finished one.
    static func defaultTour(
        in tours: [Tour],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Tour? {
        let sections = TourSchedule.sections(from: tours, now: now, calendar: calendar)

        let current = sections.upcoming.first {
            TourTimelineStatus(tour: $0, referenceDate: now, calendar: calendar) == .inProgress
        }

        return current ?? sections.upcoming.first ?? sections.past.first
    }
}

// MARK: - Load state

/// What the Schedule screen should show, given the outcome of its loads.
/// Keeps a failed load distinct from a genuinely empty schedule.
enum ScheduleLoadState: Equatable {
    /// First load still running (or a retry with nothing cached).
    case loading
    /// The load failed and there is nothing usable to show.
    case failed(String)
    /// The load failed, but previously loaded shows are still displayed.
    case stale(String)
    /// Loaded fine, but there are no teams yet.
    case noTeams
    /// Loaded fine; show the agenda (which may legitimately have no shows).
    case ready

    static func resolve(
        hasCompletedFirstLoad: Bool,
        isLoading: Bool,
        loadError: String?,
        hasShows: Bool,
        hasTeams: Bool
    ) -> ScheduleLoadState {
        if !hasCompletedFirstLoad || isLoading {
            return .loading
        }

        if let loadError {
            // Cached shows are only usable together with the teams they
            // belong to; otherwise the agenda would be empty anyway.
            return hasShows && hasTeams ? .stale(loadError) : .failed(loadError)
        }

        return hasTeams ? .ready : .noTeams
    }
}

// MARK: - Teams

enum TeamOverview {

    struct Info: Equatable {
        var tourCount: Int
        var showCount: Int
        /// The tour that is in progress today, if any.
        var currentTour: Tour?
        var nextShow: Show?
    }

    static func info(
        forTeamID teamID: UUID,
        tours: [Tour],
        shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Info {
        let summary = TeamSchedule.summary(
            forTeamID: teamID,
            tours: tours,
            shows: shows,
            now: now,
            calendar: calendar
        )

        let current = tours
            .filter { tour in
                tour.teamID == teamID
                    && TourTimelineStatus(
                        tour: tour,
                        referenceDate: now,
                        calendar: calendar
                    ) == .inProgress
            }
            .min { $0.startDate < $1.startDate }

        return Info(
            tourCount: summary.tourCount,
            showCount: summary.showCount,
            currentTour: current,
            nextShow: summary.nextShow
        )
    }
}

// MARK: - Tour timeline

enum TourTimeline {

    struct Marker: Identifiable, Equatable {
        let id: UUID
        /// 0 at the start of the tour, 1 at the end of its last day.
        let position: Double
        let isPlayed: Bool
        let isNext: Bool
    }

    struct Layout: Equatable {
        var markers: [Marker]
        /// `nil` when today is outside the tour's date range.
        var todayPosition: Double?
    }

    struct Stats: Equatable {
        var showCount: Int
        var playedCount: Int
        var upcomingCount: Int
        var nextShow: Show?
    }

    /// Only the shows that belong to `tour`.
    private static func shows(of tour: Tour, in shows: [Show]) -> [Show] {
        shows.filter { $0.tourID == tour.id }
    }

    static func stats(
        tour: Tour,
        shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Stats {
        let tourShows = Self.shows(of: tour, in: shows)
        let upcoming = tourShows.filter { ShowSchedule.isAhead($0, of: now) }

        return Stats(
            showCount: tourShows.count,
            playedCount: tourShows.count - upcoming.count,
            upcomingCount: upcoming.count,
            nextShow: ShowSchedule.nextShow(in: tourShows, now: now, calendar: calendar)
        )
    }

    /// Positions every show and today along the tour's date range. Shows
    /// outside the range are pinned to its nearest end, and a reversed range
    /// (end before start) is treated as a single day.
    static func layout(
        tour: Tour,
        shows: [Show],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Layout {
        let start = calendar.startOfDay(for: tour.startDate)
        let lastDay = max(start, calendar.startOfDay(for: tour.endDate))
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay)
            ?? lastDay.addingTimeInterval(86_400)
        let span = end.timeIntervalSince(start)

        func position(of date: Date) -> Double {
            guard span > 0 else {
                return 0
            }

            return min(max(date.timeIntervalSince(start) / span, 0), 1)
        }

        let tourShows = Self.shows(of: tour, in: shows)
        let nextID = ShowSchedule.nextShow(in: tourShows, now: now, calendar: calendar)?.id

        let markers = tourShows
            .sorted { $0.date < $1.date }
            .map { show in
                Marker(
                    id: show.id,
                    position: position(of: show.date),
                    isPlayed: !ShowSchedule.isAhead(show, of: now),
                    isNext: show.id == nextID
                )
            }

        let today: Double? = (now >= start && now < end) ? position(of: now) : nil

        return Layout(markers: markers, todayPosition: today)
    }

    /// "2 Oct – 28 Nov 2026". Falls back to two separate dates when the range
    /// is reversed, which the form prevents but synced data could contain.
    static func rangeText(for tour: Tour) -> String {
        if tour.startDate <= tour.endDate {
            return (tour.startDate..<tour.endDate).formatted(
                .interval.day().month(.abbreviated).year()
            )
        }

        let start = tour.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = tour.endDate.formatted(date: .abbreviated, time: .omitted)

        return "\(start) – \(end)"
    }
}
