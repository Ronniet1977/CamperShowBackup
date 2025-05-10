import SwiftUI

class CamperShowViewModel: ObservableObject {
    @Published var campers: [Camper] = []
    
    func importCSV(from url: URL) {
        do {
            let csvText = try String(contentsOf: url, encoding: String.Encoding.utf8)
            let lines = csvText.components(separatedBy: .newlines)
            var newCampers: [Camper] = []
            
            for line in lines.dropFirst() where !line.isEmpty {
                let fields = line.components(separatedBy: ",")
                if fields.count >= 4 {
                    let camper = Camper(
                        year: "2025",
                        make: "Forest River",
                        model: "Alpha Wolf",
                        modelName: "32BH",
                        vin: "5ZT2CXBB9R9012345",
                        location: "Wilkes-Barre",
                        assignedTo: nil,
                        status1: nil,
                        date1: nil,
                        status2: nil,
                        date2: nil
                    )
                    newCampers.append(camper)
                }
            }
            
            DispatchQueue.main.async {
                self.campers = newCampers
                print("✅ Imported \(newCampers.count) campers")
            }
        } catch {
            print("❌ Import failed: \(error.localizedDescription)")
        }
    }
}

