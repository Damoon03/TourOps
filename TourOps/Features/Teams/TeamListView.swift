//
//  TeamListView.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI

#if DEBUG
import SwiftData
#endif

struct TeamListView: View {

    let repository: TeamRepositoryProtocol
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @Environment(DataRefreshSignal.self) private var refreshSignal
    @Environment(\.floatingNavInset) private var navInset

    @State private var viewModel: TeamListViewModel
    @State private var showingCreateTeam = false
    @State private var hasCompletedFirstLoad = false
    @State private var selectedCountry: String?
    @State private var overviewByTeamID: [UUID: TeamOverview.Info] = [:]

    init(
        repository: TeamRepositoryProtocol,
        tourRepository: TourRepositoryProtocol,
        showRepository: ShowRepositoryProtocol
    ) {
        self.repository = repository
        self.tourRepository = tourRepository
        self.showRepository = showRepository

        _viewModel = State(
            initialValue: TeamListViewModel(
                repository: repository
            )
        )
    }

    // MARK: - Screen phase

    private var phase: ListPhase<[Team]> {
        ListPhase.resolve(
            isLoading: viewModel.isLoading,
            hasCompletedFirstLoad: hasCompletedFirstLoad,
            isEmpty: viewModel.teams.isEmpty,
            loadError: viewModel.loadErrorMessage,
            populated: { Self.alphabetical(viewModel.teams) }
        )
    }

    private static func alphabetical(_ teams: [Team]) -> [Team] {
        teams.sorted { lhs, rhs in
            let result = lhs.name.localizedStandardCompare(rhs.name)

            if result == .orderedSame {
                return lhs.createdAt < rhs.createdAt
            }

            return result == .orderedAscending
        }
    }

    private static func countries(in teams: [Team]) -> [String] {
        let names = teams
            .map { $0.country.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(names))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            let currentPhase = phase

            ZStack {
                Palette.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    masthead(for: currentPhase)
                    content(for: currentPhase)
                }
            }
            .navigationTitle("Teams")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCreateTeam) {
                CreateTeamView(viewModel: viewModel)
            }
            .task(id: refreshSignal.generation) {
                await viewModel.loadTeams()
                await loadOverviews()
                if !Task.isCancelled {
                    hasCompletedFirstLoad = true
                }
            }
        }
    }

    /// Per-team tour and show counts, current tour and next show, all derived
    /// from the existing tours and shows.
    private func loadOverviews() async {
        let teams = viewModel.teams

        do {
            async let fetchedTours = tourRepository.fetchTours()
            async let fetchedShows = showRepository.fetchShows()
            let (tours, shows) = try await (fetchedTours, fetchedShows)

            overviewByTeamID = Dictionary(
                teams.map { team in
                    (
                        team.id,
                        TeamOverview.info(
                            forTeamID: team.id,
                            tours: tours,
                            shows: shows
                        )
                    )
                },
                uniquingKeysWith: { first, _ in first }
            )
        } catch is CancellationError {
            // A superseded load is not a failure.
        } catch {
            // Team loading remains independent; the summaries are supplementary.
            overviewByTeamID = [:]
        }
    }

    // MARK: - Masthead

    private func masthead(for phase: ListPhase<[Team]>) -> some View {
        var teams: [Team] = []

        if case .populated(let populated) = phase {
            teams = populated
        }

        let countries = Self.countries(in: teams)
        let activeCountry = selectedCountry.flatMap { countries.contains($0) ? $0 : nil }

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Teams")
                    .font(.screenTitle)
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle = subtitle(for: teams) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if countries.count > 1 {
                countryMenu(countries: countries, active: activeCountry)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "3 teams · 4 tours". The tour count appears once tours have loaded.
    private func subtitle(for teams: [Team]) -> String? {
        guard !teams.isEmpty else {
            return nil
        }

        let teamText = teams.count == 1 ? "1 team" : "\(teams.count) teams"

        guard !overviewByTeamID.isEmpty else {
            return teamText
        }

        let tourCount = teams.reduce(0) { $0 + (overviewByTeamID[$1.id]?.tourCount ?? 0) }
        let tourText = tourCount == 1 ? "1 tour" : "\(tourCount) tours"

        return "\(teamText) · \(tourText)"
    }

    /// The country filter keeps its place from the previous design, now
    /// behind the "…" button.
    private func countryMenu(countries: [String], active: String?) -> some View {
        Menu {
            Picker("Country", selection: $selectedCountry) {
                Text("All countries").tag(String?.none)

                ForEach(countries, id: \.self) { country in
                    Text(country).tag(Optional(country))
                }
            }
        } label: {
            RoundIconLabel(systemName: "ellipsis")
        }
        .accessibilityLabel("Filter teams")
        .accessibilityValue(active ?? "All countries")
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for phase: ListPhase<[Team]>) -> some View {
        switch phase {
        case .loading:
            LoadingPanel(message: "Loading teams…")

        case .failed(let message):
            StatePanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load teams",
                message: message,
                actionTitle: "Try Again",
                isPrimaryAction: false
            ) {
                Task {
                    await viewModel.loadTeams()
                    await loadOverviews()
                }
            }

        case .empty:
            StatePanel(
                symbol: "music.mic",
                title: "No teams yet",
                message: "A team represents an artist or band whose tours and shows you manage. Create one to start planning.",
                actionTitle: "Create Team",
                isPrimaryAction: true
            ) {
                showingCreateTeam = true
            }

        case .populated(let teams):
            populatedList(teams)
        }
    }

    private func populatedList(_ teams: [Team]) -> some View {
        let countries = Self.countries(in: teams)
        let activeCountry = selectedCountry.flatMap { countries.contains($0) ? $0 : nil }

        let visible = teams.filter { team in
            guard let activeCountry else { return true }
            return team.country.trimmingCharacters(in: .whitespacesAndNewlines) == activeCountry
        }

        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(visible) { team in
                    NavigationLink {
                        TeamDetailView(
                            teamID: team.id,
                            viewModel: viewModel,
                            tourRepository: tourRepository,
                            showRepository: showRepository
                        )
                    } label: {
                        TeamCard(team: team, info: overviewByTeamID[team.id])
                    }
                    .buttonStyle(CardPressStyle())
                    .accessibilityHint("Opens team details")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32 + navInset)
        }
        .scrollIndicators(.hidden)
    }

}

