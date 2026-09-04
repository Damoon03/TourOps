//
//  RepositoryError.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation

enum RepositoryError: Error {
    case notFound
    case duplicate
    case staleVersion
}
