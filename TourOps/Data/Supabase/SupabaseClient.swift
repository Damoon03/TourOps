//
//  SupabaseClient.swift
//  TourOps
//
//  Created by Damoon saber on 30/6/1405 AP.
//

import Foundation
import Supabase

final class TourOpsSupabaseClient {

    static let shared = TourOpsSupabaseClient()

    let client: SupabaseClient
    let baseURL: URL
    let publishableKey: String
    
    private init() {
        guard
            let urlString = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_URL"
            ) as? String,
            let url = URL(string: urlString),
            let key = Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY"
            ) as? String
        else {
            fatalError("Supabase configuration is missing.")
        }

        self.baseURL = url
        self.publishableKey = key
        
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
}
