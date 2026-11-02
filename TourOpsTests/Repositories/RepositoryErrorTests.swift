//
//  RepositoryErrorTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

struct RepositoryErrorTests {

    @Test
    func unresolvedSyncIssueTellsTheUserWhatToDo() {
        let message = RepositoryError.unresolvedSyncIssue.localizedDescription

        #expect(message.contains("Resolve or retry it first"))
    }

    @Test
    func unresolvedSyncIssueIsDistinctFromOtherErrors() {
        #expect(RepositoryError.unresolvedSyncIssue != .staleVersion)
        #expect(RepositoryError.unresolvedSyncIssue != .notFound)
        #expect(RepositoryError.unresolvedSyncIssue != .duplicate)
    }
}
