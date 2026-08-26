//
//  CreateTourView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct CreateTourView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    let viewModel: TourListViewModel
    let teamID: UUID
    
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tour Information") {
                    TextField("Name", text: $name)
                    
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("New Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let tour = Tour(
                                id: UUID(),
                                teamID: teamID,
                                name: name,
                                startDate: startDate,
                                endDate: endDate,
                                createdAt: Date()
                            )
                            
                            let success = await viewModel.createTour(tour)
                            
                            if success {
                                dismiss()
                            } else {
                                showingError = true
                            }
                        }
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || endDate < startDate
                    )
                }
            }
            .alert(
                "Error",
                isPresented: $showingError
            ) {
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
            }
        }
    }
}
