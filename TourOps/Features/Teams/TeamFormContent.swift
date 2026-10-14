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

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(
                eyebrow: "ARTIST WORKSPACE",
                title: title,
                subtitle: subtitle
            )

            VStack(spacing: 18) {
                EditorField(
                    title: "Artist / Band Name",
                    prompt: "e.g. Silver Echo",
                    symbol: "music.mic",
                    isRequired: true,
                    text: $draft.name
                )

                EditorField(
                    title: "Genre",
                    prompt: "e.g. Indie Rock",
                    symbol: "waveform",
                    text: $draft.genre
                )

                EditorField(
                    title: "Country",
                    prompt: "e.g. United Kingdom",
                    symbol: "globe",
                    text: $draft.country
                )

                EditorField(
                    title: "City",
                    prompt: "e.g. London",
                    symbol: "mappin.and.ellipse",
                    text: $draft.city
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            TeamImagePicker(
                imageData: $draft.imageData,
                isBusy: $isImageBusy
            )
        }
    }
}
