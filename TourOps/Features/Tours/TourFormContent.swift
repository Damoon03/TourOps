//
//  TourFormContent.swift
//  TourOps
//
//  The fields shared by Create Tour and Edit Tour.
//

import SwiftUI

struct TourFormContent: View {

    @Binding var draft: TourDraft

    /// When present, the form lets the user pick which team the tour belongs
    /// to. Create Tour opened from a team passes none, because the team is
    /// already fixed.
    var teamChoices: [PickerOption] = []
    var teamSelection: Binding<UUID>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let teamSelection, !teamChoices.isEmpty {
                PickerField(
                    title: "Team",
                    options: teamChoices,
                    selection: teamSelection
                )
            }

            EditorField(
                title: "Tour name",
                prompt: "e.g. World Tour 2027",
                isRequired: true,
                text: $draft.name
            )

            TourDateRangeEditor(
                startDate: Binding(
                    get: { draft.startDate },
                    set: { draft.setStartDate($0) }
                ),
                endDate: $draft.endDate
            )
        }
    }
}
