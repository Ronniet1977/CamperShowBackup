import SwiftUI

struct DriverMainView: View {
    @ObservedObject var viewModel: CamperViewModel
    @AppStorage("currentDriverName") var currentDriverName: String = ""

    @State private var selectedCamperForPhoto: Camper?
    @State private var image: UIImage?
    @State private var showImagePicker = false
    @State private var showSourcePicker = false
    @State private var selectedSourceType: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        NavigationStack {
            VStack {
                if currentDriverName.isEmpty {
                    Text("🚨 No driver name set")
                        .font(.title2)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text("Welcome, \(currentDriverName)")
                        .font(.largeTitle.bold())
                        .padding(.top)

                    List {
                        let assignedCampers = viewModel.campers.filter { $0.assignedTo == currentDriverName }

                        ForEach(assignedCampers, id: \.id) { camper in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(camper.model) • \(camper.vin.suffix(5))")
                                    .font(.headline)

                                Text("📍 \(camper.location)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let photo = viewModel.camperPhotos[camper.id] {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 100)
                                        .cornerRadius(8)
                                        .padding(.top, 4)
                                }
                                // Status info
                                if let date1 = camper.date1, !date1.isEmpty {
                                    Text("🛻 Picked Up: \(date1)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                if let date2 = camper.date2, !date2.isEmpty {
                                    Text("✅ Delivered: \(date2)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }

                                // Buttons
                                HStack(spacing: 4) {
                                    // ✅ Picked Up
                                    Button {
                                        viewModel.updateCamperStatus(camper: camper, statusField: .status1)
                                    } label: {
                                        Label("Picked Up", systemImage: "checkmark.circle")
                                    }
                                    .disabled(!(camper.status1 ?? "").isEmpty)
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    .font(.caption2)

                                    // 📸 Take Photo
                                    Button {
                                        selectedCamperForPhoto = camper
                                        showSourcePicker = true
                                    } label: {
                                        Label("Photo", systemImage: "camera")
                                    }
                                    .disabled(!(camper.status2 ?? "").isEmpty)
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                    .font(.caption2)

                                    // 📦 Delivered
                                    Button {
                                        viewModel.updateCamperStatus(camper: camper, statusField: .status2)
                                    } label: {
                                        Label("Drop Off", systemImage: "shippingbox")
                                    }
                                    .disabled((camper.status1 ?? "").isEmpty || !(camper.status2 ?? "").isEmpty)
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .font(.caption2)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Campers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        viewModel.logout()
                        currentDriverName = ""
                    }
                    .foregroundColor(.red)
                }
            }

            // ✅ Confirmation Dialog to choose source
            .confirmationDialog("Select Image Source", isPresented: $showSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") {
                        selectedSourceType = .camera
                        showImagePicker = true
                    }
                }
                Button("Photo Library") {
                    selectedSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }

            // ✅ Image Picker Sheet
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: selectedSourceType, selectedImage: $image)
                    .onDisappear {
                        guard let original = selectedCamperForPhoto, let image = image else { return }
                        
                        // Save image using ViewModel helper
                        viewModel.savePhoto(image, for: original)
                        viewModel.camperPhotos[original.id] = image
                        
                        print("📸 Saved photo for \(original.vin)")
                    }
            
            }
        }
    }
}
