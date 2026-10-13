//
//  TourFormContent.swift
//  TourOps
//
//  The fields shared by Create Tour and Edit Tour.
//

import SwiftUI

struct TourFormContent: View {

    @Binding var draft: TourDraft

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(
                eyebrow: "TOUR PLANNING",
                title: title,
                subtitle: subtitle
            )

            VStack(spacing: 18) {
                EditorField(
                    title: "Tour Name",
                    prompt: "e.g. World Tour 2027",
                    symbol: "music.note.list",
                    isRequired: true,
                    text: $draft.name
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

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
