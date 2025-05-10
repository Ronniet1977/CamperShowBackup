import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct ImportCampersView: View {
    @ObservedObject var viewModel: CamperViewModel
    @State private var selectedCamper: Camper?
    @State private var camperToEdit: Camper?
    @State private var searchText = ""
    @State private var showOnlyUnassigned = false
    @State private var sortByDriver = false
    @State private var sortByLocation = false
    @State private var showingImporter = false
    @State private var showEndShowAlert = false
    @State private var showEndShowSheet = false
    @State private var showName = ""

    
    // File Export
    @State private var exportURLForEndShow: URL?
    @State private var showExporterForEndShow = false

    
    
    enum ExportMode {
        case saveToFiles
        case endShow
    }
    
    @State private var exportMode: ExportMode = .saveToFiles
    @State private var exportURL: URL?
    @State private var showExporter = false
    
    
    
    struct CSVDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.commaSeparatedText] }
        var fileURL: URL?
        
        init(url: URL?) { self.fileURL = url }
        init(configuration: ReadConfiguration) throws { self.fileURL = nil }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
            let data = try Data(contentsOf: url)
            return FileWrapper(regularFileWithContents: data)
        }
    }
    
    var filteredCampers: [Camper] {
        var baseList = showOnlyUnassigned
        ? viewModel.campers.filter { ($0.assignedTo ?? "").isEmpty }
        : viewModel.campers
        
        if sortByDriver {
            baseList.sort { ($0.assignedTo ?? "").localizedCaseInsensitiveCompare($1.assignedTo ?? "") == .orderedAscending }
        } else if sortByLocation {
            baseList.sort { $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending }
        }
        
        if !searchText.isEmpty {
            baseList = baseList.filter {
                $0.vin.localizedCaseInsensitiveContains(searchText) ||
                $0.model.localizedCaseInsensitiveContains(searchText) ||
                ($0.assignedTo ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return baseList
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                headerToggles
                searchField
                camperList
            }
            .navigationTitle("Import Campers")
            .toolbar {
                toolbarButtons
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.commaSeparatedText],
                          allowsMultipleSelection: false,
                          onCompletion: handleImport)
            .sheet(item: $selectedCamper) { camper in
                AssignDriverView(
                    camper: camper,
                    driverList: viewModel.driverList,
                    driverCounts: viewModel.driverAssignmentCounts()
                ) { selectedDriver in
                    if !viewModel.driverList.contains(selectedDriver) {
                        viewModel.driverList.append(selectedDriver)
                        viewModel.saveDriverList()
                    }
                    viewModel.assignDriver(camper: camper, to: selectedDriver)
                }
            }
            .sheet(item: $camperToEdit) { camper in
                EditCamperView(
                    camper: Binding(
                        get: {
                            viewModel.campers.first(where: { $0.id == camper.id }) ?? camper
                        },
                        set: { updated in
                            if let index = viewModel.campers.firstIndex(where: { $0.id == camper.id }) {
                                viewModel.campers[index] = updated
                            }
                        }
                    ),
                    onDone: { camperToEdit = nil }
                )
            }
            .sheet(isPresented: $showEndShowSheet) {
                VStack(spacing: 20) {
                    Text("End Show").font(.title2).bold()
                    TextField("Enter Show Name", text: $showName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    Button("Confirm End Show", role: .destructive) {
                        let safeName = showName.isEmpty ? "UnnamedShow" : showName.replacingOccurrences(of: "/", with: "-")
                        let oldPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/Camper Show Log.csv"
                        let archivePath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Archived Shows/\(safeName).csv"

                        // Save campers to Dropbox first so the file exists at oldPath
                        if let url = CamperViewModel.generateCSVFile(from: viewModel.campers) {
                            DropboxUploader.shared.upload(localURL: url, to: oldPath)

                            // After successful upload, move it to archive
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                DropboxUploader.shared.moveFile(from: oldPath, to: archivePath)
                                // Now clear campers
                                viewModel.campers.removeAll()
                                CamperViewModel.saveCSVToDocuments(from: [])
                                print("✅ End show completed: campers cleared")

                                showEndShowSheet = false
                            }
                        } else {
                            print("❌ Failed to generate CSV")
                        }
                    }

                }
                .padding()
            }
        }
        .onAppear {
            refreshFromDropbox()
        }
        .refreshable {
            refreshFromDropbox()
        }
    }
    
    
    private var toolbarButtons: some ToolbarContent {
        Group {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    CamperViewModel.saveCSVToDocuments(from: viewModel.campers)
                } label: {
                    VStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save").font(.caption2)
                    }
                }
                
                Button {
                    exportMode = .saveToFiles
                    guard let url = CamperViewModel.generateCSVFile(from: viewModel.campers) else {
                        print("❌ Failed to generate CSV file")
                        return
                    }
                    exportURL = url
                    showExporter = true
                } label: {
                    VStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Save To Files").font(.caption2)
                    }
                }
                
                
                
                Button {
                    showingImporter = true
                } label: {
                    VStack {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Import").font(.caption2)
                    }
                }
                Button {
                    showEndShowSheet = true
                } label: {
                    VStack {
                        Image(systemName: "flag.checkered")
                        Text("End Show").font(.caption2)
                    }
                }
            }
            
            // ✅ Log Out button on the right
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Log Out") {
                    viewModel.logout()
                }
            }
        }
    }
    // MARK: - Private Subviews
    
    private var headerToggles: some View {
        VStack {
            Toggle("Show Only Unassigned", isOn: $showOnlyUnassigned).padding(.horizontal)
            Toggle("Sort by Location", isOn: $sortByLocation)
                .padding(.horizontal)
                .onChange(of: sortByLocation) { if $0 { sortByDriver = false } }
            
            Toggle("Sort by Driver", isOn: $sortByDriver)
                .padding(.horizontal)
                .onChange(of: sortByDriver) { if $0 { sortByLocation = false } }
        }
    }
    
    private var searchField: some View {
        TextField("Search by VIN, Model, or Driver", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
    }
    
    private var camperList: some View {
        List(filteredCampers) { camper in
            CamperRowView(
                camper: camper,
                viewModel: viewModel,
                onEdit: { camperToEdit = camper },
                onTap: { selectedCamper = camper }
            )
        }
    }
    
    
    
    
    
    // MARK: - File Handlers
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let selectedFile = urls.first {
                viewModel.importCSV(from: selectedFile)
            }
        case .failure(let error):
            print("❌ Import failed: \(error.localizedDescription)")
        }
    }
    
    private func handleExportSave(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            print("❌ Save to Files failed: \(error.localizedDescription)")
        } else {
            print("✅ Save to Files successful")
        }
    }
    
    private func handleExportEndShow(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            print("✅ End Show export successful")
            DispatchQueue.main.async {
                viewModel.campers.removeAll()
                CamperViewModel.saveCSVToDocuments(from: [])
            }
        case .failure(let error):
            print("❌ End Show export failed: \(error.localizedDescription)")
        }
    }
    
    private func refreshFromDropbox() {
        let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/Camper Show Log.csv"
        DropboxDownloader.shared.download(from: dropboxPath) { downloadedURL in
            DispatchQueue.main.async {
                if let url = downloadedURL {
                    viewModel.loadCampersFromCSV(url: url)
                } else {
                    print("❌ Failed to download and reload campers")
                }
            }
        }
    }

    
    struct CamperRowView: View {
        let camper: Camper
        @ObservedObject var viewModel: CamperViewModel
        var onEdit: () -> Void
        var onTap: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Top Header
                HStack {
                    let vin = camper.vin.trimmingCharacters(in: .whitespacesAndNewlines)
                    let vinStripped = vin.uppercased().hasSuffix("F") ? String(vin.dropLast()) : vin
                    let displayVIN = String(vinStripped.suffix(5))
                    let typeTag = camper.type ?? ""
                    let formattedTag = typeTag.isEmpty ? "" : "(\(typeTag))"
                    
                    Text("\(camper.model) \(formattedTag) • \(displayVIN)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { onEdit() }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                }
                
                // Location & Driver
                Text("📍 \(camper.location) 👤 \(camper.assignedTo ?? "Unassigned")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Status Dates
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
                
                // ✅ Show photo if saved
                if let photo = viewModel.camperPhotos[camper.id] {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .cornerRadius(8)
                        .padding(.top, 4)
                }
                
                // Status Buttons
                HStack {
                    Button {
                        viewModel.updateCamperStatus(camper: camper, statusField: .status1)
                    } label: {
                        Label(
                            camper.status1?.isEmpty == false ? "Picked Up ✅" : "Picked Up",
                            systemImage: camper.status1?.isEmpty == false ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    .disabled(!(camper.status1 ?? "").isEmpty)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        viewModel.updateCamperStatus(camper: camper, statusField: .status2)
                    } label: {
                        Label(
                            camper.status2?.isEmpty == false ? "Delivered ✅" : "Delivered",
                            systemImage: camper.status2?.isEmpty == false ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    .disabled((camper.status1 ?? "").isEmpty || !(camper.status2 ?? "").isEmpty)
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
            .onTapGesture { onTap() }
        }
    }
}
