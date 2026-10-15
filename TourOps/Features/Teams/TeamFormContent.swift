//
//  TeamFormContent.swift
//  TourOps
//
//  The fields shared by Create Team and Edit Team.
//

import SwiftUI

struct TeamFormContent: View {

    @Binding var draft: TeamDraft
    @Binding var isImageBusy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            EditorField(
                title: "Artist / band name",
                prompt: "e.g. Silver Echo",
                isRequired: true,
                text: $draft.name
            )

            EditorField(
                title: "Genre",
                prompt: "e.g. Indie Rock",
                text: $draft.genre
            )

            EditorField(
                title: "Country",
                prompt: "e.g. United Kingdom",
                text: $draft.country
            )

            EditorField(
                title: "City",
                prompt: "e.g. London",
                text: $draft.city
            )

            TeamImagePicker(
                imageData: $draft.imageData,
                isBusy: $isImageBusy
            )
        }
    }
}
