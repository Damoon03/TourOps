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

    private var show: Show? {
        viewModel.shows.first { $0.id == showID }
    }

    var body: some View {
        Group {
            if let show {
                ZStack {
                    Palette.canvas.ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            heroCard(for: show)
                            scheduleCard(for: show)
                            locationCard(for: show)
                            deleteButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                ContentUnavailableView(
                    "Show Not Found",
                    systemImage: "music.mic",
                    description: Text(
                        "This show is no longer available."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas.ignoresSafeArea())
            }
        }
        .navigationTitle(show?.name ?? "Show")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            Palette.canvas,
            for: .navigationBar
        )
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditShow = true
                }
                .disabled(show == nil)
            }
        }
        .sheet(isPresented: $showingEditShow) {
            if let show {
                EditShowView(
                    viewModel: viewModel,
                    show: show
                )
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
            }
        }
        .confirmationDialog(
            "Delete Show?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let show else { return }

                Task {
                    let success = await viewModel.deleteShow(show)

                    if success {
                        dismiss()
                    } else {
                        showingError = true
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(
            "Couldn’t Delete Show",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(
                viewModel.errorMessage
                ?? "Something went wrong."
            )
        }
        .tint(Palette.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero

    private func heroCard(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(Palette.accent.opacity(0.22))
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 62, height: 62)

                Spacer()

                ShowStatusBadge(
                    status: ShowTimeStatus(date: show.date)
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("LIVE PERFORMANCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Palette.chipAccent)

                Text(show.name)
                    .font(
                        .system(
                            size: 27,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Show details and venue information")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
    }

    // MARK: - Schedule

    private func scheduleCard(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeading("SCHEDULE")

            detailRow(
                title: "Date",
                value: show.date.formatted(
                    date: .long,
                    time: .omitted
                ),
                symbol: "calendar"
            )

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.7)

            detailRow(
                title: "Start time",
                value: show.date.formatted(
                    date: .omitted,
                    time: .shortened
                ),
                symbol: "clock"
            )

            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.7)

            detailRow(
                title: "Added to TourOps",
                value: show.createdAt.formatted(
                    date: .abbreviated,
                    time: .omitted
                ),
                symbol: "plus.circle"
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 7)
        .background {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
    }

    // MARK: - Location

    private func locationCard(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("VENUE")

            HStack(spacing: 13) {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .fill(Palette.surfaceRaised)
                .overlay {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(Palette.chipAccent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        show.venue.isEmpty
                            ? "Venue not set"
                            : show.venue
                    )
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        show.city.isEmpty
                            ? "City not set"
                            : show.city
                    )
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .fill(Palette.surface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .strokeBorder(
                Palette.hairline,
                lineWidth: 0.7
            )
        }
    }

    // MARK: - Shared details

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Palette.secondaryText)
            .padding(.bottom, 7)
    }

    private func detailRow(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.chipAccent)
                .frame(width: 23)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete Show", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .fill(Color.red.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 17,
                        style: .continuous
                    )
                    .strokeBorder(
                        Color.red.opacity(0.18),
                        lineWidth: 0.8
                    )
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Show Detail Preview")
}
