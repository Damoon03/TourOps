//
//  TourListViewModel.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation
import Observation

@MainActor
@Observable
final class TourListViewModel {

    private let repository: TourRepositoryProtocol

    var tours: [Tour] = []
    var isLoading = false
    private(set) var errorMessage: String?

    /// Set when a load fails. Mutation failures use `errorMessage` alone, so a
    /// failed save never looks like a failed load.
    private(set) var loadErrorMessage: String?

    init(repository: TourRepositoryProtocol) {
        self.repository = repository
    }

    func loadTours() async {
        isLoading = tours.isEmpty
        errorMessage = nil
        loadErrorMessage = nil

        do {
            tours = try await repository.fetchTours()
        } catch is CancellationError {
            // A superseded load is not a failure.
        } catch {
            errorMessage = error.localizedDescription
            loadErrorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createTour(_ tour: Tour) async -> Bool {
        do {
            try await repository.createTour(tour)
            await loadTours()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateTour(_ tour: Tour) async -> Bool {
        do {
            try await repository.updateTour(tour)
            await loadTours()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteTour(_ tour: Tour) async -> Bool {
        do {
            try await repository.deleteTour(id: tour.id)
            await loadTours()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
