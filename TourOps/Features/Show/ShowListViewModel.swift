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

    /// Set whenever the latest load failed, even if other shows are cached,
    /// and cleared at the start of every load. Mutation failures use
    /// `errorMessage` alone, so a failed save never looks like a failed load.
    ///
    /// The list shows this only when the selected tour has nothing cached
    /// (see `listPhase`); a tour with cached shows keeps displaying them.
    private(set) var loadErrorMessage: String?

    init(repository: ShowRepositoryProtocol) {
        self.repository = repository
    }

    func loadShows() async {
        let shouldShowLoading = shows.isEmpty

        isLoading = shouldShowLoading
        errorMessage = nil
        loadErrorMessage = nil

        do {
            shows = try await repository.fetchShows()
        } catch is CancellationError {
            // A superseded load (for example after a refresh signal) is not a
            // failure; the load that replaced it reports its own outcome.
        } catch {
            loadErrorMessage = error.localizedDescription

            // Existing behavior: the general error is only raised when there
            // is no cached data at all.
            if shows.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// What the Shows list for one tour should display. Filtering by tour
    /// happens before the empty check, so cached shows that belong to other
    /// tours can never turn a failed load into a misleading empty state.
    func listPhase(
        forTourID tourID: UUID,
        hasCompletedFirstLoad: Bool
    ) -> ListPhase<[Show]> {
        let tourShows = shows.filter { $0.tourID == tourID }

        return ListPhase.resolve(
            isLoading: isLoading,
            hasCompletedFirstLoad: hasCompletedFirstLoad,
            isEmpty: tourShows.isEmpty,
            loadError: loadErrorMessage,
            populated: { tourShows }
        )
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
