//
//  CreateTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/3/1405 AP.
//

import SwiftUI

struct CreateTeamView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: TeamListViewModel

    @State private var name = ""
    @State private var genre = ""
    @State private var country = ""
    @State private var city = ""
    @State private var imageData: Data?
    @State private var showingError = false

    private var hasValidName: Bool {
        !name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro

                        fieldsCard

                        TeamImagePicker(imageData: $imageData)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createTeam)
                        .fontWeight(.semibold)
                        .disabled(!hasValidName)
                }
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .alert(
            "Couldn’t Create Team",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(
                viewModel.errorMessage
                ?? "Something went wrong."
            )
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ARTIST WORKSPACE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.chipAccent)

            Text("Add an artist or band")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text(
                "Set up the identity you'll use to organize tours and shows."
            )
            .font(.subheadline)
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldsCard: some View {
        VStack(spacing: 18) {
            TeamEditorField(
                title: "Artist / Band Name",
                prompt: "e.g. Silver Echo",
                symbol: "music.mic",
                text: $name
            )

            TeamEditorField(
                title: "Genre",
                prompt: "e.g. Indie Rock",
                symbol: "waveform",
                text: $genre
            )

            TeamEditorField(
                title: "Country",
                prompt: "e.g. United Kingdom",
                symbol: "globe",
                text: $country
            )

            TeamEditorField(
                title: "City",
                prompt: "e.g. London",
                symbol: "mappin.and.ellipse",
                text: $city
            )
        }
        .padding(18)
        .background {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
    }

    private func createTeam() {
        let team = Team(
            id: UUID(),
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            genre: genre.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            country: country.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            city: city.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            createdAt: Date(),
            version: 1,
            imageData: imageData
        )

        Task {
            let success = await viewModel.createTeam(team)

            if success {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    Text("Create Team Preview")
}
