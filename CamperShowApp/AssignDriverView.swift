import SwiftUI

struct AssignDriverView: View {
    var camper: Camper
    var driverList: [String]
    var driverCounts: [String: Int]
    var onSave: (String) -> Void
    
    @State private var selectedDriver: String = ""
    @State private var customDriver: String = ""
    @State private var useCustomDriver = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                if useCustomDriver {
                    Section(header: Text("New Driver Name")) {
                        TextField("Enter driver name", text: $customDriver)
                            .autocapitalization(.words)
                    }
                } else {
                    Section(header: Text("Select a Driver")) {
                        Picker("Driver", selection: $selectedDriver) {
                            ForEach(driverList, id: \.self) { driver in
                                let count = driverCounts[driver] ?? 0
                                Text("\(driver) (\(count))").tag(driver)
                            }
                        }
                    }
                }
                
                Section {
                    Button(useCustomDriver ? "Choose from List" : "Add Custom Driver") {
                        useCustomDriver.toggle()
                        if !useCustomDriver {
                            customDriver = ""
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        onSave("")
                        dismiss()
                    } label: {
                        Label("Unassign Camper", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Assign Driver")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalDriver = useCustomDriver ? customDriver.trimmingCharacters(in: .whitespaces) : selectedDriver
                        if !finalDriver.isEmpty {
                            onSave(finalDriver)
                            dismiss()
                        }
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

