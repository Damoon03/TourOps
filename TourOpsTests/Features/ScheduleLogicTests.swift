//
//  ScheduleLogicTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

struct ScheduleLogicTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func at(days: Int, hours: Int = 0) -> Date {
        now.addingTimeInterval(Double(days) * 86_400 + Double(hours) * 3_600)
    }

    private func show(
        _ name: String,
        tourID: UUID = UUID(),
        days: Int,
        created: Int = 0
    ) -> Show {
        Show(
            id: UUID(),
            tourID: tourID,
            name: name,
            venue: "V",
            city: "C",
            date: at(days: days),
            createdAt: at(days: created),
            version: 1
        )
    }

    private func tour(
        _ name: String,
        teamID: UUID = UUID(),
        start: Int,
        end: Int
    ) -> Tour {
        Tour(
            id: UUID(),
            teamID: teamID,
            name: name,
            startDate: at(days: start),
            endDate: at(days: end),
            createdAt: at(days: -100),
            version: 1
        )
    }

    @Test
    func showsSplitIntoUpcomingBeforePastAndSorted() {
        let shows = [
            show("past-old", days: -10),
            show("later", days: 9),
            show("past-recent", days: -2),
            show("soon", days: 1)
        ]

        let sections = ShowSchedule.sections(from: shows, now: now, calendar: calendar)

        #expect(sections.upcoming.map(\.name) == ["soon", "later"])
        #expect(sections.past.map(\.name) == ["past-recent", "past-old"])
    }

    @Test
    func showLaterTodayCountsAsUpcoming() {
        let tonight = Show(
            id: UUID(), tourID: UUID(), name: "Tonight", venue: "V", city: "C",
            date: at(days: 0, hours: 5), createdAt: now, version: 1
        )

        let sections = ShowSchedule.sections(from: [tonight], now: now, calendar: calendar)

        #expect(sections.upcoming.count == 1)
        #expect(ShowTimeStatus(date: tonight.date, referenceDate: now, calendar: calendar) == .today)
    }

    @Test
    func nextShowIgnoresPastAndPicksEarliest() {
        let shows = [show("past", days: -1), show("b", days: 5), show("a", days: 2)]

        #expect(ShowSchedule.nextShow(in: shows, now: now, calendar: calendar)?.name == "a")
        #expect(ShowSchedule.nextShow(in: [show("past", days: -1)], now: now, calendar: calendar) == nil)
    }

    @Test
    func tourStatusIsInclusiveOfStartAndEndDays() {
        let current = tour("c", start: 0, end: 0)
        let upcoming = tour("u", start: 1, end: 3)
        let done = tour("d", start: -5, end: -1)

        #expect(TourTimelineStatus(tour: current, referenceDate: now, calendar: calendar) == .inProgress)
        #expect(TourTimelineStatus(tour: upcoming, referenceDate: now, calendar: calendar) == .upcoming)
        #expect(TourTimelineStatus(tour: done, referenceDate: now, calendar: calendar) == .completed)
    }

    @Test
    func tourSectionsPutCurrentAndUpcomingBeforeCompleted() {
        let tours = [
            tour("done", start: -9, end: -5),
            tour("later", start: 20, end: 30),
            tour("current", start: -1, end: 4)
        ]

        let sections = TourSchedule.sections(from: tours, now: now, calendar: calendar)

        #expect(sections.upcoming.map(\.name) == ["current", "later"])
        #expect(sections.past.map(\.name) == ["done"])
    }

    @Test
    func tourSummaryCountsOnlyItsOwnShows() {
        let mine = UUID()
        let shows = [
            show("a", tourID: mine, days: 3),
            show("b", tourID: mine, days: -3),
            show("other", days: 1)
        ]

        let summary = TourSchedule.showSummary(forTourID: mine, shows: shows, now: now, calendar: calendar)

        #expect(summary.showCount == 2)
        #expect(summary.nextShow?.name == "a")
    }

    @Test
    func teamSummaryResolvesShowsThroughTours() {
        let teamID = UUID()
        let mine = tour("t", teamID: teamID, start: 0, end: 10)
        let other = tour("o", start: 0, end: 10)
        let shows = [
            show("x", tourID: mine.id, days: 4),
            show("y", tourID: other.id, days: 1)
        ]

        let summary = TeamSchedule.summary(
            forTeamID: teamID, tours: [mine, other], shows: shows, now: now, calendar: calendar
        )

        #expect(summary.tourCount == 1)
        #expect(summary.showCount == 1)
        #expect(summary.nextShow?.name == "x")
    }

    @Test
    func deleteMessagesNeverClaimACascade() {
        let team = DeletionMessage.team(tourCount: 2, showCount: 5)
        let tour = DeletionMessage.tour(showCount: 1)

        #expect(team.contains("2 tours and 5 shows"))
        #expect(team.contains("not deleted"))
        #expect(tour.contains("1 show."))
        #expect(!team.lowercased().contains("will be deleted"))
        #expect(DeletionMessage.show() == "This action cannot be undone.")
        #expect(DeletionMessage.team(tourCount: 0, showCount: 0) == "This action cannot be undone.")
    }

    @Test
    func listPhaseSeparatesLoadingFailureAndEmpty() {
        func phase(loading: Bool, first: Bool, empty: Bool, error: String?) -> String {
            switch ListPhase<Int>.resolve(
                isLoading: loading, hasCompletedFirstLoad: first,
                isEmpty: empty, loadError: error, populated: { 1 }
            ) {
            case .loading: "loading"
            case .failed: "failed"
            case .empty: "empty"
            case .populated: "populated"
            }
        }

        #expect(phase(loading: false, first: false, empty: true, error: nil) == "loading")
        #expect(phase(loading: false, first: true, empty: true, error: "x") == "failed")
        #expect(phase(loading: false, first: true, empty: true, error: nil) == "empty")
        #expect(phase(loading: false, first: true, empty: false, error: "x") == "populated")
    }
}
