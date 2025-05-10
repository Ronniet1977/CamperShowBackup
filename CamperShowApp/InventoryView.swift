import SwiftUI

import UniformTypeIdentifiers
import Foundation

// 👇 Helper for Save To Files (CSV export)
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var fileURL: URL?
    
    init(url: URL?) {
        self.fileURL = url
    }
    
    init(configuration: ReadConfiguration) throws {
        self.fileURL = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

// 👇 Helper for selecting camper type (same as before)
struct TypePickerSheet: View {
    let camper: Camper
    var onTypeSelected: (Camper, String) -> Void
    
    var body: some View {
        List {
            Button("🛻 Fifth Wheel") {
                onTypeSelected(camper, "FW")
            }
            Button("🚚 Bumper Pull") {
                onTypeSelected(camper, "BP")
            }
            Button("🏠 Park Unit") {
                onTypeSelected(camper, "Park")
            }
            Button("🚐 Drivable") {
                onTypeSelected(camper, "Drive")
            }
            Button("❓ Unknown") {
                onTypeSelected(camper, "Unknown")
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .font(.caption)
        }
        .navigationTitle("Select Camper Type")
    }
}

struct InventoryView: View {
    @ObservedObject var viewModel: CamperViewModel
    @State private var camperToClassify: Camper?
    @State private var selectedFilter = "All"
    @State private var showOnlySelected = false
    @State private var showOnlyUnselected = false
    @State private var searchVIN = ""
    @State private var saveTimer: Timer? = nil
    @State private var isSaving = false
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var showSavedBanner = false
    
    
    let filters = ["All", "FW", "BP", "Park", "Drive", "Unknown"]
    
    var filteredCampers: [Camper] {
        var baseList = viewModel.campers
        
        if selectedFilter != "All" {
            baseList = baseList.filter { camper in
                if selectedFilter == "Unknown" {
                    return camper.type == nil || camper.type == "Unknown"
                } else {
                    return camper.type == selectedFilter
                }
            }
        }
        
        if showOnlyUnselected {
            baseList = baseList.filter { ($0.isSelected ?? false) == false }
        }
        
        if !searchVIN.isEmpty {
            baseList = baseList.filter { $0.vin.localizedCaseInsensitiveContains(searchVIN) }
        }
        
        return baseList
    }
    
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(filters, id: \.self) { filter in
                        Text(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Toggle("Show Only Unselected", isOn: $showOnlyUnselected)
                    .padding(.horizontal)
                
                TextField("Search VIN...", text: $searchVIN)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                List(filteredCampers) { camper in
                    HStack {
                        Button(action: {
                            if let index = viewModel.campers.firstIndex(where: { $0.id == camper.id }) {
                                viewModel.campers[index].isSelected?.toggle()
                                
                                saveTimer?.invalidate()
                                saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                                    isSaving = true
                                    CamperViewModel.saveCSVToDocuments(from: viewModel.campers)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        isSaving = false
                                    }
                                }
                            }
                        }) {
                            Image(systemName: (camper.isSelected ?? false) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor((camper.isSelected ?? false) ? .green : .gray)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            let vin = camper.vin.trimmingCharacters(in: .whitespacesAndNewlines)
                            let vinStripped = vin.uppercased().hasSuffix("F") || vin.uppercased().hasSuffix("D") ? String(vin.dropLast()) : vin
                            let displayVIN = String(vinStripped.suffix(5))
                            
                            Text("\(camper.model) • \(displayVIN)")
                                .font(.headline)
                            
                            Text("📍 \(camper.location)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let type = camper.type, type != "Unknown" {
                                Text("🛠️ Type: \(type)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Text("🛠️ Type: Unknown")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .italic()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        camperToClassify = camper
                    }
                }
                
                if isSaving {
                    Text("Saving...")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            .overlay(
                Group {
                    if showSavedBanner {
                        VStack {
                            Spacer()
                            Text("✅ Saved to Files!")
                                .font(.caption)
                                .padding(8)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.bottom, 40)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.5), value: showSavedBanner)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showSavedBanner = false
                            }
                        }
                    }
                }
            )
            .navigationTitle("Inventory Manager")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if let inventoryURL = CamperViewModel.generateInventoryCSV(from: viewModel.campers) {
                            DropboxUploader.shared.upload(
                                localURL: inventoryURL,
                                to: "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Inventory/\(inventoryURL.lastPathComponent)"
                            )
                        } else {
                            print("❌ Could not generate Inventory CSV")
                        }
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save").font(.caption2)
                        }
                    }

                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: CSVDocument(url: exportURL),
                contentType: .commaSeparatedText,
                defaultFilename: exportURL?.lastPathComponent ?? "Inventory Export"
            ) { result in
                switch result {
                case .success:
                    print("✅ Inventory file saved to Files")
                case .failure(let error):
                    print("❌ Inventory export failed: \(error.localizedDescription)")
                }
            }

            .sheet(item: $camperToClassify) { camper in
                TypePickerSheet(
                    camper: camper,
                    onTypeSelected: { updatedCamper, newType in
                        viewModel.updateCamperType(camper: updatedCamper, newType: newType)
                        camperToClassify = nil
                    }
                )
            }
        }
    }
}
