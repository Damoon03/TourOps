//
//  TeamDraft.swift
//  TourOps
//

import Foundation

/// The editable state of the Create and Edit Team forms. Only the name is
/// required; genre, country, city and image are optional.
struct TeamDraft: Equatable {

    var name = ""
    var genre = ""
    var country = ""
    var city = ""
    var imageData: Data?

    init() {}

    init(team: Team) {
        name = team.name
        genre = team.genre
        country = team.country
        city = team.city
        imageData = team.imageData
    }

    var isValid: Bool {
        !name.trimmed.isEmpty
    }

    /// Builds the team to create, or `nil` if the draft is invalid.
    func newTeam(
        id: UUID,
        createdAt: Date = Date()
    ) -> Team? {
        guard isValid else {
            return nil
        }

        return Team(
            id: id,
            name: name.trimmed,
            genre: genre.trimmed,
            country: country.trimmed,
            city: city.trimmed,
            createdAt: createdAt,
            version: 1,
            imageData: imageData
        )
    }

    /// Builds the updated team, or `nil` if the draft is invalid.
    func updatedTeam(from original: Team) -> Team? {
        guard isValid else {
            return nil
        }

        return Team(
            id: original.id,
            name: name.trimmed,
            genre: genre.trimmed,
            country: country.trimmed,
            city: city.trimmed,
            createdAt: original.createdAt,
            version: original.version,
            imageData: imageData
        )
    }
}
