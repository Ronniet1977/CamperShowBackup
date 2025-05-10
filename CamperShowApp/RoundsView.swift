import SwiftUI

struct RoundsView: View {
    @ObservedObject var viewModel: CamperViewModel
    @State private var selectedRound: Int?
    @State private var showRoundExport = false
    @State private var selectedRoundForExport: Int?
    @State private var showRoundPicker = false
    
    var groupedByRound: [Int: [Camper]] {
        Dictionary(grouping: viewModel.campers.filter { $0.roundNumber != nil }) { $0.roundNumber! }
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
    }
    var completedRounds: [Int] {
        let grouped = Dictionary(grouping: viewModel.campers) { $0.roundNumber ?? 0 }
        
        return grouped.compactMap { round, campers in
            let allDelivered = campers.allSatisfy { !($0.status2 ?? "").isEmpty && !($0.photoPath ?? "").isEmpty }
            return allDelivered ? round : nil
        }.sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if groupedByRound.isEmpty {
                    Text("No rounds available yet.")
                        .padding()
                } else {
                    List {
                        ForEach(groupedByRound.keys.sorted(), id: \.self) { round in
                            Section(header: Text("Round \(round)").bold()) {
                                ForEach(groupedByRound[round] ?? []) { camper in
                                    VStack(alignment: .leading) {
                                        Text("\(camper.model) \(camper.displayTypeTag) \(camper.displayVIN)")
                                            .font(.headline)
                                        
                                        Text("📍 \(camper.location)")
                                            .font(.subheadline)
                                        
                                        if let driver = camper.assignedTo {
                                            Text("👤 \(driver)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let status = camper.status2, !status.isEmpty {
                                            Text("✅ Delivered")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if let photoPath = camper.photoPath,
                                           let image = UIImage(contentsOfFile: photoPath) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                                .cornerRadius(8)
                                                .padding(.top, 4)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rounds")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showRoundPicker = true
                    } label: {
                        Label("Export Photos", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .confirmationDialog("Pick a Round", isPresented: $showRoundPicker, titleVisibility: .visible) {
                ForEach(groupedByRound.keys.sorted(), id: \.self) { round in
                    Button("Round \(round)") {
                        selectedRoundForExport = round
                        exportPhotos(for: round)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    // MARK: - Export Photos
    func exportPhotos(for round: Int) {
        let deliveredWithPhotos = viewModel.campers.filter {
            $0.roundNumber == round &&
            !($0.status2 ?? "").isEmpty &&
            !($0.photoPath ?? "").isEmpty
        }
        
        guard !deliveredWithPhotos.isEmpty else {
            print("❌ No photos to export for Round \(round).")
            return
        }
        
        let messageText = deliveredWithPhotos.map { camper in
            "• \(camper.model) \(camper.displayVIN) @ \(camper.location)"
        }.joined(separator: "\n")
        
        let photoURLs: [URL] = deliveredWithPhotos.compactMap {
            guard let path = $0.photoPath else { return nil }
            return URL(fileURLWithPath: path)
        }
        
        let activityVC = UIActivityViewController(
            activityItems: ["Round \(round)\n\n\(messageText)"] + photoURLs,
            applicationActivities: nil
        )
        
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController?
            .present(activityVC, animated: true)
    }
}
