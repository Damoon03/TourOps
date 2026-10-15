//
//  CreateTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/3/1405 AP.
//

import SwiftUI

struct CreateTeamView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: TeamListViewModel

    @State private var draft = TeamDraft()

    /// Fixed for the lifetime of the form, so a second submission could never
    /// store a second team.
    @State private var teamID = UUID()

    @State private var isImageBusy = false
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    private var canSubmit: Bool {
        draft.isValid && !isImageBusy
    }

    var body: some View {
        FormSheet(
            title: "New team",
            saveTitle: "Save team",
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
            "Couldn’t Create Team",
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
            let team = draft.newTeam(id: teamID)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.createTeam(team)
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
#Preview("Empty, light") {
    CreateTeamView(
        viewModel: TeamListViewModel(repository: PreviewTeamRepository())
    )
    .preferredColorScheme(.light)
}

#Preview("Empty, dark") {
    CreateTeamView(
        viewModel: TeamListViewModel(repository: PreviewTeamRepository())
    )
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
    CreateTeamView(
        viewModel: TeamListViewModel(repository: PreviewTeamRepository())
    )
    .dynamicTypeSize(.accessibility3)
}
#endif
