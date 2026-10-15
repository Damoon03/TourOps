//
//  EditTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

/// Draws its own bottom-sheet layout (see `FormSheet`), like the Create and
/// Edit screens for tours and shows, so callers just present it as a sheet.
struct EditTeamView: View {

    @Environment(\.dismiss) private var dismiss

    private let team: Team
    let viewModel: TeamListViewModel

    @State private var draft: TeamDraft
    @State private var isImageBusy = false
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    init(
        team: Team,
        viewModel: TeamListViewModel
    ) {
        self.team = team
        self.viewModel = viewModel

        _draft = State(initialValue: TeamDraft(team: team))
    }

    private var canSubmit: Bool {
        draft.isValid && !isImageBusy
    }

    var body: some View {
        FormSheet(
            title: "Edit team",
            saveTitle: "Save changes",
            canSave: canSubmit,
            isSaving: gate.isRunning,
            onCancel: { dismiss() },
            onSave: submit
        ) {
            TeamFormContent(
                draft: $draft,
                isImageBusy: $isImageBusy
            )
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Update Team",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }

    private func submit() {
        guard
            !gate.isRunning,
            !isImageBusy,
            let updatedTeam = draft.updatedTeam(from: team)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.updateTeam(updatedTeam)
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
}

#if DEBUG
#Preview("With image, light") {
    EditTeamView(
        team: PreviewData.teamWithImage,
        viewModel: TeamListViewModel(
            repository: PreviewTeamRepository(teams: [PreviewData.teamWithImage])
        )
    )
    .preferredColorScheme(.light)
}

#Preview("No image, dark") {
    EditTeamView(
        team: PreviewData.team,
        viewModel: TeamListViewModel(
            repository: PreviewTeamRepository(teams: [PreviewData.team])
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Long text, large type") {
    EditTeamView(
        team: PreviewData.longTeam,
        viewModel: TeamListViewModel(
            repository: PreviewTeamRepository(teams: [PreviewData.longTeam])
        )
    )
    .dynamicTypeSize(.accessibility2)
}
#endif
