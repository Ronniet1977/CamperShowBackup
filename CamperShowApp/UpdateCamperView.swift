import SwiftUI

struct UpdateCamperView: View {
    var camper: Camper
    var driverList: [String]
    var onSave: (String) -> Void
    
    @State private var selectedDriver: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Picker("Assign to Driver", selection: $selectedDriver) {
                    ForEach(driverList, id: \.self) { driver in
                        Text(driver)
                    }
                }
            }
            .navigationTitle("Assign Driver")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedDriver)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedDriver = camper.assignedTo ?? driverList.first ?? ""
            }
        }
    }
}
