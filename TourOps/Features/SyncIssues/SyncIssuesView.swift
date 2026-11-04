//
//  SyncIssuesView.swift
//  TourOps
//
//  The sheet behind the "needs attention" pill. It lists every item with a
//  conflict or a failed change and offers the ways out: use the server's
//  version for a conflict, retry or discard for a failed change. The list
//  reads the existing sync queue and changes nothing by itself.
//

import SwiftUI
import SwiftData

struct SyncIssuesView: View {

    let teamRepository: TeamRepositoryProtocol
    let tourRepository: TourRepositoryProtocol
    let showRepository: ShowRepositoryProtocol

    @State private var viewModel: SyncIssuesViewModel
    @Query private var operations: [SyncOperationEntity]
    @Environment(\.dismiss) private var dismiss

    /// Names of the items that still exist on this device. A conflicted
    /// delete has none until it is resolved.
    @State private var names: [UUID: String] = [:]
    @State private var confirmation: Confirmation?
    @State private var showingError = false

    private enum Confirmation {
        case useServerVersion(SyncIssue)
        case discard(SyncIssue)
    }

    init(
        resolver: SyncConflictResolving,
        refreshSignal: DataRefreshSignal,
        teamRepository: TeamRepositoryProtocol,
        tourRepository: TourRepositoryProtocol,
        showRepository: ShowRepositoryProtocol
    ) {
        _viewModel = State(
            initialValue: SyncIssuesViewModel(
                resolver: resolver,
                refreshSignal: refreshSignal
            )
        )

        self.teamRepository = teamRepository
        self.tourRepository = tourRepository
        self.showRepository = showRepository
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if issues.isEmpty {
                    StatePanel(
                        symbol: "checkmark.circle",
                        title: "Everything is resolved",
                        message: "Nothing needs your attention right now."
                    )
                } else {
                    issueList
                }
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Needs attention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationIsPresented,
            titleVisibility: .visible,
            presenting: confirmation
        ) { item in
            switch item {
            case .useServerVersion(let issue):
                Button("Use Server Version", role: .destructive) {
                    Task {
                        _ = await viewModel.useServerVersion(for: issue)
                    }
                }
            case .discard(let issue):
                Button("Discard Change", role: .destructive) {
                    Task {
                        _ = await viewModel.discard(issue)
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: { item in
            switch item {
            case .useServerVersion(let issue):
                Text(issue.useServerVersionMessage(name: names[issue.entityID]))
            case .discard(let issue):
                Text(issue.discardMessage(name: names[issue.entityID]))
            }
        }
        .alert(
            "Couldn’t Resolve",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            showingError = message != nil
        }
        .task(id: issues.map(\.id)) {
            await loadNames()
        }
    }

    // MARK: - List

    private var issues: [SyncIssue] {
        SyncIssue.issues(
            from: operations.compactMap { $0.toDomain() }
        )
    }

    private var issueList: some View {
        List {
            Section {
                ForEach(issues) { issue in
                    row(for: issue)
                }
            } footer: {
                if issues.contains(where: { $0.kind == .failed }) {
                    Text(
                        "Retry helps if the problem was temporary, such as a "
                            + "poor connection. If the server rejected the "
                            + "data, it will fail again."
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(for issue: SyncIssue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(issue.title(name: names[issue.entityID]))
                .font(.headline)
                .foregroundStyle(Palette.primaryText)

            Text(issue.explanation)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)

            actions(for: issue)
                .disabled(viewModel.isWorking)
        }
        .padding(.vertical, 4)
        .listRowBackground(Palette.surface)
    }

    @ViewBuilder
    private func actions(for issue: SyncIssue) -> some View {
        switch issue.kind {
        case .conflict:
            Button("Use Server Version") {
                confirmation = .useServerVersion(issue)
            }
            .buttonStyle(.borderless)

        case .failed:
            HStack(spacing: 20) {
                Button("Retry") {
                    Task {
                        _ = await viewModel.retry(issue)
                    }
                }

                Button("Discard…", role: .destructive) {
                    confirmation = .discard(issue)
                }
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Confirmation

    private var confirmationTitle: String {
        switch confirmation {
        case .useServerVersion?:
            return "Use the server’s version?"
        case .discard?:
            return "Discard this change?"
        case nil:
            return ""
        }
    }

    private var confirmationIsPresented: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { isPresented in
                if !isPresented {
                    confirmation = nil
                }
            }
        )
    }

    // MARK: - Names

    private func loadNames() async {
        var loaded: [UUID: String] = [:]

        if let teams = try? await teamRepository.fetchTeams() {
            for team in teams {
                loaded[team.id] = team.name
            }
        }

        if let tours = try? await tourRepository.fetchTours() {
            for tour in tours {
                loaded[tour.id] = tour.name
            }
        }

        if let shows = try? await showRepository.fetchShows() {
            for show in shows {
                loaded[show.id] = show.name
            }
        }

        names = loaded
    }
}
