//
//  Show+Presentation.swift
//  TourOps
//

import Foundation

extension Show {

    /// "Venue · City", whichever parts are present, or `nil` if neither is.
    var locationSummary: String? {
        let venueText = self.venue.trimmed
        let cityText = self.city.trimmed

        switch (venueText.isEmpty, cityText.isEmpty) {
        case (false, false):
            return "\(venueText) · \(cityText)"
        case (false, true):
            return venueText
        case (true, false):
            return cityText
        case (true, true):
            return nil
        }
    }

    /// The same location, phrased for VoiceOver.
    var spokenLocation: String? {
        let venueText = self.venue.trimmed
        let cityText = self.city.trimmed

        switch (venueText.isEmpty, cityText.isEmpty) {
        case (false, false):
            return "\(venueText), \(cityText)"
        case (false, true):
            return venueText
        case (true, false):
            return cityText
        case (true, true):
            return nil
        }
    }
}
