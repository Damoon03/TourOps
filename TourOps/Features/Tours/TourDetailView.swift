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
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditTour = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    
    private var tour: Tour? {
        viewModel.tours.first { $0.id == tourID }
    }
    
    var body: some View {
        Group {
            if let tour {
                Form {
                    Section("Tour Information") {
                        LabeledContent("Name", value: tour.name)
                        
                        LabeledContent(
                            "Start Date",
                            value: tour.startDate.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                        
                        LabeledContent(
                            "End Date",
                            value: tour.endDate.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                    }
                    
                    Section {
                        Button("Delete Tour", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
                .navigationTitle(tour.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            showingEditTour = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditTour) {
                    EditTourView(
                        viewModel: viewModel,
                        tour: tour
                    )
                }
            } else {
                ContentUnavailableView(
                    "Tour Not Found",
                    systemImage: "music.note.list"
                )
            }
        }
        .confirmationDialog(
            "Delete Tour?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let tour else { return }
                
                Task {
                    let success = await viewModel.deleteTour(tour)
                    
                    if success {
                        dismiss()
                    } else {
                        showingError = true
                    }
                }
            }
            
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This action cannot be undone.")
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
