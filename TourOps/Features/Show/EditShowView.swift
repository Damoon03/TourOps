//
//  EditShowView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct EditShowView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: ShowListViewModel
    private let show: Show

    @State private var name: String
    @State private var venue: String
    @State private var city: String
    @State private var date: Date
    @State private var showingError = false

    private var hasValidDetails: Bool {
        !name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        && !venue.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        && !city.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    init(
        viewModel: ShowListViewModel,
        show: Show
    ) {
        self.viewModel = viewModel
        self.show = show

        _name = State(initialValue: show.name)
        _venue = State(initialValue: show.venue)
        _city = State(initialValue: show.city)
        _date = State(initialValue: show.date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro
                        informationCard

                        ShowDateTimeEditor(date: $date)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Edit Show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveShow)
                        .fontWeight(.semibold)
                        .disabled(!hasValidDetails)
                }
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .alert(
            "Couldn’t Update Show",
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
            Text("LIVE PERFORMANCE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.chipAccent)

            Text("Edit show details")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text("Update the venue or adjust the schedule.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var informationCard: some View {
        VStack(spacing: 18) {
            ShowEditorField(
                title: "Show Name",
                prompt: "e.g. Live in London",
                symbol: "music.mic",
                text: $name
            )

            ShowEditorField(
                title: "Venue",
                prompt: "e.g. Roundhouse",
                symbol: "building.2",
                text: $venue
            )

            ShowEditorField(
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

    private func saveShow() {
        let updatedShow = Show(
            id: show.id,
            tourID: show.tourID,
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            venue: venue.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            city: city.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            date: date,
            createdAt: show.createdAt,
            version: show.version
        )

        Task {
            let success = await viewModel.updateShow(updatedShow)

            if success {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    Text("Edit Show Preview")
}
