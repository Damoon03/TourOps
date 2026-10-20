//
//  SyncStatusPill.swift
//  TourOps
//
//  A compact pill that shows the sync state: offline (with or without queued
//  changes), the number of changes still waiting to sync, or a brief "Synced"
//  confirmation after a push completes. It is hidden otherwise.
//
//  The unsynced count is a read-only view of the existing queue
//  (`SyncOperationEntity`). It deliberately does not call
//  `SyncOperationRepository.fetchPendingOperations()`, which also resets
//  operations left in `.processing` and saves the context; a UI element must
//  not change sync state. Connection state and the transient success state
//  come from `SyncStatusModel`.
//

import SwiftUI
import SwiftData

struct SyncStatusPill: View {

    @Environment(SyncStatusModel.self) private var status
    @Query private var operations: [SyncOperationEntity]

    var body: some View {
        let presentation = status.presentation(
            unsyncedCount: operations.count
        )

        if presentation != .hidden {
            HStack(spacing: 7) {
                Circle()
                    .fill(dotColor(for: presentation))
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)

                Text(title(for: presentation))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Palette.hairline, lineWidth: 0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: presentation))
        }
    }

    private func dotColor(for presentation: SyncStatusPresentation) -> Color {
        switch presentation {
        case .synced:
            return Palette.statusActive
        case .offline:
            return Palette.secondaryText
        case .unsynced, .hidden:
            return Palette.orange
        }
    }

    private func title(for presentation: SyncStatusPresentation) -> String {
        switch presentation {
        case .hidden:
            return ""
        case .synced:
            return "Synced ✓"
        case .offline(let count):
            return count > 0
                ? "Offline · \(Self.unsyncedText(count))"
                : "Offline"
        case .unsynced(let count):
            return Self.unsyncedText(count)
        }
    }

    private func accessibilityLabel(
        for presentation: SyncStatusPresentation
    ) -> String {
        switch presentation {
        case .hidden:
            return ""
        case .synced:
            return "Changes synced"
        case .offline(let count):
            return count > 0
                ? "Offline. \(Self.waitingText(count))"
                : "Offline"
        case .unsynced(let count):
            return Self.waitingText(count)
        }
    }

    private static func unsyncedText(_ count: Int) -> String {
        count == 1 ? "1 change not synced" : "\(count) changes not synced"
    }

    private static func waitingText(_ count: Int) -> String {
        count == 1
            ? "1 change waiting to sync"
            : "\(count) changes waiting to sync"
    }
}
