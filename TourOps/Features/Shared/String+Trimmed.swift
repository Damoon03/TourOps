//
//  String+Trimmed.swift
//  TourOps
//

import Foundation

extension String {

    /// The string without leading or trailing whitespace and newlines.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
