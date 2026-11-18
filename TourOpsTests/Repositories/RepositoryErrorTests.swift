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

        #expect(message.contains("tap the sync status"))
        #expect(message.contains("resolve or retry it"))
    }

    @Test
    func unresolvedSyncIssueIsDistinctFromOtherErrors() {
        #expect(RepositoryError.unresolvedSyncIssue != .staleVersion)
        #expect(RepositoryError.unresolvedSyncIssue != .notFound)
        #expect(RepositoryError.unresolvedSyncIssue != .duplicate)
    }
}
