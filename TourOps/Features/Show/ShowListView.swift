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

    private var tourShows: [Show] {
        viewModel.shows
            .filter { $0.tourID == tourID }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.date < rhs.date
            }
    }

    private enum Phase {
        case loading
        case failed(String)
        case empty
        case populated([Show])
    }

    private var phase: Phase {
        if viewModel.isLoading || !hasCompletedFirstLoad {
            return .loading
        }

        if tourShows.isEmpty {
            if let message = viewModel.errorMessage {
                return .failed(message)
            }

            return .empty
        }

        return .populated(tourShows)
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                content(for: phase)
            }
        }
        .navigationTitle("Shows")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Palette.canvas,
            for: .navigationBar
        )
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateShow = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("New Show")
            }
        }
        .sheet(isPresented: $showingCreateShow) {
            CreateShowView(
                viewModel: viewModel,
                tourID: tourID
            )
            .preferredColorScheme(.dark)
            .tint(Palette.accent)
        }
        .task(id: refreshSignal.generation) {
            await viewModel.loadShows()
            hasCompletedFirstLoad = true
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIVE PERFORMANCE SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Palette.chipAccent)

            Text("Shows")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text("Keep every performance in this tour organized.")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func content(for phase: Phase) -> some View {
        switch phase {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Palette.accent)

                Text("Loading shows…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            statePanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load shows",
                message: message,
                actionTitle: "Try Again"
            ) {
                Task {
                    await viewModel.loadShows()
                    hasCompletedFirstLoad = true
                }
            }

        case .empty:
            statePanel(
                symbol: "music.mic",
                title: "No shows yet",
                message: "Add a performance to start building this tour’s schedule.",
                actionTitle: "Create Show"
            ) {
                showingCreateShow = true
            }

        case .populated(let shows):
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(shows) { show in
                        NavigationLink {
                            ShowDetailView(
                                showID: show.id,
                                viewModel: viewModel
                            )
                        } label: {
                            ShowView(show: show)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens show details")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func statePanel(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        ScrollView {
            VStack(spacing: 15) {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(Palette.surfaceRaised)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 76, height: 76)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Palette.primaryText)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 46)
                    .background(
                        Palette.accent,
                        in: Capsule()
                    )
                    .padding(.top, 5)
            }
            .padding(.horizontal, 28)
            .padding(.top, 54)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    Text("Show List Preview")
}
