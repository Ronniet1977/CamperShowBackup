import SwiftUI
import UniformTypeIdentifiers

// ✅ JSONDocument for .fileExporter / .fileImporter
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var fileURL: URL?

    init(url: URL?) { self.fileURL = url }
    init(configuration: ReadConfiguration) throws { self.fileURL = nil }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct UnifiedDriverEditorView: View {
    @ObservedObject var viewModel: CamperViewModel
    @State private var showBumperPull = false
    @State private var newDriverName = ""
    @State private var exportUnifiedURL: URL?
    @State private var showExportUnified = false
    @State private var showImportUnified = false

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Driver Type", selection: $showBumperPull) {
                    Text("Fifth Wheel").tag(false)
                    Text("Bumper Pull").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    ForEach(currentDriverList, id: \.self) { driver in
                        HStack {
                            Text(driver)
                            Spacer()
                            if viewModel.bumperPullDrivers.contains(driver) {
                                Text("BP").foregroundColor(.orange)
                            } else {
                                Text("FW").foregroundColor(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.removeDriver(driver, isBumperPull: viewModel.bumperPullDrivers.contains(driver))
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                toggleDriverType(driver)
                            } label: {
                                Label("Toggle Role", systemImage: "arrow.2.squarepath")
                            }
                            .tint(.gray)
                        }
                    }
                }

                HStack {
                    TextField("New Driver Name", text: $newDriverName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addDriver()
                    }
                    .disabled(newDriverName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                Button {
                    viewModel.saveDriverList()
                    viewModel.saveUnifiedDriverList()
                    viewModel.saveBumperPullDrivers()
                    viewModel.saveUnifiedDriverList()
                } label: {
                    Label("Save Drivers", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Edit Drivers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("📥 Import All Drivers") {
                            showImportUnified = true
                        }
                        
                        Divider() // optional visual separator
                        
                        Button("🗑 Clear All Drivers", role: .destructive) {
                            viewModel.driverList.removeAll()
                            viewModel.bumperPullDrivers.removeAll()
                            viewModel.saveDriverList()
                            viewModel.saveBumperPullDrivers()
                        }
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export").font(.caption2)
                        }
                    }
                }
            }
            // ✅ Export JSON
            .fileExporter(
                isPresented: $showExportUnified,
                document: JSONDocument(url: exportUnifiedURL),
                contentType: .json,
                defaultFilename: "AllDrivers"
            ) { result in
                if case .success(let url) = result {
                    print("✅ Drivers exported to \(url.lastPathComponent)")
                }
            }

            // ✅ Import JSON
            .fileImporter(
                isPresented: $showImportUnified,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    viewModel.importUnifiedDriverList(from: url)
                }
            }
        }
    }

    private var currentDriverList: [String] {
        showBumperPull
            ? viewModel.bumperPullDrivers
            : viewModel.driverList.filter { !viewModel.bumperPullDrivers.contains($0) }
    }

    private func addDriver() {
        let trimmed = newDriverName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            viewModel.addDriver(trimmed, isBumperPull: showBumperPull)
            newDriverName = ""
        }
    }

    private func toggleDriverType(_ driver: String) {
        if viewModel.bumperPullDrivers.contains(driver) {
            viewModel.bumperPullDrivers.removeAll { $0 == driver }
        } else {
            viewModel.bumperPullDrivers.append(driver)
        }
        viewModel.saveBumperPullDrivers()
    }
}
