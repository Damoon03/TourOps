//
//  SubmissionGateTests.swift
//  TourOpsTests
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

        let first = Task { @MainActor in
            await gate.run({
                executions += 1
                try? await Task.sleep(for: .milliseconds(100))
                return true
            })
        }

        // Let the first operation start.
        await Task.yield()
        #expect(gate.isRunning)

        let second = await gate.run({
            executions += 1
            return true
        })

        #expect(second == nil)
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
    }
}
