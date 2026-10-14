//
//  ShowDraft.swift
//  TourOps
//

import Foundation

/// The editable state of the Create and Edit Show forms. Validation and
/// trimming live here so both forms, and the submission action itself,
/// enforce the same rules.
struct ShowDraft: Equatable {

    var name = ""
    var venue = ""
    var city = ""
    var date = Date()

    init() {}

    init(show: Show) {
        name = show.name
        venue = show.venue
        city = show.city
        date = show.date
    }

    /// Name, venue and city are required.
    var isValid: Bool {
        !name.trimmed.isEmpty
            && !venue.trimmed.isEmpty
            && !city.trimmed.isEmpty
    }

    /// Builds the show to create, or `nil` if the draft is invalid.
    func newShow(
        id: UUID,
        tourID: UUID,
        createdAt: Date = Date()
    ) -> Show? {
        guard isValid else {
            return nil
        }

        return Show(
            id: id,
            tourID: tourID,
            name: name.trimmed,
            venue: venue.trimmed,
            city: city.trimmed,
            date: date,
            createdAt: createdAt,
            version: 1
        )
    }

    /// Builds the updated show, or `nil` if the draft is invalid. The version
    /// is carried over so the repository's stale-version check still applies.
    func updatedShow(from original: Show) -> Show? {
        guard isValid else {
            return nil
        }

        return Show(
            id: original.id,
            tourID: original.tourID,
            name: name.trimmed,
            venue: venue.trimmed,
            city: city.trimmed,
            date: date,
            createdAt: original.createdAt,
            version: original.version
        )
    }
}
