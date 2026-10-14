//
//  SubmissionGateTests.swift
//  TourOpsTests
//
//  No sleeps or yields: the test waits on explicit signals, so the second
//  submission is attempted only once the first is definitely running.
//

import Foundation
import Testing
@testable import TourOps

struct SubmissionGateTests {

    @Test
    @MainActor
    func secondSubmissionWhileRunningIsRejected() async {
        let gate = SubmissionGate()
        var executions = 0

        let (started, signalStarted) = AsyncStream<Void>.makeStream()
        let (release, signalRelease) = AsyncStream<Void>.makeStream()

        let first = Task { @MainActor in
            await gate.run({
                executions += 1
                signalStarted.yield()

                // Suspend until the test explicitly releases the operation.
                for await _ in release { break }

                return true
            })
        }

        // Block until the first operation is inside the gate.
        for await _ in started { break }
        #expect(gate.isRunning)

        let second = await gate.run({
            executions += 1
            return true
        })

        #expect(second == nil)
        #expect(executions == 1)
        #expect(gate.isRunning, "the rejected call must not release the first submission")

        signalRelease.yield()

        #expect(await first.value == true)
        #expect(executions == 1)
        #expect(!gate.isRunning)
    }

    @Test
    @MainActor
    func gateReleasesAfterFailureSoItCanRetry() async {
        let gate = SubmissionGate()

        #expect(await gate.run({ false }) == false)
        #expect(!gate.isRunning)
        #expect(await gate.run({ true }) == true)
        #expect(!gate.isRunning)
    }
}
