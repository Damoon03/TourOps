//
//  ListPhase.swift
//  TourOps
//

import Foundation

/// What a list screen is showing. Loading failures are kept distinct from
/// empty data and from mutation failures (which are reported by alerts).
enum ListPhase<Value> {
    case loading
    case failed(String)
    case empty
    case populated(Value)

    /// - Parameters:
    ///   - isLoading: The view model's loading flag.
    ///   - hasCompletedFirstLoad: Prevents a flash of the empty state before
    ///     the first load has finished.
    ///   - isEmpty: Whether there is nothing to show for this screen.
    ///   - loadError: The message of a failed *load* (not a failed mutation).
    ///   - populated: Builds the payload when there is something to show.
    static func resolve(
        isLoading: Bool,
        hasCompletedFirstLoad: Bool,
        isEmpty: Bool,
        loadError: String?,
        populated: () -> Value
    ) -> ListPhase<Value> {
        if isLoading || !hasCompletedFirstLoad {
            return .loading
        }

        if isEmpty {
            if let loadError {
                return .failed(loadError)
            }

            return .empty
        }

        return .populated(populated())
    }
}
