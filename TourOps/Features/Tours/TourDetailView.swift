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

    /// The team that owns the tour, when the caller has it. Only used to show
    /// the team's identity in the summary card.
    let team: Team?

    @Environment(\.dismiss) private var dismiss
    @Environment(DataRefreshSignal.self) private var refreshSignal

    @State private var showingEditTour = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var gate = SubmissionGate()

    /// Holds this tour's shows and handles editing and deleting from show
    /// detail.
    @State private var showModel: ShowListViewModel

    /// `false` until the shows have been read, or if reading them failed. The
    /// summary and the delete message then say less rather than guess.
    @State private var hasLoadedShows = false

    init(
        tourID: UUID,
        viewModel: TourListViewModel,
        showRepository: ShowRepositoryProtocol,
        team: Team? = nil
    ) {
        self.tourID = tourID
        self.viewModel = viewModel
        self.showRepository = showRepository
        self.team = team

        _showModel = State(
            initialValue: ShowListViewModel(repository: showRepository)
        )
    }

    private var tour: Tour? {
        viewModel.tours.first { $0.id == tourID }
    }

    private var tourShows: [Show] {
        showModel.shows.filter { $0.tourID == tourID }
    }

    var body: some View {
        Group {
            if let tour {
                ScreenScroll {
                    summaryCard(for: tour)
                    upcomingSection(for: tour)
                    allShowsLink(for: tour)
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
                Menu {
                    Button {
                        showingEditTour = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(tour == nil || gate.isRunning)
                .accessibilityLabel("Tour actions")
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
            Text(
                DeletionMessage.tour(
                    showCount: hasLoadedShows ? tourShows.count : nil
                )
            )
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
            await loadShows()
        }
        .onAppear {
            // Coming back from the full shows list, which has its own state.
            if hasLoadedShows {
                Task { await loadShows() }
            }
        }
    }

    private func loadShows() async {
        await showModel.loadShows()

        // Keep any earlier shows if reading failed; the rest of the screen
        // still works.
        if !Task.isCancelled {
            hasLoadedShows = showModel.loadErrorMessage == nil
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

    // MARK: - Summary

    private func summaryCard(for tour: Tour) -> some View {
        let stats = TourTimeline.stats(tour: tour, shows: tourShows)
        let layout = TourTimeline.layout(tour: tour, shows: tourShows)

        let nextText = stats.nextShow?.date.formatted(
            .dateTime.day().month(.abbreviated)
        ) ?? "—"

        return VStack(alignment: .leading, spacing: 16) {
            if let team {
                HStack(spacing: 8) {
                    Monogram(
                        initials: team.name.monogram(maxLetters: 2),
                        tint: TeamTints.tint(for: team.id),
                        size: 22
                    )

                    Text(team.name)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tour.name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(TourTimeline.rangeText(for: tour))
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }

            HStack(alignment: .top, spacing: 12) {
                stat(value: "\(stats.showCount)", label: "shows")
                stat(value: "\(stats.playedCount)", label: "played")
                stat(value: nextText, label: "next show")
            }

            TourTimelineBar(
                layout: layout,
                startLabel: tour.startDate.formatted(
                    .dateTime.day().month(.abbreviated)
                ),
                endLabel: tour.endDate.formatted(
                    .dateTime.day().month(.abbreviated)
                ),
                accessibilityText: timelineDescription(stats: stats)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.hero)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func timelineDescription(stats: TourTimeline.Stats) -> String {
        "Tour timeline. \(stats.showCount) shows, \(stats.playedCount) played, \(stats.upcomingCount) to go."
    }

    // MARK: - Upcoming shows

    private func upcomingSection(for tour: Tour) -> some View {
        let stats = TourTimeline.stats(tour: tour, shows: tourShows)
        let upcoming = tourShows
            .filter { ShowSchedule.isAhead($0, of: Date()) }
            .sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Upcoming shows")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                if !upcoming.isEmpty {
                    Text("\(upcoming.count) left")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            if upcoming.isEmpty {
                Text(emptyUpcomingText(totalCount: stats.showCount))
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .padding(.horizontal, 16)
                    .cardSurface()
            } else {
                ForEach(upcoming) { show in
                    NavigationLink {
                        ShowDetailView(
                            showID: show.id,
                            viewModel: showModel
                        )
                    } label: {
                        UpcomingShowRow(
                            show: show,
                            isNext: show.id == stats.nextShow?.id
                        )
                    }
                    .buttonStyle(CardPressStyle())
                    .accessibilityHint("Opens show details")
                }
            }
        }
    }

    private func emptyUpcomingText(totalCount: Int) -> String {
        guard hasLoadedShows else {
            return "Loading shows…"
        }

        return totalCount == 0
            ? "No shows yet. Use + to add the first one."
            : "No upcoming shows."
    }

    // MARK: - All shows

    private func allShowsLink(for tour: Tour) -> some View {
        NavigationLink {
            ShowListView(
                repository: showRepository,
                tourID: tour.id
            )
        } label: {
            NavigationCardLabel(
                symbol: "music.mic",
                title: "All shows",
                lines: showLines(for: tour)
            )
        }
        .buttonStyle(CardPressStyle())
        .accessibilityHint("Opens every show for this tour, including past ones")
    }

    private func showLines(for tour: Tour) -> [String] {
        guard hasLoadedShows else {
            return ["Manage individual live performances"]
        }

        let stats = TourTimeline.stats(tour: tour, shows: tourShows)

        guard stats.showCount > 0 else {
            return ["No shows yet. Add the first one."]
        }

        var lines = [
            stats.showCount == 1 ? "1 show" : "\(stats.showCount) shows"
        ]

        if let next = stats.nextShow {
            let date = next.date.formatted(date: .abbreviated, time: .omitted)
            lines.append("Next: \(next.name.trimmed), \(date)")
        } else {
            lines.append("No upcoming shows")
        }

        return lines
    }
}

// MARK: - Upcoming row

private struct UpcomingShowRow: View {

    let show: Show
    let isNext: Bool

    private var title: String {
        let city = show.city.trimmed
        return city.isEmpty ? show.name.trimmed : city
    }

    private var detail: String {
        let time = show.date.formatted(date: .omitted, time: .shortened)
        let venue = show.venue.trimmed

        return venue.isEmpty ? time : "\(time) · \(venue)"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(show.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(isNext ? Palette.onAccent.opacity(0.85) : Palette.secondaryText)

                Text(show.date.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isNext ? Palette.onAccent : Palette.primaryText)
            }
            .frame(width: 50, height: 54)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isNext ? Palette.accent : Palette.surfaceRaised)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(2)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), \(show.date.formatted(date: .complete, time: .shortened))\(isNext ? ", next show" : "")"
        )
    }
}

// MARK: - Timeline

/// The tour's date range as a track with one dot per show, an orange marker
/// for today and a ringed dot for the next show.
private struct TourTimelineBar: View {

    let layout: TourTimeline.Layout
    let startLabel: String
    let endLabel: String
    let accessibilityText: String

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Palette.track)
                        .frame(width: width, height: 4)
                        .offset(y: 10)

                    ForEach(layout.markers) { marker in
                        dot(for: marker)
                            .position(x: width * marker.position, y: 12)
                    }

                    if let today = layout.todayPosition {
                        todayMarker
                            .position(x: width * today, y: 12)
                    }
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 7)

            HStack {
                Text(startLabel)
                Spacer(minLength: 8)
                Text(endLabel)
            }
            .font(.caption)
            .foregroundStyle(Palette.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func dot(for marker: TourTimeline.Marker) -> some View {
        if marker.isPlayed {
            Circle()
                .strokeBorder(Palette.secondaryText, lineWidth: 1.2)
                .background(Circle().fill(Palette.surface))
                .frame(width: 8, height: 8)
        } else if marker.isNext {
            Circle()
                .fill(Palette.primaryText)
                .frame(width: 8, height: 8)
                .overlay {
                    Circle()
                        .strokeBorder(Palette.orange, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
        } else {
            Circle()
                .fill(Palette.primaryText)
                .frame(width: 8, height: 8)
        }
    }

    private var todayMarker: some View {
        ZStack {
            Rectangle()
                .fill(Palette.orange)
                .frame(width: 2, height: 22)

            Circle()
                .strokeBorder(Palette.orange, lineWidth: 2)
                .background(Circle().fill(Palette.surface))
                .frame(width: 11, height: 11)
        }
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
            showRepository: PreviewShowRepository(shows: shows),
            team: PreviewData.team
        )
    }
    .environment(DataRefreshSignal())
}

#Preview("With shows, light") {
    previewDetail(
        tour: PreviewData.currentTour,
        shows: [PreviewData.upcomingShow, PreviewData.pastShow]
    )
    .preferredColorScheme(.light)
}

#Preview("With shows, dark") {
    previewDetail(
        tour: PreviewData.currentTour,
        shows: [PreviewData.upcomingShow, PreviewData.pastShow]
    )
    .preferredColorScheme(.dark)
}

#Preview("No shows") {
    previewDetail(tour: PreviewData.upcomingTour, shows: [])
}

#Preview("Long text, large type") {
    previewDetail(tour: PreviewData.longTour, shows: [PreviewData.longShow])
        .dynamicTypeSize(.accessibility3)
}
#endif