// MARK: - Tag

private struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Palette.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Palette.surfaceRaised))
            .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Card

private struct TeamCard: View {

    let team: Team
    let info: TeamOverview.Info?

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 56

    private var detail: String {
        let location = [team.city.trimmed, team.country.trimmed]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return [team.genre.trimmed, location]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                TeamAvatar(team: team, size: avatarSize, cornerRadius: Radius.control)

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(2)
                    }

                    if let info {
                        HStack(spacing: 6) {
                            TagPill(text: info.tourCount == 1 ? "1 tour" : "\(info.tourCount) tours")
                            TagPill(text: info.showCount == 1 ? "1 show" : "\(info.showCount) shows")
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }

            if let info {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 0.7)
                    .accessibilityHidden(true)

                statusRow(for: info)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    private func statusRow(for info: TeamOverview.Info) -> some View {
        let isOnTour = info.currentTour != nil

        return HStack(spacing: 8) {
            Circle()
                .fill(isOnTour ? Palette.orange : Palette.secondaryText.opacity(0.6))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text(statusText(for: info))
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }

    private func statusText(for info: TeamOverview.Info) -> String {
        if let tour = info.currentTour {
            return "On tour: \(tour.name.trimmed)"
        }

        if let next = info.nextShow {
            let date = next.date.formatted(date: .abbreviated, time: .omitted)
            return "Next show: \(date) · \(next.locationSummary ?? next.name.trimmed)"
        }

        return "No upcoming shows scheduled"
    }
}

// MARK: - Previews

#if DEBUG
private enum TeamListPreviewSupport {

    struct PreviewError: LocalizedError {
        var errorDescription: String? {
            "The local database could not be read."
        }
    }

    struct UnavailableTeamRepository: TeamRepositoryProtocol {

        enum Mode {
            case failing
            case neverLoading
        }

        let mode: Mode

        func fetchTeams() async throws -> [Team] {
            switch mode {
            case .failing:
                throw PreviewError()
            case .neverLoading:
                try await Task.sleep(for: .seconds(3600))
                return []
            }
        }

        func fetchTeam(id: UUID) async throws -> Team { throw PreviewError() }
        func createTeam(_ team: Team) async throws { throw PreviewError() }
        func updateTeam(_ team: Team) async throws { throw PreviewError() }
        func deleteTeam(id: UUID) async throws { throw PreviewError() }
    }

    private static func team(
        _ name: String,
        _ genre: String,
        _ city: String,
        _ country: String
    ) -> Team {
        Team(
            id: UUID(),
            name: name,
            genre: genre,
            country: country,
            city: city,
            createdAt: Date(),
            version: 1
        )
    }

    static let sampleTeams: [Team] = [
        team("Silver Echo", "Indie Rock", "Berlin", "Germany"),
        team("Northbound", "Alternative Rock", "London", "UK"),
        team("The Midnight Crew", "Synthwave", "Los Angeles", "USA"),
        team("Paper Lanterns", "Dream Pop", "Tokyo", "Japan"),
        team("Velvet Static", "Post-Punk", "Manchester", "UK"),
        team("Low Tide Collective", "Indie Folk", "Melbourne", "Australia"),
        team("Crew 7", "", "Lisbon", ""),
        team(
            "The Extraordinarily Long Named Touring Orchestra of Somewhere",
            "Chamber Pop",
            "Reykjavík",
            "Iceland"
        )
    ]

    static func makeContainer(teams: [Team]) -> ModelContainer {
        let container = try! ModelContainer(
            for: TeamEntity.self,
            TourEntity.self,
            ShowEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        for team in teams {
            container.mainContext.insert(TeamEntity(team: team))
        }

        try? container.mainContext.save()

        return container
    }

    static func makeView(
        container: ModelContainer,
        teamRepository: TeamRepositoryProtocol? = nil
    ) -> some View {
        let context = container.mainContext

        return TeamListView(
            repository: teamRepository
                ?? SwiftDataTeamRepository(modelContext: context),
            tourRepository: SwiftDataTourRepository(modelContext: context),
            showRepository: SwiftDataShowRepository(modelContext: context)
        )
        .environment(DataRefreshSignal())
        .modelContainer(container)
    }
}

#Preview("Populated, light") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(
            teams: TeamListPreviewSupport.sampleTeams
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Populated, dark") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(
            teams: TeamListPreviewSupport.sampleTeams
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(
            teams: TeamListPreviewSupport.sampleTeams
        )
    )
    .dynamicTypeSize(.accessibility3)
}

#Preview("Empty") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(teams: [])
    )
}

#Preview("Load Error") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(teams: []),
        teamRepository: TeamListPreviewSupport.UnavailableTeamRepository(
            mode: .failing
        )
    )
}

#Preview("Loading") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(teams: []),
        teamRepository: TeamListPreviewSupport.UnavailableTeamRepository(
            mode: .neverLoading
        )
    )
}
#endif
