//
//  TeamDetailView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation
import SwiftUI
import UIKit

struct TeamDetailView: View {

    let teamID: UUID
    let viewModel: TeamListViewModel
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false

    private var team: Team? {
        viewModel.teams.first { $0.id == teamID }
    }

    var body: some View {
        Group {
            if let team {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard(for: team)
                        detailsCard(for: team)
                        toursCard(for: team)
                        deleteButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .background(Palette.canvas.ignoresSafeArea())
            } else {
                ContentUnavailableView(
                    "Team Not Found",
                    systemImage: "music.mic",
                    description: Text(
                        "This team is no longer available."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas.ignoresSafeArea())
            }
        }
        .navigationTitle(team?.name ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(team == nil)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let team {
                NavigationStack {
                    EditTeamView(
                        team: team,
                        viewModel: viewModel
                    )
                }
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
            }
        }
        .confirmationDialog(
            "Delete Team?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let team else { return }

                Task {
                    let success = await viewModel.deleteTeam(team)

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
            "Error",
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

    private func heroCard(for team: Team) -> some View {
        HStack(alignment: .top, spacing: 16) {
            artwork(for: team)

            VStack(alignment: .leading, spacing: 11) {
                Text(team.name)
                    .font(
                        .system(
                            size: 25,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !team.genre
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    TeamDetailPill(
                        title: team.genre,
                        color: GenreColorMapper.color(
                            for: team.genre
                        )
                    )
                }

                if !team.country
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    TeamDetailPill(
                        title: team.country,
                        color: ContinentColorMapper.color(
                            for: team.country
                        )
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
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

    @ViewBuilder
    private func artwork(for team: Team) -> some View {
        if let imageData = team.imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
                .accessibilityLabel(
                    "Artist image for \(team.name)"
                )
        } else {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(Palette.surfaceRaised)
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(width: 104, height: 104)
            .accessibilityLabel("No artist image")
        }
    }

    // MARK: - Team details

    private func detailsCard(for team: Team) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeading("TEAM DETAILS")

            detailRow(
                title: "Location",
                value: locationSummary(for: team),
                symbol: "mappin.and.ellipse"
            )

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.7)

            detailRow(
                title: "Added",
                value: team.createdAt.formatted(
                    date: .abbreviated,
                    time: .omitted
                ),
                symbol: "calendar"
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 8)
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

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Palette.secondaryText)
            .padding(.bottom, 7)
    }

    private func detailRow(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.chipAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)

                Text(value.isEmpty ? "Not set" : value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func locationSummary(for team: Team) -> String {
        let city = team.city.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let country = team.country.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch (city.isEmpty, country.isEmpty) {
        case (false, false):
            return "\(city) · \(country)"
        case (false, true):
            return city
        case (true, false):
            return country
        case (true, true):
            return "Location not set"
        }
    }

    // MARK: - Tours

    private func toursCard(for team: Team) -> some View {
        NavigationLink {
            TourListView(
                repository: tourRepository,
                teamID: team.id,
                showRepository: showRepository
            )
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.20))
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(
                            .system(size: 21, weight: .semibold)
                        )
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Tours & Shows")
                        .font(.headline)
                        .foregroundStyle(Palette.primaryText)

                    Text("Manage tours and scheduled performances")
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
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 23,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label(
                "Delete Team",
                systemImage: "trash"
            )
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

// MARK: - Metadata pill

private struct TeamDetailPill: View {

    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay {
                Capsule()
                    .strokeBorder(
                        color.opacity(0.9),
                        lineWidth: 0.8
                    )
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    Text("Team Detail Preview")
}
