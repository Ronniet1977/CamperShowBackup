import SwiftUI

struct RoleSelectorView: View {
    @ObservedObject var viewModel: CamperViewModel
    @AppStorage("currentDriverName") var currentDriverName: String = ""
    @State private var driverNameInput: String = ""
    @State private var showPasswordAlert = false
    @State private var showingPasswordPrompt = false
    @State private var enteredPassword = ""
    @State private var showWrongPasswordAlert = false


    private func promptForAdminPassword() {
        showPasswordAlert = true
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Select Your Role")
                .font(.title2)
                .bold()

            Button("🛠 Admin") {
                showingPasswordPrompt = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            VStack(spacing: 10) {
                TextField("Enter Driver Name", text: $driverNameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .alert("Enter Admin Password", isPresented: $showingPasswordPrompt) {
                        SecureField("Password", text: $enteredPassword)
                        Button("Login") {
                            if viewModel.verifyAdminPassword(enteredPassword) {
                                viewModel.userRole = .admin
                                viewModel.saveUserRole()
                            } else {
                                showWrongPasswordAlert = true
                            }
                            enteredPassword = ""
                        }
                        Button("Cancel", role: .cancel) {
                            enteredPassword = ""
                        }
                    } message: {
                        Text("This section is for admins only.")
                    }
                    .alert("Wrong Password", isPresented: $showWrongPasswordAlert) {
                        Button("OK", role: .cancel) { }
                    }


                Button("🚛 Driver") {
                    let trimmed = driverNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    currentDriverName = trimmed
                    viewModel.userRole = .driver
                    viewModel.saveUserRole()

                    if !viewModel.driverList.contains(trimmed) {
                        viewModel.driverList.append(trimmed)
                        viewModel.saveDriverList()
                    }
                }
                .disabled(driverNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.bordered)
                .font(.title3)
            }
        }
        .padding()
    }
}
