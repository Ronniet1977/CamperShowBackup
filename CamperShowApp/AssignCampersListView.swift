import SwiftUI

struct AssignCampersListView: View {
    @ObservedObject var viewModel: CamperViewModel
    
    var body: some View {
        if viewModel.campers.isEmpty {
            Text("No campers loaded. Please import first.")
                .padding()
        } else {
            List {
                ForEach(viewModel.campers.indices, id: \.self) { i in
                    let camper = viewModel.campers[i]
                    let displayVIN = String(camper.vin.suffix(5))
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(camper.model) • \(displayVIN)")
                                .font(.headline)
                            
                            Text("📍 \(camper.location)")
                                .font(.subheadline)
                            
                            Text(camper.assignedTo?.isEmpty ?? true
                                 ? "❌ Unassigned"
                                 : "🧑‍✈️ Driver: \(camper.assignedTo!)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button("Unassign") {
                                viewModel.campers[i].assignedTo = nil
                            }
                            ForEach(viewModel.driverList, id: \.self) { driver in
                                Button(driver) {
                                    viewModel.campers[i].assignedTo = driver
                                }
                            }
                        } label: {
                            Text(viewModel.campers[i].assignedTo ?? "Assign")
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
