//
//  Endpoint.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

protocol Endpoint {

    var path: String { get }
    var method: HTTPMethod { get }
}


enum HTTPMethod: String {

    case GET
    case POST
    case PUT
    case DELETE
}
