//
//  SyncStatusPill.swift
//  TourOps
//
//  A compact pill that appears only while local changes are still waiting in
//  the sync queue. It is hidden once everything is synced, so there is no
//  permanent "Synced" badge.
//
//  This is a read-only view of the existing queue (`SyncOperationEntity`).
//  It deliberately does not call `SyncOperationRepository.fetchPendingOperations()`,
//  which also resets operations left in `.processing` and saves the context;
//  a UI element must not change sync state.
//
//  The sync layer has no notion of being offline (no reachability
//  monitoring), so no offline state is shown here.
//

import SwiftUI
import SwiftData

struct SyncStatusPill: View {

    @Query private var operations: [SyncOperationEntity]

    var body: some View {
        let count = operations.count

        if count > 0 {
            HStack(spacing: 7) {
                Circle()
                    .fill(Palette.orange)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)

                Text(count == 1 ? "1 change not synced" : "\(count) changes not synced")
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
            .accessibilityLabel(
                count == 1
                    ? "1 change waiting to sync"
                    : "\(count) changes waiting to sync"
            )
        }
    }
}
