//
//  ScheduleAgendaTests.swift
//  TourOpsTests
//
//  Pure derivations behind the redesigned Schedule, Teams and Tour screens.
//  Every test passes an explicit calendar and `now`.
//

import Foundation
import Testing
@testable import TourOps

struct ScheduleAgendaTests {

    /// 2027-01-15 08:00:00 UTC, a Friday.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    private func days(_ value: Double, hours extra: Double = 0) -> Date {
        now.addingTimeInterval(value * 86_400 + extra * 3_600)
    }

    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func team(_ name: String = "Team") -> Team {
        Team(
            id: UUID(),
            name: name,
            genre: "",
            country: "",
            city: "",
            createdAt: createdAt,
            version: 1
        )
    }

    private func tour(
        teamID: UUID,
        start: Double = -10,
        end: Double = 10
    ) -> Tour {
        Tour(
            id: UUID(),
            teamID: teamID,
            name: "Tour",
            startDate: days(start),
            endDate: days(end),
            createdAt: createdAt,
            version: 1
        )
    }

    private func show(tourID: UUID, at date: Date) -> Show {
        Show(
            id: UUID(),
            tourID: tourID,
            name: "Show",
            venue: "Venue",
            city: "City",
            date: date,
            createdAt: createdAt,
            version: 1
        )
    }

    // MARK: Entries

    @Test
    func entriesAreSortedAndOrphansAreDropped() {
        let team = team()
        let tour = tour(teamID: team.id)

        let late = show(tourID: tour.id, at: days(2))
        let early = show(tourID: tour.id, at: days(1))
        let orphan = show(tourID: UUID(), at: days(1))

        let entries = ScheduleAgenda.entries(
            shows: [late, orphan, early],
            tours: [tour],
            teams: [team]
        )

        #expect(entries.map(\.show.id) == [early.id, late.id])
    }

    @Test
    func teamFilterKeepsOnlyThatTeam() {
        let first = team("First")
        let second = team("Second")
        let firstTour = tour(teamID: first.id)
        let secondTour = tour(teamID: second.id)

        let firstShow = show(tourID: firstTour.id, at: days(1))
        let secondShow = show(tourID: secondTour.id, at: days(1))

        let entries = ScheduleAgenda.entries(
            shows: [firstShow, secondShow],
            tours: [firstTour, secondTour],
            teams: [first, second],
            teamFilter: second.id
        )

        #expect(entries.map(\.show.id) == [secondShow.id])
    }

    // MARK: Sections

    @Test
    func selectedDayIsAlwaysTheFirstSectionEvenWhenEmpty() {
        let team = team()
        let tour = tour(teamID: team.id)
        let later = show(tourID: tour.id, at: days(3))

        let entries = ScheduleAgenda.entries(
            shows: [later],
            tours: [tour],
            teams: [team]
        )

        let sections = ScheduleAgenda.sections(
            entries: entries,
            from: now,
            calendar: calendar
        )

        #expect(sections.count == 2)
        #expect(sections[0].day == calendar.startOfDay(for: now))
        #expect(sections[0].entries.isEmpty)
        #expect(sections[1].entries.map(\.show.id) == [later.id])
    }

    @Test
    func earlierDaysAreExcludedAndSameDayShowsAreGrouped() {
        let team = team()
        let tour = tour(teamID: team.id)

        let earlier = show(tourID: tour.id, at: days(-1))
        let morning = show(tourID: tour.id, at: days(0, hours: -2))
        let evening = show(tourID: tour.id, at: days(0, hours: 6))

        let entries = ScheduleAgenda.entries(
            shows: [earlier, evening, morning],
            tours: [tour],
            teams: [team]
        )

        let sections = ScheduleAgenda.sections(
            entries: entries,
            from: now,
            calendar: calendar
        )

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.show.id) == [morning.id, evening.id])
    }

    @Test
    func daysWithShowsContainsEachDayOnce() {
        let team = team()
        let tour = tour(teamID: team.id)

        let entries = ScheduleAgenda.entries(
            shows: [
                show(tourID: tour.id, at: days(1, hours: -3)),
                show(tourID: tour.id, at: days(1, hours: 5)),
                show(tourID: tour.id, at: days(2))
            ],
            tours: [tour],
            teams: [team]
        )

        let result = ScheduleAgenda.daysWithShows(in: entries, calendar: calendar)

        #expect(result.count == 2)
        #expect(result.contains(calendar.startOfDay(for: days(1))))
        #expect(result.contains(calendar.startOfDay(for: days(2))))
    }

    // MARK: Week

    @Test
    func weekRunsMondayToSundayAroundTheDate() {
        let week = ScheduleAgenda.weekDays(containing: now, calendar: calendar)

        #expect(week.count == 7)
        #expect(calendar.component(.weekday, from: week[0]) == 2)
        #expect(week[0] == calendar.startOfDay(for: days(-4)))
        #expect(week[6] == calendar.startOfDay(for: days(2)))
        #expect(week.contains(calendar.startOfDay(for: now)))
    }

    // MARK: Next up

    @Test
    func nextUpSkipsShowsThatAlreadyStarted() {
        let team = team()
        let tour = tour(teamID: team.id)

        let started = show(tourID: tour.id, at: days(0, hours: -1))
        let upcoming = show(tourID: tour.id, at: days(0, hours: 2))

        let entries = ScheduleAgenda.entries(
            shows: [started, upcoming],
            tours: [tour],
            teams: [team]
        )

        #expect(ScheduleAgenda.nextUp(in: entries, now: now)?.show.id == upcoming.id)
    }

    // MARK: Default tour

    @Test
    func defaultTourPrefersTheTourInProgress() {
        let team = team()
        let future = tour(teamID: team.id, start: 20, end: 40)
        let current = tour(teamID: team.id, start: -5, end: 5)
        let past = tour(teamID: team.id, start: -60, end: -30)

        let result = ScheduleAgenda.defaultTour(
            in: [past, future, current],
            now: now,
            calendar: calendar
        )

        #expect(result?.id == current.id)
    }

    @Test
    func defaultTourFallsBackToMostRecentWhenAllArePast() {
        let team = team()
        let older = tour(teamID: team.id, start: -90, end: -60)
        let newer = tour(teamID: team.id, start: -50, end: -30)

        let result = ScheduleAgenda.defaultTour(
            in: [older, newer],
            now: now,
            calendar: calendar
        )

        #expect(result?.id == newer.id)
        #expect(ScheduleAgenda.defaultTour(in: [], now: now, calendar: calendar) == nil)
    }

    // MARK: Team overview

    @Test
    func teamOverviewCountsAndFindsCurrentTour() {
        let team = team()
        let current = tour(teamID: team.id, start: -5, end: 5)
        let future = tour(teamID: team.id, start: 20, end: 30)
        let other = tour(teamID: UUID(), start: -5, end: 5)

        let shows = [
            show(tourID: current.id, at: days(-1)),
            show(tourID: current.id, at: days(1)),
            show(tourID: future.id, at: days(21)),
            show(tourID: other.id, at: days(1))
        ]

        let info = TeamOverview.info(
            forTeamID: team.id,
            tours: [current, future, other],
            shows: shows,
            now: now,
            calendar: calendar
        )

        #expect(info.tourCount == 2)
        #expect(info.showCount == 3)
        #expect(info.currentTour?.id == current.id)
        #expect(info.nextShow?.date == days(1))
    }

    @Test
    func teamOverviewHasNoCurrentTourBetweenTours() {
        let team = team()
        let future = tour(teamID: team.id, start: 20, end: 30)

        let info = TeamOverview.info(
            forTeamID: team.id,
            tours: [future],
            shows: [],
            now: now,
            calendar: calendar
        )

        #expect(info.currentTour == nil)
        #expect(info.nextShow == nil)
    }

    // MARK: Tour timeline

    @Test
    func timelineStatsSplitPlayedFromUpcoming() {
        let team = team()
        let tour = tour(teamID: team.id)

        let shows = [
            show(tourID: tour.id, at: days(-2)),
            show(tourID: tour.id, at: days(-1)),
            show(tourID: tour.id, at: days(1)),
            show(tourID: tour.id, at: days(3)),
            show(tourID: UUID(), at: days(2))
        ]

        let stats = TourTimeline.stats(tour: tour, shows: shows, now: now, calendar: calendar)

        #expect(stats.showCount == 4)
        #expect(stats.playedCount == 2)
        #expect(stats.upcomingCount == 2)
        #expect(stats.nextShow?.date == days(1))
    }

    @Test
    func timelineMarksNextShowAndTodayInsideTheRange() {
        let team = team()
        let tour = tour(teamID: team.id, start: -10, end: 10)

        let played = show(tourID: tour.id, at: days(-5))
        let next = show(tourID: tour.id, at: days(2))
        let later = show(tourID: tour.id, at: days(8))

        let layout = TourTimeline.layout(
            tour: tour,
            shows: [later, played, next],
            now: now,
            calendar: calendar
        )

        #expect(layout.markers.map(\.id) == [played.id, next.id, later.id])
        #expect(layout.markers.map(\.isPlayed) == [true, false, false])
        #expect(layout.markers.map(\.isNext) == [false, true, false])
        #expect(layout.markers[0].position < layout.markers[1].position)
        #expect(layout.markers[1].position < layout.markers[2].position)

        let today = layout.todayPosition
        #expect(today != nil)
        #expect((today ?? 0) > layout.markers[0].position)
        #expect((today ?? 1) < layout.markers[1].position)
    }

    @Test
    func timelinePinsShowsOutsideTheRangeAndHidesToday() {
        let team = team()
        let tour = tour(teamID: team.id, start: 5, end: 10)

        let before = show(tourID: tour.id, at: days(-30))
        let after = show(tourID: tour.id, at: days(40))

        let layout = TourTimeline.layout(
            tour: tour,
            shows: [before, after],
            now: now,
            calendar: calendar
        )

        #expect(layout.markers.map(\.position) == [0, 1])
        #expect(layout.todayPosition == nil)
    }

    @Test
    func timelineSurvivesAReversedRangeAndNoShows() {
        let team = team()
        let reversed = tour(teamID: team.id, start: 5, end: -5)

        let layout = TourTimeline.layout(
            tour: reversed,
            shows: [],
            now: now,
            calendar: calendar
        )

        #expect(layout.markers.isEmpty)
        #expect(!TourTimeline.rangeText(for: reversed).isEmpty)
    }

    // MARK: Monogram

    @Test
    func monogramUsesInitialsOfTheFirstWords() {
        #expect("Midnight Parade".monogram(maxLetters: 2) == "MP")
        #expect("Midnight Parade".monogram() == "M")
        #expect("  velvet static  ".monogram(maxLetters: 2) == "VS")
        #expect("Cher".monogram(maxLetters: 2) == "CH")
        #expect("   ".monogram() == "?")
    }
}
