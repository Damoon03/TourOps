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

    init(repository: TourRepositoryProtocol) {
        self.repository = repository
    }

    func loadTours() async {
        isLoading = true
        errorMessage = nil

        do {
            tours = try await repository.fetchTours()
        } catch {
            errorMessage = error.localizedDescription
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
