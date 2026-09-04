//
//  TourListViewModelTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct TourListViewModelTests {

    @MainActor
    final class TestTourRepository: TourRepositoryProtocol {

        var tours: [Tour] = []

        var error: Error?
        var createError: Error?
        var updateError: Error?
        var deleteError: Error?

        func fetchTours() async throws -> [Tour] {
            if let error {
                throw error
            }

            return tours
        }

        func fetchTour(id: UUID) async throws -> Tour {
            if let error {
                throw error
            }

            guard let tour = tours.first(where: { $0.id == id }) else {
                throw RepositoryError.notFound
            }

            return tour
        }

        func createTour(_ tour: Tour) async throws {
            if let createError {
                throw createError
            }

            tours.append(tour)
        }

        func updateTour(_ tour: Tour) async throws {
            if let updateError {
                throw updateError
            }

            guard let index = tours.firstIndex(where: { $0.id == tour.id }) else {
                throw RepositoryError.notFound
            }

            tours[index] = tour
        }

        func deleteTour(id: UUID) async throws {
            if let deleteError {
                throw deleteError
            }

            guard let index = tours.firstIndex(where: { $0.id == id }) else {
                throw RepositoryError.notFound
            }

            tours.remove(at: index)
        }
    }

    @Test
    @MainActor
    func loadToursSuccessfullyUpdatesTours() async {
        let repository = TestTourRepository()

        let tour1 = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        let tour2 = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "Summer Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 14),
            createdAt: Date(),
            version: 1
        )

        repository.tours = [tour1, tour2]

        let viewModel = TourListViewModel(
            repository: repository
        )

        await viewModel.loadTours()

        #expect(viewModel.tours == [tour1, tour2])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func loadToursFailsWithError() async {
        let repository = TestTourRepository()
        repository.error = RepositoryError.notFound

        let viewModel = TourListViewModel(
            repository: repository
        )

        await viewModel.loadTours()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.tours.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test
    @MainActor
    func createTourSuccessfullyCreatesTour() async {
        let repository = TestTourRepository()

        let viewModel = TourListViewModel(
            repository: repository
        )

        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        let success = await viewModel.createTour(tour)

        #expect(success == true)
        #expect(repository.tours == [tour])
        #expect(viewModel.tours == [tour])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func createTourFailsWithError() async {
        let repository = TestTourRepository()
        repository.createError = RepositoryError.duplicate

        let viewModel = TourListViewModel(
            repository: repository
        )

        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        let success = await viewModel.createTour(tour)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.tours.isEmpty)
    }

    @Test
    @MainActor
    func updateTourSuccessfullyUpdatesTour() async {
        let repository = TestTourRepository()

        let originalTour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        repository.tours = [originalTour]

        let viewModel = TourListViewModel(
            repository: repository
        )

        let updatedTour = Tour(
            id: originalTour.id,
            teamID: originalTour.teamID,
            name: "Updated European Tour",
            startDate: originalTour.startDate,
            endDate: originalTour.endDate,
            createdAt: originalTour.createdAt,
            version: originalTour.version
        )

        let success = await viewModel.updateTour(updatedTour)

        #expect(success == true)
        #expect(repository.tours == [updatedTour])
        #expect(viewModel.tours == [updatedTour])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func updateTourFailsWithError() async {
        let repository = TestTourRepository()

        let originalTour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        repository.tours = [originalTour]
        repository.updateError = RepositoryError.notFound

        let viewModel = TourListViewModel(
            repository: repository
        )

        let updatedTour = Tour(
            id: originalTour.id,
            teamID: originalTour.teamID,
            name: "Updated European Tour",
            startDate: originalTour.startDate,
            endDate: originalTour.endDate,
            createdAt: originalTour.createdAt,
            version: originalTour.version
        )

        let success = await viewModel.updateTour(updatedTour)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.tours == [originalTour])
    }

    @Test
    @MainActor
    func deleteTourSuccessfullyDeletesTour() async {
        let repository = TestTourRepository()

        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        repository.tours = [tour]

        let viewModel = TourListViewModel(
            repository: repository
        )

        let success = await viewModel.deleteTour(tour)

        #expect(success == true)
        #expect(repository.tours.isEmpty)
        #expect(viewModel.tours.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func deleteTourFailsWithError() async {
        let repository = TestTourRepository()

        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        repository.tours = [tour]
        repository.deleteError = RepositoryError.notFound

        let viewModel = TourListViewModel(
            repository: repository
        )

        let success = await viewModel.deleteTour(tour)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.tours == [tour])
    }
}
