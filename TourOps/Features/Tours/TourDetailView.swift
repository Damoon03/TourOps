//
//  TourDetailView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct TourDetailView: View {

    let tourID: UUID
    let viewModel: TourListViewModel
    let showRepository: ShowRepositoryProtocol

    @Environment(\.dismiss) private var dismiss

    @State private var showingEditTour = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false

    private var tour: Tour? {
        viewModel.tours.first { $0.id == tourID }
    }

    var body: some View {
        Group {
            if let tour {
                ZStack {
                    Palette.canvas.ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            heroCard(for: tour)
                            scheduleCard(for: tour)
                            showsCard(for: tour)
                            deleteButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                ContentUnavailableView(
                    "Tour Not Found",
                    systemImage: "music.note.list",
                    description: Text(
                        "This tour is no longer available."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas.ignoresSafeArea())
            }
        }
        .navigationTitle(tour?.name ?? "Tour")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Palette.canvas,
            for: .navigationBar
        )
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditTour = true
                }
                .disabled(tour == nil)
            }
        }
        .sheet(isPresented: $showingEditTour) {
            if let tour {
                EditTourView(
                    viewModel: viewModel,
                    tour: tour
                )
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
            }
        }
        .confirmationDialog(
            "Delete Tour?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let tour else { return }

                Task {
                    let success = await viewModel.deleteTour(tour)

                    if success {
                        dismiss()
                    } else {
                        showingError = true
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(
            "Couldn’t Delete Tour",
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
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero

    private func heroCard(for tour: Tour) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.22))
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 62, height: 62)

                Spacer()

                TourStatusBadge(
                    status: TourTimelineStatus(tour: tour)
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("TOUR OVERVIEW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Palette.chipAccent)

                Text(tour.name)
                    .font(
                        .system(
                            size: 27,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tour schedule and live performances")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
    }

    // MARK: - Schedule

    private func scheduleCard(for tour: Tour) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Palette.secondaryText)
                .padding(.bottom, 8)

            scheduleRow(
                title: "Start date",
                date: tour.startDate,
                symbol: "calendar"
            )

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.7)

            scheduleRow(
                title: "End date",
                date: tour.endDate,
                symbol: "calendar.badge.clock"
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

    private func scheduleRow(
        title: String,
        date: Date,
        symbol: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.chipAccent)
                .frame(width: 23)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)

                Text(
                    date.formatted(
                        date: .long,
                        time: .omitted
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    // MARK: - Shows

    private func showsCard(for tour: Tour) -> some View {
        NavigationLink {
            ShowListView(
                repository: showRepository,
                tourID: tour.id
            )
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.20))
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Shows")
                        .font(.headline)
                        .foregroundStyle(Palette.primaryText)

                    Text("Manage individual live performances")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .buttonStyle(.plain)
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete Tour", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .fill(Color.red.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .strokeBorder(
                        Color.red.opacity(0.18),
                        lineWidth: 0.8
                    )
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Tour Detail Preview")
}
