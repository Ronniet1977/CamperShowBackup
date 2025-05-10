import SwiftUI

struct AssignCampersView: View {
    @ObservedObject var viewModel: CamperViewModel
    @State private var showExport = false
    @State private var showEditor = false
    @State private var showShareSheet = false
    @State private var showDriverTotals = false
    @State private var showMissingTypeList = false
    @State private var shareMessage = ""

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.campers.isEmpty {
                    Text("No campers loaded. Please import first.")
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.campers.indices, id: \.self) { i in
                            let camper = viewModel.campers[i]
                            Group {
                                let vin = camper.vin.trimmingCharacters(in: .whitespacesAndNewlines)
                                let vinStripped = vin.uppercased().hasSuffix("F") ? String(vin.dropLast()) : vin
                                let displayVIN = String(vinStripped.suffix(5))
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(camper.model) \(camper.displayTypeTag) \(displayVIN)")
                                            .font(.headline)
                                        
                                        Text("📍 Location: \(camper.location)")
                                            .font(.subheadline)
                                        
                                        Text(
                                            camper.assignedTo?.isEmpty == false
                                            ? "👤 Driver: \(camper.assignedTo!)"
                                            : "❌ Unassigned"
                                        )
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Campers")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu {
                        Button("Assign All (Round Robin)") {
                            viewModel.assignCampersRoundRobin()

                            if let yourCSVURL = CamperViewModel.generateCSVFile(from: viewModel.campers) {
                                let filename = yourCSVURL.lastPathComponent
                                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(filename)"
                                DropboxUploader.shared.upload(localURL: yourCSVURL, to: dropboxPath)
                            }
                        }
                        
                        Button("Unassign All") {
                            viewModel.unassignAllUnpickedCampers()
                        }
                    } label: {
                        VStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Manage").font(.caption2)
                        }
                    }
                    
                    Button {
                        showEditor = true
                    } label: {
                        VStack {
                            Image(systemName: "person.3")
                            Text("Drivers").font(.caption2)
                        }
                    }
                    
                    Button {
                        showExport = true
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export").font(.caption2)
                        }
                    }
                    
                    Button {
                        shareMessage = viewModel.generateGroupedDriverSummary()
                        showShareSheet = true
                    } label: {
                        VStack {
                            Image(systemName: "message")
                            Text("Send Text").font(.caption2)
                        }
                    }
                    
                    Button {
                        showDriverTotals = true
                    } label: {
                        VStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Totals").font(.caption2)
                        }
                    }
                }
            }
            .alert("⚠️ Missing Camper Type", isPresented: $viewModel.showMissingTypeAlert) {
                Button("Quick Classify") {
                    showMissingTypeList = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("There are \(viewModel.missingTypeCount) camper(s) missing a type.\n\nPlease classify them first!")
            }
            .sheet(isPresented: Binding(
                get: {
                    showExport || showEditor || showShareSheet || showDriverTotals || showMissingTypeList || viewModel.showQuickClassify
                },
                set: { newValue in
                    if !newValue {
                        showExport = false
                        showEditor = false
                        showShareSheet = false
                        showDriverTotals = false
                        showMissingTypeList = false
                        viewModel.showQuickClassify = false
                    }
                }
            )) {
                Group {
                    if showExport {
                        ScrollView {
                            Text(viewModel.generateGroupedSummaryByLocation())
                                .padding()
                        }
                    } else if showEditor {
                        UnifiedDriverEditorView(viewModel: viewModel)
                    } else if showShareSheet {
                        ActivityView(activityItems: [shareMessage])
                    } else if showDriverTotals {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📊 Driver Totals")
                                    .font(.title2)
                                    .bold()
                                    .padding(.bottom, 4)
                                
                                Text(viewModel.generateDriverTotalsSummary())
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal)
                            }
                            .padding()
                        }
                    } else if showMissingTypeList {
                        MissingTypeListView(viewModel: viewModel)
                    } else if viewModel.showQuickClassify {
                        QuickPickTypeView(viewModel: viewModel)
                    }
                }
            }
        }
    }
}
