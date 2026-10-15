//
//  ShowFormContent.swift
//  TourOps
//
//  The fields shared by Create Show and Edit Show. Each screen keeps its own
//  sheet, submission logic and validation (see ShowDraft).
//

import SwiftUI

struct ShowFormContent: View {

    @Binding var draft: ShowDraft

    /// When present, the form lets the user pick which tour the show belongs
    /// to. Create Show opened from a tour passes none, because the tour is
    /// already fixed.
    var tourChoices: [PickerOption] = []
    var tourSelection: Binding<UUID>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let tourSelection, !tourChoices.isEmpty {
                PickerField(
                    title: "Tour",
                    options: tourChoices,
                    selection: tourSelection
                )
            }

            EditorField(
                title: "Show name",
                prompt: "e.g. Live in London",
                isRequired: true,
                text: $draft.name
            )

            EditorField(
                title: "Venue",
                prompt: "e.g. Roundhouse",
                isRequired: true,
                text: $draft.venue
            )

            EditorField(
                title: "City",
                prompt: "e.g. London",
                isRequired: true,
                text: $draft.city
            )

            HStack(alignment: .top, spacing: 12) {
                DateField(
                    title: "Date",
                    date: $draft.date,
                    components: .date
                )

                DateField(
                    title: "Time",
                    date: $draft.date,
                    components: .hourAndMinute
                )
            }
        }
    }
}
