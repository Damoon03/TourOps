//
//  CreateTourView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct CreateTourView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: TourListViewModel
    let teamID: UUID

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showingError = false

    private var hasValidName: Bool {
        !name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }

    private var hasValidDateRange: Bool {
        Calendar.current.startOfDay(for: endDate)
            >= Calendar.current.startOfDay(for: startDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro
                        nameCard

                        TourDateRangeEditor(
                            startDate: $startDate,
                            endDate: $endDate
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createTour)
                        .fontWeight(.semibold)
                        .disabled(!hasValidName || !hasValidDateRange)
                }
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
        .alert(
            "Couldn’t Create Tour",
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
            Text("TOUR PLANNING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.chipAccent)

            Text("Create a tour")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text("Set a name and define the tour schedule.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("TOUR NAME")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Palette.secondaryText)

            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.chipAccent)
                    .frame(width: 22)

                TextField("e.g. World Tour 2026", text: $name)
                    .foregroundStyle(Palette.primaryText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(Palette.canvas.opacity(0.72))
            }
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

    private func createTour() {
        let tour = Tour(
            id: UUID(),
            teamID: teamID,
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            startDate: startDate,
            endDate: endDate,
            createdAt: Date(),
            version: 1
        )

        Task {
            let success = await viewModel.createTour(tour)

            if success {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    Text("Create Tour Preview")
}
