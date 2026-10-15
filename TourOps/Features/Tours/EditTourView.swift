//
//  EditTourView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct EditTourView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: TourListViewModel
    private let tour: Tour

    @State private var draft: TourDraft
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    init(
        viewModel: TourListViewModel,
        tour: Tour
    ) {
        self.viewModel = viewModel
        self.tour = tour

        _draft = State(initialValue: TourDraft(tour: tour))
    }

    var body: some View {
        FormSheet(
            title: "Edit tour",
            saveTitle: "Save changes",
            canSave: draft.isValid(),
            isSaving: gate.isRunning,
            onCancel: { dismiss() },
            onSave: submit
        ) {
            TourFormContent(draft: $draft)
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Update Tour",
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
            let updatedTour = draft.updatedTour(from: tour)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.updateTour(updatedTour)
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
#Preview("Populated, light") {
    EditTourView(
        viewModel: TourListViewModel(
            repository: PreviewTourRepository(tours: [PreviewData.upcomingTour])
        ),
        tour: PreviewData.upcomingTour
    )
    .preferredColorScheme(.light)
}

#Preview("Populated, dark") {
    EditTourView(
        viewModel: TourListViewModel(
            repository: PreviewTourRepository(tours: [PreviewData.upcomingTour])
        ),
        tour: PreviewData.upcomingTour
    )
    .preferredColorScheme(.dark)
}

#Preview("Long text, large type") {
    EditTourView(
        viewModel: TourListViewModel(
            repository: PreviewTourRepository(tours: [PreviewData.longTour])
        ),
        tour: PreviewData.longTour
    )
    .dynamicTypeSize(.accessibility2)
}
#endif
