//
//  PreviewSupport.swift
//  TourOps
//
//  Small in-memory fixtures for SwiftUI previews. DEBUG only.
//

#if DEBUG
import SwiftUI
import UIKit

enum PreviewData {

    struct PreviewError: LocalizedError {
        var errorDescription: String? {
            "The local database could not be read."
        }
    }

    static let teamID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    static let tourID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!

    static func date(daysFromNow days: Int) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: days,
            to: Calendar.current.startOfDay(for: Date())
        )?.addingTimeInterval(20 * 3600) ?? Date()
    }

    static let longName =
        "The Extraordinarily Long Named Touring Orchestra of Somewhere"

    // MARK: Teams

    static let team = Team(
        id: teamID,
        name: "Silver Echo",
        genre: "Indie Rock",
        country: "Germany",
        city: "Berlin",
        createdAt: date(daysFromNow: -90),
        version: 1
    )

    static let teamWithImage = Team(
        id: teamID,
        name: "Silver Echo",
        genre: "Indie Rock",
        country: "Germany",
        city: "Berlin",
        createdAt: date(daysFromNow: -90),
        version: 1,
        imageData: sampleImageData
    )

    static let longTeam = Team(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
        name: longName,
        genre: "Experimental Chamber Pop",
        country: "United Kingdom",
        city: "Reykjavík",
        createdAt: date(daysFromNow: -10),
        version: 1
    )

    static let emptyTeam = Team(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
        name: "Crew 7",
        genre: "",
        country: "",
        city: "",
        createdAt: date(daysFromNow: -1),
        version: 1
    )

    // MARK: Tours

    static let upcomingTour = Tour(
        id: tourID,
        teamID: teamID,
        name: "World Tour 2027",
        startDate: date(daysFromNow: 20),
        endDate: date(daysFromNow: 60),
        createdAt: date(daysFromNow: -30),
        version: 1
    )

    static let currentTour = Tour(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!,
        teamID: teamID,
        name: "Autumn Run",
        startDate: date(daysFromNow: -5),
        endDate: date(daysFromNow: 10),
        createdAt: date(daysFromNow: -40),
        version: 1
    )

    static let pastTour = Tour(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!,
        teamID: teamID,
        name: "Spring Warm-Up",
        startDate: date(daysFromNow: -120),
        endDate: date(daysFromNow: -90),
        createdAt: date(daysFromNow: -150),
        version: 1
    )

    static let longTour = Tour(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B4")!,
        teamID: teamID,
        name: "The Extraordinarily Long Named Farewell Anniversary Reunion Tour",
        startDate: date(daysFromNow: 100),
        endDate: date(daysFromNow: 160),
        createdAt: date(daysFromNow: -2),
        version: 1
    )

    // MARK: Shows

    static let upcomingShow = Show(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
        tourID: tourID,
        name: "Live in London",
        venue: "Roundhouse",
        city: "London",
        date: date(daysFromNow: 7),
        createdAt: date(daysFromNow: -20),
        version: 1
    )

    static let todayShow = Show(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!,
        tourID: tourID,
        name: "Homecoming",
        venue: "Columbiahalle",
        city: "Berlin",
        date: date(daysFromNow: 0),
        createdAt: date(daysFromNow: -20),
        version: 1
    )

    static let pastShow = Show(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!,
        tourID: tourID,
        name: "Opening Night",
        venue: "Fabrik",
        city: "Hamburg",
        date: date(daysFromNow: -14),
        createdAt: date(daysFromNow: -40),
        version: 1
    )

    static let longShow = Show(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C4")!,
        tourID: tourID,
        name: "An Evening With The Extraordinarily Long Named Touring Orchestra",
        venue: "The Grand Municipal Concert Hall and Convention Centre",
        city: "Llanfairpwllgwyngyll",
        date: date(daysFromNow: 30),
        createdAt: date(daysFromNow: -3),
        version: 1
    )

    // MARK: Image

    static var sampleImageData: Data {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor(red: 0.318, green: 0.251, blue: 0.937, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.94, green: 0.95, blue: 0.30, alpha: 1).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: 60, y: 60, width: 120, height: 120)
            )
        }
    }
}

