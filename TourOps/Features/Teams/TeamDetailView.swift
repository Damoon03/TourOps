//
//  TeamDetailView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI
import UIKit

struct TeamDetailView: View {

    let teamID: UUID
    let viewModel: TeamListViewModel
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(DataRefreshSignal.self) private var refreshSignal

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var gate = SubmissionGate()

    /// `nil` until tours and shows have been read, or if reading failed. The
    /// card and the delete message then say less rather than guess.
    @State private var summary: TeamSchedule.Summary?

    @ScaledMetric(relativeTo: .title) private var artworkSize: CGFloat = 104

    private var team: Team? {
        viewModel.teams.first { $0.id == teamID }
    }

    var body: some View {
        Group {
            if let team {
                ScreenScroll {
                    heroCard(for: team)
                    toursLink(for: team)
                    detailsCard(for: team)

                    DestructiveButton(
                        title: "Delete Team",
                        hint: "Asks for confirmation before deleting this team.",
                        isDisabled: gate.isRunning
                    ) {
                        showingDeleteConfirmation = true
                    }
                }
            } else {
                ContentUnavailableView(
                    "Team Not Found",
                    systemImage: "music.mic",
                    description: Text("This team is no longer available.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas.ignoresSafeArea())
            }
        }
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
                .disabled(team == nil || gate.isRunning)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let team {
                EditTeamView(
                    team: team,
                    viewModel: viewModel
                )
            }
        }
        .confirmationDialog(
            "Delete Team?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Team", role: .destructive) {
                delete()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                DeletionMessage.team(
                    tourCount: summary?.tourCount,
                    showCount: summary?.showCount
                )
            )
        }
        .alert(
            "Couldn’t Delete Team",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .task(id: refreshSignal.generation) {
            await loadSummary()
        }
    }

    private func loadSummary() async {
        do {
            async let fetchedTours = tourRepository.fetchTours()
            async let fetchedShows = showRepository.fetchShows()

            let (tours, shows) = try await (fetchedTours, fetchedShows)

            summary = TeamSchedule.summary(
                forTeamID: teamID,
                tours: tours,
                shows: shows
            )
        } catch {
            // Keep any earlier summary; the rest of the screen still works.
        }
    }

    private func delete() {
        guard !gate.isRunning, let team else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.deleteTeam(team)
            })

            switch result {
            case .some(true):
                dismiss()
            case .some(false):
                showingError = true
            case .none:
                break
            }
        }
    }

    // MARK: - Hero

    private func heroCard(for team: Team) -> some View {
        let genre = team.genre.trimmed
        let country = team.country.trimmed

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))

        return layout {
            artwork(for: team)

            VStack(alignment: .leading, spacing: 11) {
                Text(team.name)
                    .font(.heroTitle)
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if !genre.isEmpty {
                    StatusBadge(
                        title: genre,
                        color: GenreColorMapper.color(for: genre),
                        accessibilityPrefix: "Genre"
                    )
                }

                if !country.isEmpty {
                    StatusBadge(
                        title: country,
                        color: ContinentColorMapper.color(for: country),
                        accessibilityPrefix: "Country"
                    )
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.hero)
    }

    @ViewBuilder
    private func artwork(for team: Team) -> some View {
        if let imageData = team.imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: Radius.card,
                        style: .continuous
                    )
                )
                .accessibilityLabel("Artist image for \(team.name)")
        } else {
            RoundedRectangle(
                cornerRadius: Radius.card,
                style: .continuous
            )
            .fill(Palette.surfaceRaised)
            .overlay {
                Image(systemName: "music.mic")
                    .font(.title.weight(.medium))
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(width: artworkSize, height: artworkSize)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Tours

    private func toursLink(for team: Team) -> some View {
        NavigationLink {
            TourListView(
                repository: tourRepository,
                teamID: team.id,
                showRepository: showRepository
            )
        } label: {
            NavigationCardLabel(
                symbol: "music.note.list",
                title: "Tours",
                lines: tourLines
            )
        }
        .buttonStyle(CardPressStyle())
        .accessibilityHint("Opens the tours for this team")
    }

    private var tourLines: [String] {
        guard let summary else {
            return ["Manage tours and scheduled performances"]
        }

        guard summary.tourCount > 0 else {
            return ["No tours yet. Create the first one."]
        }

        var lines = [
            summary.tourCount == 1 ? "1 tour" : "\(summary.tourCount) tours"
        ]

        if let next = summary.nextShow {
            let date = next.date.formatted(date: .abbreviated, time: .omitted)
            lines.append("Next show: \(next.name.trimmed), \(date)")
        } else {
            lines.append("No upcoming shows")
        }

        return lines
    }

    // MARK: - Details

    private func detailsCard(for team: Team) -> some View {
        let city = team.city.trimmed

        return DetailCard(heading: "TEAM DETAILS") {
            DetailRow(
                title: "Home city",
                value: city.isEmpty ? "Not set" : city,
                symbol: "mappin.and.ellipse"
            )

            HairlineDivider()

            DetailRow(
                title: "Added",
                value: team.createdAt.formatted(date: .abbreviated, time: .omitted),
                symbol: "calendar"
            )
        }
    }
}

#if DEBUG
@MainActor
private func previewDetail(
    team: Team,
    tours: [Tour] = [],
    shows: [Show] = []
) -> some View {
    let viewModel = TeamListViewModel(
        repository: PreviewTeamRepository(teams: [team])
    )
    viewModel.teams = [team]

    return NavigationStack {
        TeamDetailView(
            teamID: team.id,
            viewModel: viewModel,
            tourRepository: PreviewTourRepository(tours: tours),
            showRepository: PreviewShowRepository(shows: shows)
        )
    }
    .environment(DataRefreshSignal())
    .preferredColorScheme(.dark)
}

#Preview("With image and shows") {
    previewDetail(
        team: PreviewData.teamWithImage,
        tours: [PreviewData.upcomingTour],
        shows: [PreviewData.upcomingShow, PreviewData.pastShow]
    )
}

#Preview("No image, no tours") {
    previewDetail(team: PreviewData.emptyTeam)
}

#Preview("Long text, large type") {
    previewDetail(team: PreviewData.longTeam)
        .dynamicTypeSize(.accessibility3)
}
#endif
