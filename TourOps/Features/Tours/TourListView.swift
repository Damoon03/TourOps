//
//  TourListView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct TourListView: View {

    let repository: TourRepositoryProtocol
    let teamID: UUID
    let showRepository: ShowRepositoryProtocol

    @Environment(DataRefreshSignal.self) private var refreshSignal

    @State private var viewModel: TourListViewModel
    @State private var showingCreateTour = false
    @State private var hasCompletedFirstLoad = false

    init(
        repository: TourRepositoryProtocol,
        teamID: UUID,
        showRepository: ShowRepositoryProtocol
    ) {
        self.repository = repository
        self.teamID = teamID
        self.showRepository = showRepository

        _viewModel = State(
            initialValue: TourListViewModel(
                repository: repository
            )
        )
    }

    private var teamTours: [Tour] {
        viewModel.tours.filter { $0.teamID == teamID }
    }

    private var phase: ListPhase<TourSchedule.Sections> {
        ListPhase.resolve(
            isLoading: viewModel.isLoading,
            hasCompletedFirstLoad: hasCompletedFirstLoad,
            isEmpty: teamTours.isEmpty,
            loadError: viewModel.loadErrorMessage,
            populated: { TourSchedule.sections(from: teamTours) }
        )
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            content(for: phase)
        }
        .navigationTitle("Tours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateTour = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Tour")
            }
        }
        .sheet(isPresented: $showingCreateTour) {
            CreateTourView(
                viewModel: viewModel,
                teamID: teamID
            )
        }
        .task(id: refreshSignal.generation) {
            await load()
        }
    }

    private func load() async {
        await viewModel.loadTours()
        if !Task.isCancelled {
            hasCompletedFirstLoad = true
        }
    }

    @ViewBuilder
    private func content(for phase: ListPhase<TourSchedule.Sections>) -> some View {
        switch phase {
        case .loading:
            LoadingPanel(message: "Loading tours…")

        case .failed(let message):
            StatePanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load tours",
                message: message,
                actionTitle: "Try Again",
                isPrimaryAction: false
            ) {
                Task { await load() }
            }

        case .empty:
            StatePanel(
                symbol: "music.note.list",
                title: "No tours yet",
                message: "Create a tour to start organizing its shows.",
                actionTitle: "Create Tour"
            ) {
                showingCreateTour = true
            }

        case .populated(let sections):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenHeader(
                        eyebrow: "TOUR SCHEDULE",
                        title: headerTitle(for: sections),
                        subtitle: "Manage tour dates and their live performances."
                    )
                    .padding(.bottom, 8)

                    if !sections.upcoming.isEmpty {
                        SectionHeading("UPCOMING AND IN PROGRESS")
                            .padding(.top, 4)

                        rows(sections.upcoming)
                    }

                    if !sections.past.isEmpty {
                        SectionHeading("PAST")
                            .padding(.top, 12)

                        rows(sections.past)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func headerTitle(for sections: TourSchedule.Sections) -> String {
        let count = sections.upcoming.count + sections.past.count
        return count == 1 ? "1 Tour" : "\(count) Tours"
    }

    private func rows(_ tours: [Tour]) -> some View {
        ForEach(tours) { tour in
            NavigationLink {
                TourDetailView(
                    tourID: tour.id,
                    viewModel: viewModel,
                    showRepository: showRepository
                )
            } label: {
                TourView(tour: tour)
            }
            .buttonStyle(CardPressStyle())
            .accessibilityHint("Opens tour details")
        }
    }
}

#if DEBUG
@MainActor
private func previewList(
    tours: [Tour],
    mode: PreviewRepositoryMode = .normal
) -> some View {
    NavigationStack {
        TourListView(
            repository: PreviewTourRepository(tours: tours, mode: mode),
            teamID: PreviewData.teamID,
            showRepository: PreviewShowRepository()
        )
    }
    .environment(DataRefreshSignal())
    .preferredColorScheme(.dark)
}

#Preview("Populated") {
    previewList(tours: [
        PreviewData.upcomingTour,
        PreviewData.currentTour,
        PreviewData.pastTour,
        PreviewData.longTour
    ])
}

#Preview("Empty") {
    previewList(tours: [])
}

#Preview("Loading") {
    previewList(tours: [], mode: .neverLoading)
}

#Preview("Error") {
    previewList(tours: [], mode: .failing)
}

#Preview("Accessibility text size") {
    previewList(tours: [PreviewData.upcomingTour, PreviewData.longTour])
        .dynamicTypeSize(.accessibility3)
}
#endif
