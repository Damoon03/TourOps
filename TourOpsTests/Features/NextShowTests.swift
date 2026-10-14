//
//  NextShowTests.swift
//  TourOpsTests
//
//  The next-show rule compares instants: a show counts only if it starts
//  strictly after the reference time. Every test passes an explicit `now`.
//

import Foundation
import Testing
@testable import TourOps

struct NextShowTests {

    /// Fixed reference moment (2027-01-15 08:00:00 UTC).
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func hours(_ value: Double) -> Date {
        now.addingTimeInterval(value * 3_600)
    }

    private func show(
        _ name: String,
        tourID: UUID = UUID(),
        at date: Date
    ) -> Show {
        Show(
            id: UUID(),
            tourID: tourID,
            name: name,
            venue: "V",
            city: "C",
            date: date,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            version: 1
        )
    }

    private func next(_ shows: [Show]) -> Show? {
        ShowSchedule.nextShow(in: shows, now: now, calendar: calendar)
    }

    @Test
    func showEarlierTodayIsExcluded() {
        #expect(next([show("morning", at: hours(-2))]) == nil)
    }

    @Test
    func showLaterTodayIsEligible() {
        #expect(next([show("tonight", at: hours(2))])?.name == "tonight")
    }

    @Test
    func futureTodayWinsOverPastToday() {
        let shows = [
            show("earlier", at: hours(-2)),
            show("later", at: hours(3))
        ]

        #expect(next(shows)?.name == "later")
    }

    @Test
    func showTomorrowIsEligible() {
        #expect(next([show("tomorrow", at: hours(24))])?.name == "tomorrow")
    }

    @Test
    func pastShowsAreExcludedWhenNothingIsAhead() {
        let shows = [
            show("yesterday", at: hours(-24)),
            show("an hour ago", at: hours(-1))
        ]

        #expect(next(shows) == nil)
    }

    @Test
    func showStartingExactlyNowIsNotUpcoming() {
        #expect(next([show("now", at: now)]) == nil)
        #expect(next([show("one second later", at: now.addingTimeInterval(1))])?.name == "one second later")
    }

    @Test
    func earliestEligibleShowIsChosen() {
        let shows = [
            show("far", at: hours(72)),
            show("past", at: hours(-5)),
            show("soon", at: hours(4)),
            show("later", at: hours(10))
        ]

        #expect(next(shows)?.name == "soon")
    }

    @Test
    func nextShowsByTeamAppliesTheSameCutoffToEachTeam() {
        let teamA = UUID()
        let teamB = UUID()
        let teamC = UUID()

        func tour(_ team: UUID) -> Tour {
            Tour(
                id: UUID(), teamID: team, name: "T",
                startDate: hours(-1_000), endDate: hours(1_000),
                createdAt: hours(-2_000), version: 1
            )
        }

        let tourA = tour(teamA)
        let tourB = tour(teamB)
        let tourC = tour(teamC)

        let shows = [
            // Team A: one earlier today and one later today.
            show("A earlier", tourID: tourA.id, at: hours(-3)),
            show("A later", tourID: tourA.id, at: hours(5)),
            // Team B: only earlier today, so no next show.
            show("B earlier", tourID: tourB.id, at: hours(-1)),
            // Team C: exactly now (excluded) and tomorrow.
            show("C now", tourID: tourC.id, at: now),
            show("C tomorrow", tourID: tourC.id, at: hours(24))
        ]

        let result = TeamSchedule.nextShowsByTeamID(
            tours: [tourA, tourB, tourC],
            shows: shows,
            now: now,
            calendar: calendar
        )

        #expect(result[teamA]?.name == "A later")
        #expect(result[teamB] == nil)
        #expect(result[teamC]?.name == "C tomorrow")
    }

    @Test
    func dayLevelTodayStatusIsUnchangedByTheInstantRule() {
        let earlierToday = hours(-2)

        // Not "next"...
        #expect(next([show("earlier", at: earlierToday)]) == nil)
        // ...but still labelled "Today", which is a calendar-day concept.
        #expect(
            ShowTimeStatus(date: earlierToday, referenceDate: now, calendar: calendar) == .today
        )
    }
}
