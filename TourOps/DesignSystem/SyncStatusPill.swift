//
//  SyncStatusPill.swift
//  TourOps
//
//  A compact pill that shows the sync state: changes that need attention
//  (conflict or failed), offline (with or without queued changes), the number
//  of changes still waiting to sync, or a brief "Synced" confirmation after a
//  push completes. It is hidden otherwise.
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

    /// Called when the pill is tapped while items need attention. In every
    /// other state the pill is a plain label.
    private let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        let attentionOperations = operations.filter {
            $0.status == SyncOperationStatus.conflict.rawValue
                || $0.status == SyncOperationStatus.failed.rawValue
        }

        // Counted per item, because the sheet lists one row per item.
        let needsAttentionCount = Set(attentionOperations.map(\.entityID)).count

        let presentation = status.presentation(
            unsyncedCount: operations.count - attentionOperations.count,
            needsAttentionCount: needsAttentionCount
        )

        if presentation != .hidden {
            if case .needsAttention(let count) = presentation, let onTap {
                Button(action: onTap) {
                    label(for: presentation)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.attentionText(count))
                .accessibilityHint("Opens the list of items to resolve")
                .accessibilityAddTraits(.isButton)
            } else {
                label(for: presentation)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: presentation))
            }
        }
    }

    private func label(for presentation: SyncStatusPresentation) -> some View {
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
    }

    private func dotColor(for presentation: SyncStatusPresentation) -> Color {
        switch presentation {
        case .synced:
            return Palette.statusActive
        case .offline:
            return Palette.secondaryText
        case .needsAttention:
            return Palette.destructive
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
        case .needsAttention(let count):
            return Self.attentionText(count)
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
        case .needsAttention(let count):
            return Self.attentionText(count)
        }
    }

    private static func unsyncedText(_ count: Int) -> String {
        count == 1 ? "1 change not synced" : "\(count) changes not synced"
    }

    private static func attentionText(_ count: Int) -> String {
        count == 1
            ? "1 item needs attention"
            : "\(count) items need attention"
    }

    private static func waitingText(_ count: Int) -> String {
        count == 1
            ? "1 change waiting to sync"
            : "\(count) changes waiting to sync"
    }
}
