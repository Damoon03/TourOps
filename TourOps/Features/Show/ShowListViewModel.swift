//
//  ShowListViewModel.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShowListViewModel {

private let repository: ShowRepositoryProtocol

var shows: [Show] = []
var isLoading = false

private(set) var errorMessage: String?

init(repository: ShowRepositoryProtocol) {
    self.repository = repository
}

func loadShows() async {
    isLoading = true
    errorMessage = nil

    do {
        shows = try await repository.fetchShows()
    } catch {
        errorMessage = error.localizedDescription
    }

    isLoading = false
}

func createShow(_ show: Show) async -> Bool {
    do {
        try await repository.createShow(show)
        await loadShows()
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}

func updateShow(_ show: Show) async -> Bool {
    do {
        try await repository.updateShow(show)
        await loadShows()
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}

func deleteShow(_ show: Show) async -> Bool {
    do {
        try await repository.deleteShow(id: show.id)
        await loadShows()
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
