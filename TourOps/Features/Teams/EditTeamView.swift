//
//  EditTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct EditTeamView: View {

    let team: Team
    let viewModel: TeamListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var genre: String
    @State private var country: String
    @State private var city: String
    @State private var imageData: Data?
    @State private var showingError = false

    private var hasValidName: Bool {
        !name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    init(
        team: Team,
        viewModel: TeamListViewModel
    ) {
        self.team = team
        self.viewModel = viewModel

        _name = State(initialValue: team.name)
        _genre = State(initialValue: team.genre)
        _country = State(initialValue: team.country)
        _city = State(initialValue: team.city)
        _imageData = State(initialValue: team.imageData)
    }

    var body: some View {
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
        .navigationTitle("Edit Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveTeam)
                    .fontWeight(.semibold)
                    .disabled(!hasValidName)
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .alert(
            "Couldn’t Update Team",
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

            Text("Edit artist details")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text(
                "Keep the artist profile and its visual identity up to date."
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

    private func saveTeam() {
        let updatedTeam = Team(
            id: team.id,
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
            createdAt: team.createdAt,
            version: team.version,
            imageData: imageData
        )

        Task {
            let success = await viewModel.updateTeam(updatedTeam)

            if success {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    Text("Edit Team Preview")
}
