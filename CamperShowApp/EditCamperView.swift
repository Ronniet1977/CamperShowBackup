import SwiftUI
import Foundation

struct EditCamperView: View {
    @Binding var camper: Camper
    var onDone: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model")) {
                    TextField("Model", text: $camper.model)
                }
                Section(header: Text("VIN")) {
                    TextField("VIN", text: $camper.vin)
                }
                Section(header: Text("Location")) {
                    TextField("Location", text: $camper.location)
                }
            }
            .navigationTitle("Edit Camper")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}
