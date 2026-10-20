//
//  AppShell.swift
//  TourOps
//
//  The signed-in app: the Schedule and Teams tabs with the floating capsule
//  navigation, the round add button and the global create menu.
//
//  Both tabs stay alive and keep their own navigation stacks, so switching
//  tabs does not lose the place the user was in. The floating controls sit
//  above both stacks, so they stay visible on pushed screens too.
//
//  Creation reuses the existing Create Team, Create Tour and Create Show
//  forms and their view models; this view only decides which one to present.
//

import SwiftUI

struct AppShell: View {

    let teamRepository: TeamRepositoryProtocol
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @Environment(DataRefreshSignal.self) private var refreshSignal
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: AppTab = .schedule
    @State private var isMenuOpen = false
    @State private var activeSheet: CreateAction?

    /// Teams and tours the create menu needs to know about: the pickers in the
    /// forms, and whether a show or tour can be created at all.
    @State private var teams: [Team] = []
    @State private var tours: [Tour] = []

    /// View models for the creation flows. They only create; the lists reload
    /// through the refresh signal once a sheet is dismissed.
    @State private var teamModel: TeamListViewModel
    @State private var tourModel: TourListViewModel
    @State private var showModel: ShowListViewModel

    init(
        teamRepository: TeamRepositoryProtocol,
        tourRepository: TourRepositoryProtocol,
        showRepository: ShowRepositoryProtocol
    ) {
        self.teamRepository = teamRepository
        self.tourRepository = tourRepository
        self.showRepository = showRepository

        _teamModel = State(initialValue: TeamListViewModel(repository: teamRepository))
        _tourModel = State(initialValue: TourListViewModel(repository: tourRepository))
        _showModel = State(initialValue: ShowListViewModel(repository: showRepository))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            tabs
                .environment(\.floatingNavInset, FloatingNavMetrics.contentInset)
                .blur(radius: isMenuOpen ? 10 : 0)
                .overlay {
                    Color.black
                        .opacity(isMenuOpen ? (colorScheme == .dark ? 0.35 : 0.18) : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .allowsHitTesting(!isMenuOpen)
                .accessibilityHidden(isMenuOpen)

            if isMenuOpen {
                // Tapping anywhere outside the menu closes it.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        isMenuOpen = false
                    }
                    .accessibilityHidden(true)
            }

            controls
        }
        .animation(.snappy(duration: 0.28), value: isMenuOpen)
        .sheet(
            item: $activeSheet,
            onDismiss: {
                // Whatever was just created should show up everywhere.
                refreshSignal.bump()
            }
        ) { sheet in
            sheetContent(for: sheet)
        }
        .task(id: refreshSignal.generation) {
            await loadOptions()
        }
        .onChange(of: selectedTab) { _, _ in
            isMenuOpen = false
            refreshSignal.bump()
        }
    }

    // MARK: - Tabs

    private var tabs: some View {
        ZStack {
            ScheduleView(
                teamRepository: teamRepository,
                tourRepository: tourRepository,
                showRepository: showRepository
            )
            .opacity(selectedTab == .schedule ? 1 : 0)
            .allowsHitTesting(selectedTab == .schedule)
            .accessibilityHidden(selectedTab != .schedule)

            TeamListView(
                repository: teamRepository,
                tourRepository: tourRepository,
                showRepository: showRepository
            )
            .opacity(selectedTab == .teams ? 1 : 0)
            .allowsHitTesting(selectedTab == .teams)
            .accessibilityHidden(selectedTab != .teams)
        }
    }

    // MARK: - Floating controls

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isMenuOpen {
                CreateMenu(
                    canCreateShow: !tourOptions.isEmpty,
                    canCreateTour: !teamOptions.isEmpty,
                    onSelect: select
                )
                .transition(
                    .scale(scale: 0.92, anchor: .bottomTrailing)
                        .combined(with: .opacity)
                )
            }

            HStack(spacing: 12) {
                FloatingNavBar(selection: $selectedTab)

                FloatingAddButton(isOpen: isMenuOpen) {
                    isMenuOpen.toggle()
                }
            }
            .overlay(alignment: .topLeading) {
                // Shows offline, unsynced-count or brief synced state.
                SyncStatusPill()
                    .padding(.leading, 6)
                    .alignmentGuide(.top) { dimensions in
                        dimensions[.bottom] + 10
                    }
            }
        }
        .padding(.horizontal, FloatingNavMetrics.horizontalPadding)
        .padding(.bottom, FloatingNavMetrics.bottomPadding)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func select(_ action: CreateAction) {
        isMenuOpen = false
        activeSheet = action
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for sheet: CreateAction) -> some View {
        switch sheet {
        case .show:
            CreateShowView(
                viewModel: showModel,
                tourID: ScheduleAgenda.defaultTour(in: reachableTours)?.id ?? UUID(),
                tourChoices: tourOptions
            )

        case .tour:
            CreateTourView(
                viewModel: tourModel,
                teamID: teamOptions.first?.id ?? UUID(),
                teamChoices: teamOptions
            )

        case .team:
            CreateTeamView(viewModel: teamModel)
        }
    }

    // MARK: - Options

    /// Tours whose team still exists. Deleting a team does not delete its
    /// tours, but the app can no longer reach them.
    private var reachableTours: [Tour] {
        let teamIDs = Set(teams.map(\.id))
        return tours.filter { teamIDs.contains($0.teamID) }
    }

    private var teamOptions: [PickerOption] {
        teams
            .sorted { lhs, rhs in
                let result = lhs.name.localizedStandardCompare(rhs.name)

                if result == .orderedSame {
                    return lhs.createdAt < rhs.createdAt
                }

                return result == .orderedAscending
            }
            .map { team in
                PickerOption(id: team.id, title: team.name, subtitle: nil)
            }
    }

    private var tourOptions: [PickerOption] {
        let teamNames = Dictionary(
            teams.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        let sections = TourSchedule.sections(from: reachableTours)

        return (sections.upcoming + sections.past).map { tour in
            PickerOption(
                id: tour.id,
                title: tour.name,
                subtitle: teamNames[tour.teamID]
            )
        }
    }

    private func loadOptions() async {
        do {
            async let fetchedTeams = teamRepository.fetchTeams()
            async let fetchedTours = tourRepository.fetchTours()

            let (loadedTeams, loadedTours) = try await (fetchedTeams, fetchedTours)

            teams = loadedTeams
            tours = loadedTours
        } catch {
            // Keep the last known options; the screens report their own errors.
        }
    }
}
