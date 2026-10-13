//
//  TeamListView.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI
import UIKit

#if DEBUG
import SwiftData
#endif

struct TeamListView: View {

    let repository: TeamRepositoryProtocol
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @Environment(DataRefreshSignal.self) private var refreshSignal

    @State private var viewModel: TeamListViewModel
    @State private var showingCreateTeam = false
    @State private var hasCompletedFirstLoad = false
    @State private var selectedCountry: String?
    @State private var nextShowsByTeamID: [UUID: Show] = [:]

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

    private enum Phase {
        case loading
        case failed(String)
        case empty
        case populated([Team])
    }

    private var phase: Phase {
        if viewModel.isLoading || !hasCompletedFirstLoad {
            return .loading
        }

        if viewModel.teams.isEmpty {
            if let message = viewModel.errorMessage {
                return .failed(message)
            }
            return .empty
        }

        return .populated(Self.alphabetical(viewModel.teams))
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
                    .preferredColorScheme(.dark)
                    .tint(Palette.accent)
            }
            .task(id: refreshSignal.generation) {
                await viewModel.loadTeams()
                await loadUpcomingShows()
                hasCompletedFirstLoad = true
            }
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }

    private func loadUpcomingShows() async {
        do {
            async let fetchedTours = tourRepository.fetchTours()
            async let fetchedShows = showRepository.fetchShows()
            let (tours, shows) = try await (fetchedTours, fetchedShows)

            let teamIDByTourID = Dictionary(
                tours.map { ($0.id, $0.teamID) },
                uniquingKeysWith: { first, _ in first }
            )
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var upcoming: [UUID: Show] = [:]

            for show in shows where calendar.startOfDay(for: show.date) >= today {
                guard let teamID = teamIDByTourID[show.tourID] else { continue }
                if let current = upcoming[teamID], current.date <= show.date { continue }
                upcoming[teamID] = show
            }

            nextShowsByTeamID = upcoming
        } catch {
            // Team loading remains independent; show details are supplementary.
            nextShowsByTeamID = [:]
        }
    }

    // MARK: - Masthead

    private func masthead(for phase: Phase) -> some View {
        var teamCount: Int?
        var showsCreateButton = true

        switch phase {
        case .populated(let teams):
            teamCount = teams.count
        case .empty:
            showsCreateButton = false
        case .loading, .failed:
            break
        }

        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Teams")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                if let teamCount {
                    let countLabel = teamCount == 1 ? "1 team" : "\(teamCount) teams"
                    Text("Your touring teams · \(countLabel)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                } else {
                    Text("Your touring teams")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if showsCreateButton {
                createButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var createButton: some View {
        Button {
            showingCreateTeam = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Palette.accent))
                .contentShape(Circle())
        }
        .buttonStyle(PressFadeStyle())
        .accessibilityLabel("New Team")
        .accessibilityHint("Creates a new team")
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for phase: Phase) -> some View {
        switch phase {
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Palette.accent)

                Text("Loading teams…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)

        case .failed(let message):
            StatusPanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load teams",
                message: message,
                actionTitle: "Try Again",
                isPrimaryAction: false
            ) {
                Task {
                    await viewModel.loadTeams()
                    await loadUpcomingShows()
                }
            }

        case .empty:
            StatusPanel(
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

        return VStack(spacing: 0) {
            if countries.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        FilterPill(title: "All", isSelected: activeCountry == nil) {
                            selectedCountry = nil
                        }

                        ForEach(countries, id: \.self) { country in
                            FilterPill(title: country, isSelected: activeCountry == country) {
                                selectedCountry = country
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }

            ScrollView {
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
                            TeamCard(team: team, nextShow: nextShowsByTeamID[team.id])
                        }
                        .buttonStyle(CardPressStyle())
                        .accessibilityHint("Opens team details")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, countries.count > 1 ? 3 : 10)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

}

// MARK: - Filter pill

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Palette.canvas : Palette.secondaryText)
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .background(
                    Capsule().fill(isSelected ? Color.white : Palette.surface)
                )
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Palette.hairline, lineWidth: 0.7)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Informational chips



private struct OutlineChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay {
                Capsule()
                    .strokeBorder(color.opacity(0.9), lineWidth: 0.8)
            }
            .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Card

private struct TeamCard: View {

    let team: Team
    let nextShow: Show?

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 48

    private var locationTone: Color { ContinentColorMapper.color(for: country) }

    private var genreTone: Color { GenreColorMapper.color(for: genre) }

    private var genre: String {
        team.genre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var city: String {
        team.city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var country: String {
        team.country.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                artistImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(locationSummary)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !genre.isEmpty || !country.isEmpty {
                        HStack(spacing: 5) {
                            if !genre.isEmpty {
                                OutlineChip(text: genre, color: genreTone)
                            }
                            if !country.isEmpty {
                                OutlineChip(text: country, color: locationTone)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText.opacity(0.75))
                    .padding(.leading, 1)
                    .accessibilityHidden(true)
            }

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.5)

            nextShowRow
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var artistImage: some View {
        if let imageData = team.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 0.8)
                }
                .accessibilityLabel("Artist image for \(team.name)")
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.surfaceRaised)
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.secondaryText.opacity(0.8))
                }
                .frame(width: avatarSize, height: avatarSize)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 0.8)
                }
                .accessibilityLabel("No artist image")
        }
    }

    @ViewBuilder
    private var nextShowRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.chipAccent)
                .frame(width: 15)
                .accessibilityHidden(true)

            Text("NEXT")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(Palette.secondaryText)

            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1, height: 20)

            if let nextShow {
                VStack(alignment: .leading, spacing: 3) {
                    Text(nextShow.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(1)

                    Text(showLocation(nextShow))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No upcoming shows scheduled")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 24, alignment: .leading)
    }

    private func showLocation(_ show: Show) -> String {
        let venue = show.venue.trimmingCharacters(in: .whitespacesAndNewlines)
        let showCity = show.city.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (venue.isEmpty, showCity.isEmpty) {
        case (false, false): return "\(venue) · \(showCity)"
        case (false, true): return venue
        case (true, false): return showCity
        case (true, true): return show.name
        }
    }

    private var locationSummary: String {
        city.isEmpty ? "Touring team workspace" : city
    }
}

// MARK: - Status panel (empty / error)

private struct StatusPanel: View {

    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let isPrimaryAction: Bool
    let action: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.surfaceRaised)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(.title, weight: .medium))
                            .foregroundStyle(Palette.chipAccent)
                    }
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Palette.primaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.body)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle(isProminent: isPrimaryAction))
                    .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 64)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Button styles

private struct PillButtonStyle: ButtonStyle {

    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? Color.white : Palette.primaryText)
            .padding(.horizontal, 26)
            .frame(minHeight: 48)
            .background {
                Capsule()
                    .fill(isProminent ? Palette.accent : Palette.surfaceRaised)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

private struct PressFadeStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct CardPressStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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

#Preview("Populated") {
    TeamListPreviewSupport.makeView(
        container: TeamListPreviewSupport.makeContainer(
            teams: TeamListPreviewSupport.sampleTeams
        )
    )
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
