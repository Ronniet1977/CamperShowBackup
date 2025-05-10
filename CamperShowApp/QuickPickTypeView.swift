import SwiftUI

struct QuickPickTypeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: CamperViewModel
    @State private var currentIndex = 0
    @State private var showAllDoneAlert = false
    
    var body: some View {
        NavigationStack {
            if currentIndex < viewModel.missingTypeCampers.count {
                let camper = viewModel.missingTypeCampers[currentIndex]
                
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(camper.model)
                            .font(.title2)
                            .bold()
                        Text("VIN: \(camper.vin)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 10) {
                        HStack {
                            typeButton(title: "🛻 FW", type: "FW", color: Color.blue)
                            typeButton(title: "🚚 BP", type: "BP", color: Color.orange)
                        }
                        HStack {
                            typeButton(title: "🏠 Park", type: "Park", color: Color.green)
                            typeButton(title: "🚐 Drive", type: "Drive", color: Color.purple)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Quick Pick Type")
                .alert("✅ All campers classified!", isPresented: $showAllDoneAlert) {
                    Button("OK") {
                        dismiss()
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Text("✅ All campers classified!")
                        .font(.title)
                        .bold()
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
    
    private func typeButton(title: String, type: String, color: Color) -> some View {
        Button(action: {
            updateCamper(to: type)
        }) {
            Text(title)
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
    
    private func updateCamper(to newType: String) {
        let camper = viewModel.missingTypeCampers[currentIndex]
        viewModel.updateCamperType(camper: camper, newType: newType)
        
        // ✅ Remove it from missingTypeCampers list
        viewModel.missingTypeCampers.remove(at: currentIndex)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if viewModel.missingTypeCampers.isEmpty {
                CamperViewModel.saveCSVToDocuments(from: viewModel.campers)
                showAllDoneAlert = true
            } else {
                // ✅ Move to the next camper (do not reset to 0)
                if currentIndex >= viewModel.missingTypeCampers.count {
                    currentIndex = 0
                }
            }
        }
    }
}
