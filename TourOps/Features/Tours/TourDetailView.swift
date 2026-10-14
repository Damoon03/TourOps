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
    @Environment(DataRefreshSignal.self) private var refreshSignal

    @State private var showingEditTour = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var gate = SubmissionGate()

    /// `nil` until the shows have been read, or if reading them failed. The
    /// summary and the delete message then say less rather than guess.
    @State private var summary: TourSchedule.ShowSummary?

    @ScaledMetric(relativeTo: .title) private var heroIconSize: CGFloat = 62

    private var tour: Tour? {
        viewModel.tours.first { $0.id == tourID }
    }

    var body: some View {
        Group {
            if let tour {
                ScreenScroll {
                    heroCard(for: tour)
                    scheduleCard(for: tour)
                    showsLink(for: tour)

                    DestructiveButton(
                        title: "Delete Tour",
                        hint: "Asks for confirmation before deleting this tour.",
                        isDisabled: gate.isRunning
                    ) {
                        showingDeleteConfirmation = true
                    }
                }
            } else {
                ContentUnavailableView(
                    "Tour Not Found",
                    systemImage: "music.note.list",
                    description: Text("This tour is no longer available.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas.ignoresSafeArea())
            }
        }
        .navigationTitle("Tour")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditTour = true
                }
                .disabled(tour == nil || gate.isRunning)
            }
        }
        .sheet(isPresented: $showingEditTour) {
            if let tour {
                EditTourView(
                    viewModel: viewModel,
                    tour: tour
                )
            }
        }
        .confirmationDialog(
            "Delete Tour?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Tour", role: .destructive) {
                delete()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(DeletionMessage.tour(showCount: summary?.showCount))
        }
        .alert(
            "Couldn’t Delete Tour",
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
            let shows = try await showRepository.fetchShows()
            summary = TourSchedule.showSummary(
                forTourID: tourID,
                shows: shows
            )
        } catch {
            // Keep any earlier summary; the rest of the screen still works.
        }
    }

    private func delete() {
        guard !gate.isRunning, let tour else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.deleteTour(tour)
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

    private func heroCard(for tour: Tour) -> some View {
        let status = TourTimelineStatus(tour: tour)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                RoundedRectangle(
                    cornerRadius: Radius.control,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.22))
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: heroIconSize, height: heroIconSize)
                .accessibilityHidden(true)

                Spacer()

                StatusBadge(title: status.title, color: status.color)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("TOUR OVERVIEW")
                    .eyebrowStyle(Palette.chipAccent)

                Text(tour.name)
                    .font(.heroTitle)
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.hero)
    }

    // MARK: - Schedule

    private func scheduleCard(for tour: Tour) -> some View {
        DetailCard(heading: "SCHEDULE") {
            DetailRow(
                title: "Start date",
                value: tour.startDate.formatted(date: .long, time: .omitted),
                symbol: "calendar"
            )

            HairlineDivider()

            DetailRow(
                title: "End date",
                value: tour.endDate.formatted(date: .long, time: .omitted),
                symbol: "calendar.badge.clock"
            )
        }
    }

    // MARK: - Shows

    private func showsLink(for tour: Tour) -> some View {
        NavigationLink {
            ShowListView(
                repository: showRepository,
                tourID: tour.id
            )
        } label: {
            NavigationCardLabel(
                symbol: "music.mic",
                title: "Shows",
                lines: showLines
            )
        }
        .buttonStyle(CardPressStyle())
        .accessibilityHint("Opens the shows for this tour")
    }

    private var showLines: [String] {
        guard let summary else {
            return ["Manage individual live performances"]
        }

        guard summary.showCount > 0 else {
            return ["No shows yet. Add the first one."]
        }

        var lines = [
            summary.showCount == 1 ? "1 show" : "\(summary.showCount) shows"
        ]

        if let next = summary.nextShow {
            let date = next.date.formatted(date: .abbreviated, time: .omitted)
            lines.append("Next: \(next.name.trimmed), \(date)")
        } else {
            lines.append("No upcoming shows")
        }

        return lines
    }
}

#if DEBUG
@MainActor
private func previewDetail(
    tour: Tour,
    shows: [Show]
) -> some View {
    let viewModel = TourListViewModel(
        repository: PreviewTourRepository(tours: [tour])
    )
    viewModel.tours = [tour]

    return NavigationStack {
        TourDetailView(
            tourID: tour.id,
            viewModel: viewModel,
            showRepository: PreviewShowRepository(shows: shows)
        )
    }
    .environment(DataRefreshSignal())
    .preferredColorScheme(.dark)
}

#Preview("With shows") {
    previewDetail(
        tour: PreviewData.upcomingTour,
        shows: [PreviewData.upcomingShow, PreviewData.pastShow]
    )
}

#Preview("No shows") {
    previewDetail(tour: PreviewData.upcomingTour, shows: [])
}

#Preview("Long text, large type") {
    previewDetail(tour: PreviewData.longTour, shows: [PreviewData.longShow])
        .dynamicTypeSize(.accessibility3)
}
#endif
