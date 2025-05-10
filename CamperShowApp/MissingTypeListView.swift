import SwiftUI

struct MissingTypeListView: View {
    @ObservedObject var viewModel: CamperViewModel
    @State private var selectedCamper: Camper? = nil
    @State private var showAllDoneAlert = false
    
    var body: some View {
        NavigationStack {
            List(viewModel.missingTypeCampers) { camper in
                VStack(alignment: .leading) {
                    Text(camper.model)
                        .font(.headline)
                    Text("VIN: \(camper.vin)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .onTapGesture {
                    selectedCamper = camper
                }
            }
            .onAppear {
                if viewModel.missingTypeCampers.isEmpty {
                    // Trigger alert (if not already)
                    showAllDoneAlert = true
                }
            }
            .navigationTitle("Quick Classify")
            .sheet(item: $selectedCamper) { _ in
                QuickPickTypeView(viewModel: viewModel)
            }
            .alert("✅ All Campers Classified!", isPresented: $showAllDoneAlert) {
                Button("OK") {
                    // Fully close the Quick Classify sheet
                    selectedCamper = nil
                    viewModel.showQuickClassify = false
                }
            }
        }
    }
}
