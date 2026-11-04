//
//  SyncIssue.swift
//  TourOps
//
//  One entity whose queued work needs the user: at least one of its
//  operations is in conflict or has failed.
//

import Foundation

struct SyncIssue: Identifiable, Equatable {

    enum Kind: Equatable {
        case conflict
        case failed
    }

    let entityID: UUID
    let entityType: SyncEntityType

    /// The operation types of the entity's conflict and failed operations.
    let operationTypes: Set<SyncOperationType>

    /// `.conflict` when any blocking operation is a conflict, otherwise
    /// `.failed`.
    let kind: Kind

    /// Creation date of the oldest blocking operation, for stable ordering.
    let createdAt: Date

    var id: UUID { entityID }

    /// Groups the conflict and failed operations by entity. Operations that
    /// are pending or processing are not issues and are ignored.
    static func issues(from operations: [SyncOperation]) -> [SyncIssue] {
        let blocking = operations.filter {
            $0.status == .conflict || $0.status == .failed
        }

        let grouped = Dictionary(grouping: blocking, by: \.entityID)

        let issues = grouped.compactMap { entityID, group -> SyncIssue? in
            guard let first = group.first else {
                return nil
            }

            return SyncIssue(
                entityID: entityID,
                entityType: first.entityType,
                operationTypes: Set(group.map(\.operationType)),
                kind: group.contains { $0.status == .conflict }
                    ? .conflict
                    : .failed,
                createdAt: group.map(\.createdAt).min() ?? first.createdAt
            )
        }

        return issues.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }

            return $0.entityID.uuidString < $1.entityID.uuidString
        }
    }
}
