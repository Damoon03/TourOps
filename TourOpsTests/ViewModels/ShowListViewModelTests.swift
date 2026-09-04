//
//  ShowListViewModelTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct ShowListViewModelTests {

    @Test
    @MainActor
    func loadShowsSuccessfullyUpdatesShows() async {
        let repository = TestShowRepository()

        let show1 = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        let show2 = Show(
            id: UUID(),
            tourID: UUID(),
            name: "Manchester Show",
            venue: "AO Arena",
            city: "Manchester",
            date: Date().addingTimeInterval(86400),
            createdAt: Date(),
            version: 1
        )

        repository.shows = [show1, show2]

        let viewModel = ShowListViewModel(
            repository: repository
        )

        await viewModel.loadShows()

        #expect(viewModel.shows == [show1, show2])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func loadShowsFailsWithError() async {
        let repository = TestShowRepository()
        repository.error = RepositoryError.notFound

        let viewModel = ShowListViewModel(
            repository: repository
        )

        await viewModel.loadShows()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.shows.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test
    @MainActor
    func createShowSuccessfullyCreatesShow() async {
        let repository = TestShowRepository()

        let viewModel = ShowListViewModel(
            repository: repository
        )

        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        let success = await viewModel.createShow(show)

        #expect(success == true)
        #expect(repository.shows == [show])
        #expect(viewModel.shows == [show])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func createShowFailsWithError() async {
        let repository = TestShowRepository()
        repository.createError = RepositoryError.duplicate

        let viewModel = ShowListViewModel(
            repository: repository
        )

        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        let success = await viewModel.createShow(show)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.shows.isEmpty)
    }

    @Test
    @MainActor
    func updateShowSuccessfullyUpdatesShow() async {
        let repository = TestShowRepository()

        let originalShow = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        repository.shows = [originalShow]

        let viewModel = ShowListViewModel(
            repository: repository
        )

        let updatedShow = Show(
            id: originalShow.id,
            tourID: originalShow.tourID,
            name: "Updated London Show",
            venue: "Wembley Arena",
            city: "London",
            date: originalShow.date,
            createdAt: originalShow.createdAt,
            version: originalShow.version
        )

        let success = await viewModel.updateShow(updatedShow)

        #expect(success == true)
        #expect(repository.shows == [updatedShow])
        #expect(viewModel.shows == [updatedShow])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func updateShowFailsWithError() async {
        let repository = TestShowRepository()

        let originalShow = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        repository.shows = [originalShow]
        repository.updateError = RepositoryError.notFound

        let viewModel = ShowListViewModel(
            repository: repository
        )

        let updatedShow = Show(
            id: originalShow.id,
            tourID: originalShow.tourID,
            name: "Updated London Show",
            venue: "Wembley Arena",
            city: "London",
            date: originalShow.date,
            createdAt: originalShow.createdAt,
            version: originalShow.version
        )

        let success = await viewModel.updateShow(updatedShow)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.shows == [originalShow])
    }

    @Test
    @MainActor
    func deleteShowSuccessfullyDeletesShow() async {
        let repository = TestShowRepository()

        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        repository.shows = [show]

        let viewModel = ShowListViewModel(
            repository: repository
        )

        let success = await viewModel.deleteShow(show)

        #expect(success == true)
        #expect(repository.shows.isEmpty)
        #expect(viewModel.shows.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func deleteShowFailsWithError() async {
        let repository = TestShowRepository()

        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        repository.shows = [show]
        repository.deleteError = RepositoryError.notFound

        let viewModel = ShowListViewModel(
            repository: repository
        )

        let success = await viewModel.deleteShow(show)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.shows == [show])
    }
}

@MainActor
private final class TestShowRepository: ShowRepositoryProtocol {

    var shows: [Show] = []

    var error: Error?
    var createError: Error?
    var updateError: Error?
    var deleteError: Error?

    func fetchShows() async throws -> [Show] {
        if let error {
            throw error
        }

        return shows
    }

    func fetchShow(id: UUID) async throws -> Show {
        if let error {
            throw error
        }

        guard let show = shows.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        return show
    }

    func createShow(_ show: Show) async throws {
        if let createError {
            throw createError
        }

        shows.append(show)
    }

    func updateShow(_ show: Show) async throws {
        if let updateError {
            throw updateError
        }

        guard let index = shows.firstIndex(where: { $0.id == show.id }) else {
            throw RepositoryError.notFound
        }

        shows[index] = show
    }

    func deleteShow(id: UUID) async throws {
        if let deleteError {
            throw deleteError
        }

        guard let index = shows.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        shows.remove(at: index)
    }
}
