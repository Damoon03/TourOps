//
//  TeamEditorField.swift
//  TourOps
//
//  Created by Damoon saber on 7/21/1405 AP.
//

import Foundation
import SwiftUI

struct TeamEditorField: View {

    let title: String
    let prompt: String
    let symbol: String

    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Palette.secondaryText)

            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.chipAccent)
                    .frame(width: 22)

                TextField(prompt, text: $text)
                    .font(.body)
                    .foregroundStyle(Palette.primaryText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(
                Palette.canvas.opacity(0.72),
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .strokeBorder(
                    Palette.hairline,
                    lineWidth: 0.7
                )
            }
        }
    }
}

#Preview {
    ZStack {
        Palette.canvas.ignoresSafeArea()

        TeamEditorField(
            title: "Artist / Band Name",
            prompt: "e.g. Silver Echo",
            symbol: "music.mic",
            text: .constant("")
        )
        .padding(20)
    }
    .preferredColorScheme(.dark)
}
