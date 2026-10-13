//
//  SubmissionGate.swift
//  TourOps
//
//  Serializes a form's mutation so that a rapid double tap cannot start two
//  overlapping operations. The repositories are not guaranteed to be atomic
//  across tasks, so the guard lives at the point where the user triggers it.
//

import Foundation
import Observation

@MainActor
@Observable
final class SubmissionGate {

    private(set) var isRunning = false

    /// Runs `operation` unless another one is already in progress.
    ///
    /// - Returns: The operation's result, or `nil` if the call was rejected
    ///   because a submission was already running. The gate is released
    ///   whether the operation succeeds or fails, so a failed submission can
    ///   be retried.
    func run(_ operation: () async -> Bool) async -> Bool? {
        guard !isRunning else {
            return nil
        }

        isRunning = true
        defer { isRunning = false }

        return await operation()
    }
}
