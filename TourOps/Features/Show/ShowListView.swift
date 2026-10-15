//
//  ShowListView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct ShowListView: View {

    let repository: ShowRepositoryProtocol
    let tourID: UUID

    @Environment(DataRefreshSignal.self) private var refreshSignal
    @Environment(\.floatingNavInset) private var navInset

    @State private var viewModel: ShowListViewModel
    @State private var showingCreateShow = false
    @State private var hasCompletedFirstLoad = false

    init(
        repository: ShowRepositoryProtocol,
        tourID: UUID
    ) {
        self.repository = repository
        self.tourID = tourID

        _viewModel = State(
            initialValue: ShowListViewModel(
                repository: repository
            )
        )
    }

    private var phase: ListPhase<[Show]> {
        viewModel.listPhase(
            forTourID: tourID,
            hasCompletedFirstLoad: hasCompletedFirstLoad
        )
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            content(for: phase)
        }
        .navigationTitle("Shows")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateShow = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Show")
            }
        }
        .sheet(isPresented: $showingCreateShow) {
            CreateShowView(
                viewModel: viewModel,
                tourID: tourID
            )
        }
        .task(id: refreshSignal.generation) {
            await load()
        }
    }

    private func load() async {
        await viewModel.loadShows()

        // A cancelled load was superseded; the replacement marks completion.
        if !Task.isCancelled {
            hasCompletedFirstLoad = true
        }
    }

    @ViewBuilder
    private func content(for phase: ListPhase<[Show]>) -> some View {
        switch phase {
        case .loading:
            LoadingPanel(message: "Loading shows…")

        case .failed(let message):
            StatePanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load shows",
                message: message,
                actionTitle: "Try Again",
                isPrimaryAction: false
            ) {
                Task { await load() }
            }

        case .empty:
            StatePanel(
                symbol: "music.mic",
                title: "No shows yet",
                message: "Add a performance to start building this tour’s schedule.",
                actionTitle: "Create Show"
            ) {
                showingCreateShow = true
            }

        case .populated(let shows):
            let sections = ShowSchedule.sections(from: shows)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenHeader(
                        eyebrow: "LIVE PERFORMANCE SCHEDULE",
                        title: headerTitle(for: sections),
                        subtitle: "Keep every performance in this tour organized."
                    )
                    .padding(.bottom, 8)

                    if !sections.upcoming.isEmpty {
                        SectionHeading("UPCOMING")
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
                .padding(.bottom, 32 + navInset)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func headerTitle(for sections: ShowSchedule.Sections) -> String {
        let count = sections.upcoming.count + sections.past.count
        return count == 1 ? "1 Show" : "\(count) Shows"
    }

    private func rows(_ shows: [Show]) -> some View {
        ForEach(shows) { show in
            NavigationLink {
                ShowDetailView(
                    showID: show.id,
                    viewModel: viewModel
                )
            } label: {
                ShowView(show: show)
            }
            .buttonStyle(CardPressStyle())
            .accessibilityHint("Opens show details")
        }
    }
}

#if DEBUG
@MainActor
private func previewList(
    shows: [Show],
    mode: PreviewRepositoryMode = .normal
) -> some View {
    NavigationStack {
        ShowListView(
            repository: PreviewShowRepository(shows: shows, mode: mode),
            tourID: PreviewData.tourID
        )
    }
    .environment(DataRefreshSignal())
    .preferredColorScheme(.dark)
}

#Preview("Populated") {
    previewList(shows: [
        PreviewData.upcomingShow,
        PreviewData.todayShow,
        PreviewData.pastShow,
        PreviewData.longShow
    ])
}

#Preview("Empty") {
    previewList(shows: [])
}

#Preview("Loading") {
    previewList(shows: [], mode: .neverLoading)
}

#Preview("Error") {
    previewList(shows: [], mode: .failing)
}

#Preview("Accessibility text size") {
    previewList(shows: [PreviewData.upcomingShow, PreviewData.longShow])
        .dynamicTypeSize(.accessibility3)
}
#endif
