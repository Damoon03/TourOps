//
//  EditTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

/// Presents its own navigation stack, like the Create and Edit screens for
/// tours and shows, so callers just present it as a sheet.
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
        NavigationStack {
            ScreenScroll(topPadding: 24, spacing: 20) {
                TeamFormContent(
                    draft: $draft,
                    isImageBusy: $isImageBusy,
                    title: "Edit artist details",
                    subtitle: "Update the name, location or artwork."
                )
            }
            .navigationTitle("Edit Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(gate.isRunning)
                }

                ToolbarItem(placement: .confirmationAction) {
                    SubmitButton(
                        title: "Save",
                        isEnabled: canSubmit,
                        isSubmitting: gate.isRunning,
                        action: submit
                    )
                }
            }
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
#Preview("With image") {
    EditTeamView(
        team: PreviewData.teamWithImage,
        viewModel: TeamListViewModel(
            repository: PreviewTeamRepository(teams: [PreviewData.teamWithImage])
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("No image") {
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
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
#endif
