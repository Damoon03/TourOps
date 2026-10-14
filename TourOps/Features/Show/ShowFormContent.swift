//
//  ShowFormContent.swift
//  TourOps
//
//  The fields shared by Create Show and Edit Show. Each screen keeps its own
//  navigation, toolbar and submission logic.
//

import SwiftUI

struct ShowFormContent: View {

    @Binding var draft: ShowDraft

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(
                eyebrow: "LIVE PERFORMANCE",
                title: title,
                subtitle: subtitle
            )

            VStack(spacing: 18) {
                EditorField(
                    title: "Show Name",
                    prompt: "e.g. Live in London",
                    symbol: "music.mic",
                    isRequired: true,
                    text: $draft.name
                )

                EditorField(
                    title: "Venue",
                    prompt: "e.g. Roundhouse",
                    symbol: "building.2",
                    isRequired: true,
                    text: $draft.venue
                )

                EditorField(
                    title: "City",
                    prompt: "e.g. London",
                    symbol: "mappin.and.ellipse",
                    isRequired: true,
                    text: $draft.city
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            ShowDateTimeEditor(date: $draft.date)
        }
    }
}