// MARK: - In-memory repositories

enum PreviewRepositoryMode {
    case normal
    case failing
    case neverLoading
}

@MainActor
final class PreviewTeamRepository: TeamRepositoryProtocol {

    var teams: [Team]
    let mode: PreviewRepositoryMode

    init(teams: [Team] = [], mode: PreviewRepositoryMode = .normal) {
        self.teams = teams
        self.mode = mode
    }

    private func gate() async throws {
        switch mode {
        case .normal:
            break
        case .failing:
            throw PreviewData.PreviewError()
        case .neverLoading:
            try await Task.sleep(for: .seconds(3600))
        }
    }

    func fetchTeams() async throws -> [Team] {
        try await gate()
        return teams
    }

    func fetchTeam(id: UUID) async throws -> Team {
        try await gate()

        guard let team = teams.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        return team
    }

    func createTeam(_ team: Team) async throws {
        try await gate()
        teams.append(team)
    }

    func updateTeam(_ team: Team) async throws {
        try await gate()

        guard let index = teams.firstIndex(where: { $0.id == team.id }) else {
            throw RepositoryError.notFound
        }

        teams[index] = team
    }

    func deleteTeam(id: UUID) async throws {
        try await gate()
        teams.removeAll { $0.id == id }
    }
}

@MainActor
final class PreviewTourRepository: TourRepositoryProtocol {

    var tours: [Tour]
    let mode: PreviewRepositoryMode

    init(tours: [Tour] = [], mode: PreviewRepositoryMode = .normal) {
        self.tours = tours
        self.mode = mode
    }

    private func gate() async throws {
        switch mode {
        case .normal:
            break
        case .failing:
            throw PreviewData.PreviewError()
        case .neverLoading:
            try await Task.sleep(for: .seconds(3600))
        }
    }

    func fetchTours() async throws -> [Tour] {
        try await gate()
        return tours
    }

    func fetchTour(id: UUID) async throws -> Tour {
        try await gate()

        guard let tour = tours.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        return tour
    }

    func createTour(_ tour: Tour) async throws {
        try await gate()
        tours.append(tour)
    }

    func updateTour(_ tour: Tour) async throws {
        try await gate()

        guard let index = tours.firstIndex(where: { $0.id == tour.id }) else {
            throw RepositoryError.notFound
        }

        tours[index] = tour
    }

    func deleteTour(id: UUID) async throws {
        try await gate()
        tours.removeAll { $0.id == id }
    }
}

@MainActor
final class PreviewShowRepository: ShowRepositoryProtocol {

    var shows: [Show]
    let mode: PreviewRepositoryMode

    init(shows: [Show] = [], mode: PreviewRepositoryMode = .normal) {
        self.shows = shows
        self.mode = mode
    }

    private func gate() async throws {
        switch mode {
        case .normal:
            break
        case .failing:
            throw PreviewData.PreviewError()
        case .neverLoading:
            try await Task.sleep(for: .seconds(3600))
        }
    }

    func fetchShows() async throws -> [Show] {
        try await gate()
        return shows
    }

    func fetchShow(id: UUID) async throws -> Show {
        try await gate()

        guard let show = shows.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        return show
    }

    func createShow(_ show: Show) async throws {
        try await gate()
        shows.append(show)
    }

    func updateShow(_ show: Show) async throws {
        try await gate()

        guard let index = shows.firstIndex(where: { $0.id == show.id }) else {
            throw RepositoryError.notFound
        }

        shows[index] = show
    }

    func deleteShow(id: UUID) async throws {
        try await gate()
        shows.removeAll { $0.id == id }
    }
}
#endif
