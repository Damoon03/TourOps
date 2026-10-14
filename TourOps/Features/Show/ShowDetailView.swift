//
//  ShowDetailView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct ShowDetailView: View {

    let showID: UUID
    let viewModel: ShowListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var showingEditShow = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var gate = SubmissionGate()

    @ScaledMetric(relativeTo: .title) private var heroIconSize: CGFloat = 62

    private var show: Show? {
        viewModel.shows.first { $0.id == showID }
    }

    var body: some View {
        Group {
            if let show {
                ScreenScroll {
                    heroCard(for: show)
                    scheduleCard(for: show)
                    venueCard(for: show)

                    Text(
                        "Added to TourOps on \(show.createdAt.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DestructiveButton(
                        title: "Delete Show",
                        hint: "Asks for confirmation before deleting this show.",
                        isDisabled: gate.isRunning
                    ) {
                        showingDeleteConfirmation = true
                    }
                }
            } else {
                ContentUnavailableView(
                    "Show Not Found",
                    systemImage: "music.mic",
                    description: Text("This show is no longer available.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas.ignoresSafeArea())
            }
        }
        .navigationTitle("Show")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.canvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditShow = true
                }
                .disabled(show == nil || gate.isRunning)
            }
        }
        .sheet(isPresented: $showingEditShow) {
            if let show {
                EditShowView(
                    viewModel: viewModel,
                    show: show
                )
            }
        }
        .confirmationDialog(
            "Delete Show?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Show", role: .destructive) {
                delete()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(DeletionMessage.show())
        }
        .alert(
            "Couldn’t Delete Show",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }

    private func delete() {
        guard !gate.isRunning, let show else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.deleteShow(show)
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

    private func heroCard(for show: Show) -> some View {
        let status = ShowTimeStatus(date: show.date)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                RoundedRectangle(
                    cornerRadius: Radius.control,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.22))
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: heroIconSize, height: heroIconSize)
                .accessibilityHidden(true)

                Spacer()

                StatusBadge(title: status.title, color: status.color)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("LIVE PERFORMANCE")
                    .eyebrowStyle(Palette.chipAccent)

                Text(show.name)
                    .font(.heroTitle)
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let location = show.locationSummary {
                    Text(location)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.hero)
    }

    // MARK: - Schedule

    private func scheduleCard(for show: Show) -> some View {
        DetailCard(heading: "SCHEDULE") {
            DetailRow(
                title: "Date",
                value: show.date.formatted(date: .long, time: .omitted),
                symbol: "calendar"
            )

            HairlineDivider()

            // Shows store a single moment in time. The time is displayed in
            // this device's time zone, and the zone is named so a show in
            // another region is not silently misread.
            DetailRow(
                title: "Start time",
                value: show.date.formatted(
                    .dateTime.hour().minute().timeZone()
                ),
                symbol: "clock"
            )
        }
    }

    // MARK: - Venue

    private func venueCard(for show: Show) -> some View {
        let venue = show.venue.trimmed
        let city = show.city.trimmed

        return DetailCard(heading: "VENUE") {
            DetailRow(
                title: "Venue",
                value: venue.isEmpty ? "Venue not set" : venue,
                symbol: "building.2"
            )

            HairlineDivider()

            DetailRow(
                title: "City",
                value: city.isEmpty ? "City not set" : city,
                symbol: "mappin.and.ellipse"
            )
        }
    }
}

#if DEBUG
#Preview("Upcoming") {
    NavigationStack {
        ShowDetailView(
            showID: PreviewData.upcomingShow.id,
            viewModel: previewViewModel([PreviewData.upcomingShow])
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Long text, large type") {
    NavigationStack {
        ShowDetailView(
            showID: PreviewData.longShow.id,
            viewModel: previewViewModel([PreviewData.longShow])
        )
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}

#Preview("Not found") {
    NavigationStack {
        ShowDetailView(
            showID: UUID(),
            viewModel: previewViewModel([])
        )
    }
    .preferredColorScheme(.dark)
}

@MainActor
private func previewViewModel(_ shows: [Show]) -> ShowListViewModel {
    let viewModel = ShowListViewModel(
        repository: PreviewShowRepository(shows: shows)
    )
    viewModel.shows = shows
    return viewModel
}
#endif
