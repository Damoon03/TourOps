//
//  DraftTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

struct DraftTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 86_400)
    }

    // MARK: Tour date range

    @Test
    func endBeforeStartIsInvalid() {
        #expect(!TourDateRange.isValid(start: day(5), end: day(4), calendar: calendar))
    }

    @Test
    func sameDayRangeIsValid() {
        #expect(TourDateRange.isValid(start: day(5), end: day(5), calendar: calendar))
    }

    @Test
    func movingStartPastEndClampsEndToStartDay() {
        var draft = TourDraft()
        draft.name = "Tour"
        draft.startDate = day(0)
        draft.endDate = day(2)

        draft.setStartDate(day(10), calendar: calendar)

        #expect(calendar.startOfDay(for: draft.endDate) == calendar.startOfDay(for: day(10)))
        #expect(draft.isValid(calendar: calendar))
    }

    @Test
    func movingStartEarlierKeepsEnd() {
        var draft = TourDraft()
        draft.startDate = day(5)
        draft.endDate = day(8)

        draft.setStartDate(day(1), calendar: calendar)

        #expect(draft.endDate == day(8))
    }

    @Test
    func tourDraftTrimsNameAndRejectsBlank() {
        var draft = TourDraft()
        draft.name = "  Autumn Run \n"
        draft.startDate = day(0)
        draft.endDate = day(3)

        let tour = draft.newTour(id: UUID(), teamID: UUID(), calendar: calendar)
        #expect(tour?.name == "Autumn Run")

        draft.name = "   "
        #expect(draft.newTour(id: UUID(), teamID: UUID(), calendar: calendar) == nil)
    }

    // MARK: Show

    @Test
    func showDraftRequiresNameVenueAndCityAfterTrimming() {
        var draft = ShowDraft()
        draft.name = "Live"
        draft.venue = "  "
        draft.city = "London"

        #expect(!draft.isValid)
        #expect(draft.newShow(id: UUID(), tourID: UUID()) == nil)

        draft.venue = " Roundhouse "
        let show = draft.newShow(id: UUID(), tourID: UUID())
        #expect(show?.venue == "Roundhouse")
    }

    // MARK: Team

    @Test
    func teamDraftOnlyRequiresName() {
        var draft = TeamDraft()
        #expect(!draft.isValid)

        draft.name = " Silver Echo "
        let team = draft.newTeam(id: UUID())

        #expect(team?.name == "Silver Echo")
        #expect(team?.genre == "")
        #expect(team?.imageData == nil)
    }
}
