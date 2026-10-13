//
//  CreateShowView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct CreateShowView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: ShowListViewModel
    let tourID: UUID

    @State private var name = ""
    @State private var venue = ""
    @State private var city = ""
    @State private var date = Date()
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
            .navigationTitle("New Show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createShow)
                        .fontWeight(.semibold)
                        .disabled(!hasValidDetails)
                }
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .alert(
            "Couldn’t Create Show",
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

            Text("Add a show")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text("Add a venue, city, and schedule for this tour.")
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

    private func createShow() {
        let show = Show(
            id: UUID(),
            tourID: tourID,
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
            createdAt: Date(),
            version: 1
        )

        Task {
            let success = await viewModel.createShow(show)

            if success {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    Text("Create Show Preview")
}
