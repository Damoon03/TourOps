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
        viewModel.tours
            .filter { $0.teamID == teamID }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startDate < rhs.startDate
            }
    }

    private enum Phase {
        case loading
        case failed(String)
        case empty
        case populated([Tour])
    }

    private var phase: Phase {
        if viewModel.isLoading || !hasCompletedFirstLoad {
            return .loading
        }

        if teamTours.isEmpty {
            if let message = viewModel.errorMessage {
                return .failed(message)
            }

            return .empty
        }

        return .populated(teamTours)
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                content(for: phase)
            }
        }
        .navigationTitle("Tours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Palette.canvas,
            for: .navigationBar
        )
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateTour = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("New Tour")
            }
        }
        .sheet(isPresented: $showingCreateTour) {
            CreateTourView(
                viewModel: viewModel,
                teamID: teamID
            )
            .preferredColorScheme(.dark)
            .tint(Palette.accent)
        }
        .task(id: refreshSignal.generation) {
            await viewModel.loadTours()
            hasCompletedFirstLoad = true
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOUR SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Palette.chipAccent)

            Text("Plan the run.")
                .font(
                    .system(
                        size: 27,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Palette.primaryText)

            Text("Manage tour dates and their live performances.")
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

                Text("Loading tours…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            statePanel(
                symbol: "exclamationmark.triangle",
                title: "Couldn’t load tours",
                message: message,
                actionTitle: "Try Again"
            ) {
                Task {
                    await viewModel.loadTours()
                    hasCompletedFirstLoad = true
                }
            }

        case .empty:
            statePanel(
                symbol: "music.note.list",
                title: "No tours yet",
                message: "Create a tour to start organizing its shows.",
                actionTitle: "Create Tour"
            ) {
                showingCreateTour = true
            }

        case .populated(let tours):
            ScrollView {
                LazyVStack(spacing: 12) {
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
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens tour details")
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
    Text("Tour List Preview")
}
