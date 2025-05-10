import SwiftUI
import Foundation

enum StatusField {
    case status1
    case status2
}

struct UnifiedDriverData: Codable {
    var driverList: [String]
    var bumperPullDrivers: [String]
}

class CamperViewModel: ObservableObject {
    enum UserRole: String, CaseIterable, Codable {
        case admin
        case driver
    }

    // Use AppStorage for persistent role management
    @AppStorage("userRole") var userRoleRaw: String = ""
    var userRole: UserRole? {
        get { UserRole(rawValue: userRoleRaw) }
        set { userRoleRaw = newValue?.rawValue ?? "" }
    }

    @Published var campers: [Camper] = []
    @Published var driverList: [String] = []
    @Published var bumperPullDrivers: [String] = []
    @Published var showMissingTypeAlert = false
    @Published var missingTypeCount = 0
    @Published var showMissingTypeList = false
    @Published var missingTypeCampers: [Camper] = []
    @Published var showQuickClassify = false
    @Published var camperPhotos: [UUID: UIImage] = [:]


    init() {
        loadDriverList()
        loadBumperPullDrivers()
        loadCampersFromCSV()
        reloadPhotos()
        loadSavedPhotos()
    }
    
    func saveUserRole() {
        if let role = userRole {
            userRoleRaw = role.rawValue
        }
    }
    
    func logout() {
        userRole = nil
        UserDefaults.standard.removeObject(forKey: "UserRole")
    }

    func loadDriverList() {
        let fileName = "DriverList.json"
        let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Driver Data/\(fileName)"

        DropboxDownloader.shared.download(
            from: dropboxPath
        ) { url in
            guard let url = url else {
                print("❌ Failed to download driver list")
                
                return
            }

            do {
                let data = try Data(contentsOf: url)
                self.driverList = try JSONDecoder().decode([String].self, from: data)
                print("✅ Loaded driver list from Dropbox")
            } catch {
                print("❌ Failed to decode driver list: \(error.localizedDescription)")
            }
        }
    }


    
    func registerDriverIfNeeded(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        if !driverList.contains(trimmedName) {
            driverList.append(trimmedName)
            saveDriverList()
            createDriverPhotoFolder(trimmedName)
            print("🆕 Added new driver and created photo folder: \(trimmedName)")
            return true
        } else {
            createDriverPhotoFolder(trimmedName) // ensure folder exists even if driver is already added
            print("👤 Driver already exists: \(trimmedName)")
            return false
        }
    }

    
    func createDriverPhotoFolder(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let driverFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos")
            .appendingPathComponent(trimmedName)

        if !FileManager.default.fileExists(atPath: driverFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: driverFolderURL, withIntermediateDirectories: true)
                print("📸 Created photo folder for driver: \(driverFolderURL.lastPathComponent)")
            } catch {
                print("❌ Failed to create driver folder: \(error.localizedDescription)")
            }
        } else {
            print("📁 Photo folder already exists for: \(trimmedName)")
        }
    }


    // MARK: - 🚛 Driver List Functions
    func addDriver(_ name: String, isBumperPull: Bool) {
        if isBumperPull {
            if !bumperPullDrivers.contains(name) {
                bumperPullDrivers.append(name)
                saveBumperPullDrivers()
            }
        } else {
            if !driverList.contains(name) {
                driverList.append(name)
                saveDriverList()
            }
        }
    }

    func removeDriver(_ name: String, isBumperPull: Bool) {
        if isBumperPull {
            bumperPullDrivers.removeAll { $0 == name }
            saveBumperPullDrivers()
        } else {
            driverList.removeAll { $0 == name }
            saveDriverList()
        }

        // Unassign any campers assigned to this driver
        for i in campers.indices {
            if campers[i].assignedTo == name {
                campers[i].assignedTo = nil
            }
        }

        // Save the updated list
        CamperViewModel.saveCSVToDocuments(from: campers)
    }

    // MARK: - 🚛 Driver List Functions
    func loadBumperPullDrivers() {
        let fileName = "BumperPullOnlyDrivers.json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: url)
            bumperPullDrivers = try JSONDecoder().decode([String].self, from: data)
            print("✅ Loaded bumper pull driver list")
        } catch {
            print("❌ Failed to load bumper pull drivers: \(error.localizedDescription)")
            bumperPullDrivers = []
        }
    }
    
    // MARK: - 🚛 Driver List Functions
    func saveDriverList() {
        let fileName = "DriverList.json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            let data = try JSONEncoder().encode(driverList)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("✅ Driver list saved locally")

            DropboxUploader.shared.upload(
                localURL: fileURL,
                to: "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Driver Data/\(fileName)"
            )
            
            exportUnifiedDriverList()

        } catch {
            print("❌ Failed to save driver list: \(error.localizedDescription)")
        }
    }

    func saveBumperPullDrivers() {
        let fileName = "BumperPullOnlyDrivers.json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(bumperPullDrivers)
            try data.write(to: url, options: [.atomicWrite])
            print("✅ Saved bumper pull driver list")
            DropboxUploader.shared.upload(localURL: url,
                to: "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Driver Data/BumperPullOnlyDrivers.json")
            
            exportUnifiedDriverList()

        } catch {
            print("❌ Failed to save bumper pull drivers: \(error.localizedDescription)")
        }
    }
    
    func saveUnifiedDriverList() {
        exportUnifiedDriverList()
    }

    
    func exportUnifiedDriverList() {
        let unified = UnifiedDriverData(driverList: driverList, bumperPullDrivers: bumperPullDrivers)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllDrivers.json")

        do {
            let data = try JSONEncoder().encode(unified)
            try data.write(to: url)
            print("✅ Exported AllDrivers.json")

            // Upload to Dropbox for portal
            let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Driver Data/AllDrivers.json"
            DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
        } catch {
            print("❌ Failed to export unified driver list: \(error)")
        }
    }

    
    func importUnifiedDriverList(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let unified = try JSONDecoder().decode(UnifiedDriverData.self, from: data)
            driverList = unified.driverList
            bumperPullDrivers = unified.bumperPullDrivers
            saveDriverList()
            saveBumperPullDrivers()
            print("✅ Imported AllDrivers.json")
        } catch {
            print("❌ Failed to import unified driver list: \(error)")
        }
    }
    
    func loadCampersFromCSV(url: URL) {
        do {
            let csvText = try String(contentsOf: url, encoding: .utf8)
            print("📥 CSV CONTENT:\n\(csvText)")
            let lines = csvText.components(separatedBy: .newlines).dropFirst()

            var loadedCampers: [Camper] = []

            for line in lines where !line.isEmpty {
                let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                if fields.count >= 6 {
                    var camper = Camper(
                        year: fields[safe: 0] ?? "",
                        make: fields[safe: 1] ?? "",
                        model: fields[safe: 2] ?? "",
                        modelName: fields[safe: 3] ?? "",
                        vin: fields[safe: 4] ?? "",
                        location: fields[safe: 5] ?? "",
                        assignedTo: fields[safe: 6],
                        status1: fields[safe: 7],
                        date1: fields[safe: 8],
                        status2: fields[safe: 9],
                        date2: fields[safe: 10],
                        type: fields[safe: 11],
                        isSelected: (fields[safe: 12]?.lowercased() == "true"),
                        photoPath: fields[safe: 13]
                    )

                    if camper.type == nil || camper.type?.isEmpty == true {
                        camper.type = "Unknown"
                    }

                    loadedCampers.append(camper)
                }
            }

            self.campers = loadedCampers
            print("✅ Loaded \(loadedCampers.count) campers from \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to load campers from \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // MARK: - 🚚 Camper Loading and Saving
    func loadCampersFromCSV() {
        let fileName = "Camper Show Log.csv"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        do {
            let csvText = try String(contentsOf: url, encoding: .utf8)
            let lines = csvText.components(separatedBy: .newlines).dropFirst()
            
            var loadedCampers: [Camper] = []
            
            for line in lines where !line.isEmpty {
                let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if fields.count >= 6 {
                    var camper = Camper(
                        year: fields[safe: 0] ?? "",
                        make: fields[safe: 1] ?? "",
                        model: fields[safe: 2] ?? "",
                        modelName: fields[safe: 3] ?? "",
                        vin: fields[safe: 4] ?? "",
                        location: fields[safe: 5] ?? "",
                        assignedTo: fields[safe: 6],
                        status1: fields[safe: 7],
                        date1: fields[safe: 8],
                        status2: fields[safe: 9],
                        date2: fields[safe: 10],
                        type: fields[safe: 11],
                        isSelected: (fields[safe: 12]?.lowercased() == "true") ? true : false,
                        photoPath: fields[safe: 13]
                    )
                    
                    // ✅ Fix missing types
                    if camper.type == nil || camper.type?.isEmpty == true {
                        camper.type = "Unknown"
                    }
                    
                    loadedCampers.append(camper)
                }
            }
            
            self.campers = loadedCampers
            print("✅ Loaded \(loadedCampers.count) campers")
        } catch {
            print("❌ No CSV found — starting fresh.")
        }
    }
    
    func loadCampersFromCSV(data: Data) {
        guard let csvText = String(data: data, encoding: .utf8) else {
            print("❌ Failed to decode CSV data")
            return
        }

        let lines = csvText.components(separatedBy: .newlines).dropFirst()
        var loadedCampers: [Camper] = []

        for line in lines where !line.isEmpty {
            let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if fields.count >= 6 {
                var camper = Camper(
                    year: fields[safe: 0] ?? "",
                    make: fields[safe: 1] ?? "",
                    model: fields[safe: 2] ?? "",
                    modelName: fields[safe: 3] ?? "",
                    vin: fields[safe: 4] ?? "",
                    location: fields[safe: 5] ?? "",
                    assignedTo: fields[safe: 6],
                    status1: fields[safe: 7],
                    date1: fields[safe: 8],
                    status2: fields[safe: 9],
                    date2: fields[safe: 10],
                    type: fields[safe: 11],
                    isSelected: (fields[safe: 12]?.lowercased() == "true"),
                    photoPath: fields[safe: 13]
                )
                if camper.type?.isEmpty ?? true {
                    camper.type = "Unknown"
                }
                loadedCampers.append(camper)
            }
        }

        DispatchQueue.main.async {
            self.campers = loadedCampers
            print("✅ Refreshed with \(loadedCampers.count) campers from Dropbox")
        }
    }
    
    func verifyAdminPassword(_ input: String) -> Bool {
        return input == "LestersShow1234"
    }
    
    func refreshFromDropbox() {
        let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Camper Show Log.csv"
        
        DropboxDownloader.shared.download(from: dropboxPath) { fileURL in
            guard let fileURL = fileURL else {
                print("❌ Failed to download CSV from Dropbox")
                return
            }
            
            DispatchQueue.main.async {
                self.loadCampersFromCSV(url: fileURL)
            }
        }
    }


    // MARK: - 🔁 Assignment Functions
    func assignCampersRoundRobin() {
        // ✅ Step 1: Block if missing types
        let missing = campers.filter { $0.type == nil || $0.type == "Unknown" }
        if !missing.isEmpty {
            missingTypeCampers = missing
            missingTypeCount = missing.count
            showMissingTypeAlert = true
            showMissingTypeList = true
            print("❌ Blocked Round Robin: \(missing.count) campers missing type")
            return
        }
        
        // ✅ Step 2: Setup drivers
        let bpOnly = bumperPullDrivers
        let fwCapable = driverList.filter { !bpOnly.contains($0) }
        let allDrivers = fwCapable + bpOnly
        
        // ✅ Step 3: Reset round numbers
        for i in campers.indices {
            campers[i].roundNumber = nil
        }
        
        // ✅ Step 4: Get unassigned, undelivered campers
        var unassigned = campers.enumerated().filter {
            ($0.element.assignedTo?.isEmpty ?? true) &&
            ($0.element.status2 ?? "").isEmpty
        }
        
        var round = 1
        let maxRounds = 1000  // safety guard to avoid infinite loop
        
        while !unassigned.isEmpty && round <= maxRounds {
            var assignedDrivers: Set<String> = []
            var assignedThisRound = false  // track progress
            
            for camperType in ["FW", "BP", "Park"] {
                var i = 0
                while i < unassigned.count {
                    let index = unassigned[i].offset
                    let camper = unassigned[i].element
                    
                    if camper.type != camperType || camper.type == "Drive" {
                        i += 1
                        continue
                    }
                    
                    let eligibleDrivers: [String] = {
                        if camperType == "FW" {
                            return fwCapable.filter { !assignedDrivers.contains($0) }
                        } else {
                            return (fwCapable + bpOnly).filter { !assignedDrivers.contains($0) }
                        }
                    }()
                    
                    guard let driver = eligibleDrivers.first else {
                        i += 1
                        continue
                    }
                    
                    campers[index].assignedTo = driver
                    campers[index].roundNumber = round
                    assignedDrivers.insert(driver)
                    unassigned.remove(at: i)
                    assignedThisRound = true
                }
            }
            
            // Break early if nothing assigned this round
            if !assignedThisRound { break }
            
            round += 1
        }
        if !campers.isEmpty {
            CamperViewModel.saveCSVToDocuments(from: campers)
            if let url = CamperViewModel.generateCSVFile(from: campers) {
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
                DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
            }
        } else {
            print("⚠️ Not saving CSV — camper list is empty.")
        }

        if let csvURL = Self.generateCSVFile(from: campers) {

            let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(csvURL.lastPathComponent)"
            DropboxUploader.shared.upload(localURL: csvURL, to: dropboxPath)
        }

        print("✅ Assigned by round, skipping delivered. Total rounds: \(round - 1)")
    }
    
    func unassignAllUnpickedCampers() {
        for i in campers.indices {
            if (campers[i].status1 ?? "").isEmpty {
                campers[i].assignedTo = nil
            }
        }
        CamperViewModel.saveCSVToDocuments(from: campers)
        if let url = CamperViewModel.generateCSVFile(from: campers) {
            let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
            DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
        }
        print("✅ Unassigned only unpicked campers")
    }
    
    func uploadCSVToPortal(fileURL: URL, driver: String) {
        var request = URLRequest(url: URL(string: "https://ronniethayer.pythonanywhere.com/upload_assignments")!)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        // Add driver field
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"driver\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(driver)\r\n".data(using: .utf8)!)

        // Add file
        let filename = fileURL.lastPathComponent
        let fileData = try? Data(contentsOf: fileURL)
        let mimeType = "text/csv"

        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData ?? Data())
        data.append("\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Upload
        URLSession.shared.uploadTask(with: request, from: data) { _, response, error in
            if let error = error {
                print("❌ Upload failed: \(error)")
            } else {
                print("✅ Uploaded CSV for \(driver)")
            }
        }.resume()
    }
    
    
    func exportAssignmentsCSV() -> URL? {
        let fileName = "Camper Show Logs.csv"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        let header = "Make,VIN,Location,Driver,Round"
        let lines = campers
            .filter { !($0.assignedTo ?? "").isEmpty }
            .map {
                let make = $0.make
                let vin = String($0.vin.suffix(5))
                let location = $0.location
                let driver = $0.assignedTo ?? ""
                let round = "\($0.roundNumber ?? 0)"
                return "\(make),\(vin),\(location),\(driver),\(round)"
            }

        let csvText = ([header] + lines).joined(separator: "\n")

        do {
            try csvText.write(to: url, atomically: true, encoding: .utf8)
            print("✅ Exported assignments to \(url.lastPathComponent)")
            return url
        } catch {
            print("❌ Failed to export assignments CSV: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 📋 Summary Generators
    func generateAssignmentSummary() -> String {
        var summaryLines: [String] = []
        var grouped: [String: [String]] = [:]
        
        for camper in campers {
            let typeTag = camper.vin.lowercased().hasSuffix("f") ? "[FW]" : "[BP]"
            let line = "\(typeTag) \(camper.make) \(camper.vin) → \(camper.location)"
            let driver = camper.assignedTo ?? "Unassigned"
            grouped[driver, default: []].append(line)
        }
        
        // Show assigned drivers first, sorted alphabetically
        let assignedDrivers = grouped.keys.filter { $0 != "Unassigned" }.sorted()
        
        for driver in assignedDrivers {
            let camperLines = grouped[driver] ?? []
            let tag = bumperPullDrivers.contains(driver) ? "[BP]" : "[FW]"
            summaryLines.append("🧑‍✈️ \(driver) \(tag) – \(camperLines.count) camper(s)")
            summaryLines.append(contentsOf: camperLines.map { "  \($0)" })
            summaryLines.append("") // spacer
        }
        
        // Show unassigned campers at the end
        if let unassigned = grouped["Unassigned"] {
            summaryLines.append("⚠️ Unassigned – \(unassigned.count) camper(s)")
            summaryLines.append(contentsOf: unassigned.map { "  \($0)" })
        }
        
        return summaryLines.joined(separator: "\n")
    }
    
    // MARK: - 📋 Summary Generators
    func generateGroupedSummaryByLocation() -> String {
        var summary = ""
        var fwCount = 0
        var bpCount = 0
        
        let locationGroups = Dictionary(grouping: campers) { $0.location }
        
        for (location, campersAtLocation) in locationGroups.sorted(by: { $0.key < $1.key }) {
            summary += "📍 \(location):\n"
            
            let driverGroups = Dictionary(grouping: campersAtLocation) { $0.assignedTo ?? "Unassigned" }
            
            for (driver, driverCampers) in driverGroups.sorted(by: { $0.key < $1.key }) {
                summary += "  🧑‍✈️ \(driver) — \(driverCampers.count) unit\(driverCampers.count == 1 ? "" : "s"):\n"
                
                for camper in driverCampers {
                    let last5 = String(camper.vin.suffix(5))
                    let type = camper.vin.lowercased().hasSuffix("f") ? "FW" : "BP"
                    summary += "     • \(camper.model) • \(last5) [\(type)]\n"
                    if type == "FW" { fwCount += 1 } else { bpCount += 1 }
                }
            }
            
            summary += "\n"
        }
        
        summary += "==========\n"
        summary += "🚚 Fifth Wheel Total: \(fwCount)\n"
        summary += "🚙 Bumper Pull Total: \(bpCount)\n"
        
        return summary
    }
    
    // MARK: - 📋 Summary Generators
    func generateGroupedDriverSummary() -> String {
        var grouped: [String: [String]] = [:]
        
        for camper in campers {
            let driver = camper.assignedTo ?? "Unassigned"
            let vin = camper.vin.trimmingCharacters(in: .whitespacesAndNewlines)
            let vinStripped = vin.uppercased().hasSuffix("F") ? String(vin.dropLast()) : vin
            let displayVIN = String(vinStripped.suffix(5))
            let line = "\(camper.make) \(displayVIN) → \(camper.location)"
            grouped[driver, default: []].append(line)
        }
        
        return grouped
            .sorted { $0.key < $1.key }
            .map { driver, campers in
                "\(driver):\n" + campers.map { "  \($0)" }.joined(separator: "\n")
            }
            .joined(separator: "\n\n")
    }
    
    // MARK: - 📋 Summary Generators
    func generateDriverTotalsSummary() -> String {
        let counts = driverAssignmentCounts()
        let sorted = counts.sorted { $0.key < $1.key }
        var lines: [String] = []
        
        var totalCampers = 0
        
        for (driver, count) in sorted {
            let tag = bumperPullDrivers.contains(driver) ? "(BP)" : "(FW)"
            lines.append("→ \(driver) \(tag): \(count)")
            totalCampers += count
        }
        
        lines.append("")
        lines.append("📦 Grand Total: \(totalCampers) campers")
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - 🔁 Assignment Functions
    func driverAssignmentCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for camper in campers {
            if let driver = camper.assignedTo, !driver.isEmpty {
                counts[driver, default: 0] += 1
            }
        }
        return counts
    }
    
    // MARK: - ✏️ Camper Updates
    func assignDriver(camper: Camper, to driver: String) {
        if let index = campers.firstIndex(where: { $0.id == camper.id }) {
            campers[index].assignedTo = driver
            CamperViewModel.saveCSVToDocuments(from: campers)
            if let url = CamperViewModel.generateCSVFile(from: campers) {
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
                DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
            }
            print("✅ Assigned to \(driver)")
        }
    }
    
    // MARK: - ✏️ Camper Updates
    func updateCamperType(camper: Camper, newType: String) {
        if let index = campers.firstIndex(where: { $0.id == camper.id }) {
            campers[index].type = newType
            
            if newType == "FW" {
                // ➡️ Add "F" to VIN if missing
                if !campers[index].vin.uppercased().hasSuffix("F") {
                    campers[index].vin += "F"
                }
            } else if newType == "BP" {
                // ➡️ Remove "F" (if it exists) for BP
                campers[index].vin = campers[index].vin.replacingOccurrences(of: "F", with: "", options: .caseInsensitive)
            } else if newType == "Drive" {
                // ➡️ Do NOTHING to the VIN for Drive units
            }
            
            CamperViewModel.saveCSVToDocuments(from: campers)
            if let url = CamperViewModel.generateCSVFile(from: campers) {
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
                DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
            }
        }
    }
    
    // MARK: - 🚚 Camper Loading and Saving
    func importCSV(from fileURL: URL) {
        guard fileURL.startAccessingSecurityScopedResource() else {
            print("❌ Access denied")
            return
        }
        
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        do {
            let csvText = try String(contentsOf: fileURL, encoding: .utf8)
            let cleanedText = csvText

            let lines = cleanedText.components(separatedBy: .newlines).dropFirst()
            
            var newCampers: [Camper] = []
            
            for line in lines where !line.isEmpty {
                let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if fields.count >= 6 {
                    let camper = Camper(
                        year: fields[safe: 0] ?? "",
                        make: fields[safe: 1] ?? "",
                        model: fields[safe: 2] ?? "",
                        modelName: fields[safe: 3] ?? "",
                        vin: fields[safe: 4] ?? "",
                        location: fields[safe: 5] ?? "",
                        assignedTo: fields[safe: 6],
                        status1: fields[safe: 7],
                        date1: fields[safe: 8],
                        status2: fields[safe: 9],
                        date2: fields[safe: 10],
                        type: fields[safe: 11],
                        isSelected: (fields[safe: 12]?.lowercased() == "true") ? true : false,
                        photoPath: fields[safe: 13]
                    )
                    newCampers.append(camper)
                }
            }
            
            self.campers = newCampers
            CamperViewModel.saveCSVToDocuments(from: campers)
            if let url = CamperViewModel.generateCSVFile(from: campers) {
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
                DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
            }
            print("✅ Imported and saved \(newCampers.count) campers")
            
        } catch {
            print("❌ Import failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ✏️ Camper Updates
    func updateCamperInfo(_ updatedCamper: Camper) {
        if let index = campers.firstIndex(where: { $0.id == updatedCamper.id }) {
            campers[index] = updatedCamper
            CamperViewModel.saveCSVToDocuments(from: campers)
            if let url = CamperViewModel.generateCSVFile(from: campers) {
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
                DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
            }
        }
    }
    
    func reloadPhotos() {
        for camper in campers {
            if let image = loadPhoto(for: camper) {
                camperPhotos[camper.id] = image
            }
        }
    }
    
    func loadSavedPhotos() {
        for camper in campers {
            if let image = loadPhoto(for: camper) {
                camperPhotos[camper.id] = image
            }
        }
        print("✅ Loaded saved photos for \(camperPhotos.count) campers")
    }
    
    func savePhoto(_ image: UIImage, for camper: Camper) {
        guard let driver = camper.assignedTo else {
            print("❌ No driver assigned for camper \(camper.vin)")
            return
        }

        let last5 = camper.vin.suffix(5)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "\(driver)_\(last5)_\(timestamp).jpg"

        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos")
            .appendingPathComponent(driver)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let photoURL = folderURL.appendingPathComponent(fileName)

            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: photoURL, options: [.atomicWrite])
                camperPhotos[camper.id] = image
                print("✅ Saved photo for camper \(camper.vin) to \(photoURL.lastPathComponent)")

                // Save path back to camper
                if let index = campers.firstIndex(where: { $0.id == camper.id }) {
                    campers[index].photoPath = photoURL.path
                }
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Camper Photos/\(driver)/\(fileName)"
                            DropboxUploader.shared.upload(localURL: photoURL, to: dropboxPath)


            } else {
                print("❌ Could not convert image to JPEG")
            }
        } catch {
            print("❌ Failed to save photo: \(error.localizedDescription)")
        }
    }

    
    func loadPhoto(for camper: Camper) -> UIImage? {
        guard let path = camper.photoPath else { return nil }

        if FileManager.default.fileExists(atPath: path) {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }


    func sendDeliveryText(for camper: Camper) {
        guard let driver = camper.assignedTo,
              let location = camper.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        let vinSuffix = camper.vin.suffix(5)
        let message = """
        📦 Camper Delivered
        🛻 Driver: \(driver)
        🔧 Unit: \(camper.model) • \(vinSuffix)
        📍 Location: \(camper.location)
        ✅ Delivered: \(camper.date2 ?? "")
        """

        if let url = URL(string: "sms:&body=\(message)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - ✏️ Camper Updates
    func updateCamperStatus(camper: Camper, statusField: StatusField) {
        if let index = campers.firstIndex(where: { $0.id == camper.id }) {
            var updated = campers[index]
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let today = formatter.string(from: Date())
            
            switch statusField {
            case .status1:
                updated.status1 = "Picked Up"
                updated.date1 = today
            case .status2:
                updated.status2 = "Delivered"
                updated.date2 = today
                if statusField == .status2 {
                    sendDeliveryText(for: updated)
                }

            }
            
            campers[index] = updated  // <-- Force update SwiftUI
            CamperViewModel.saveCSVToDocuments(from: campers)
            if let url = CamperViewModel.generateCSVFile(from: campers) {
                let dropboxPath = "/RONNIE SHOW SHORTCUT FOLDER/Lester Show Logs/Assignments/\(url.lastPathComponent)"
                DropboxUploader.shared.upload(localURL: url, to: dropboxPath)
            }
            print("✅ Updated camper and saved CSV")
        }
    }
    
    // MARK: - 🗺️ Other
    func openInMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - 🚚 Camper Loading and Saving
    static func generateCSVFile(from campers: [Camper]) -> URL? {
        let fileName = "Camper Show Log.csv"  // Always the same during an active show

        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        let header = "Year,Make,Model,ModelName,VIN,Location,AssignedTo,Status1,Date1,Status2,Date2,Type,IsSelected,PhotoPath"
        
        var camperLines: [String] = []
        
        for camper in campers {
            let fields: [String] = [
                camper.year,
                camper.make,
                camper.model,
                camper.modelName,
                camper.vin,
                camper.location,
                camper.assignedTo ?? "",
                camper.status1 ?? "",
                camper.date1 ?? "",
                camper.status2 ?? "",
                camper.date2 ?? "",
                camper.type ?? "",
                (camper.isSelected ?? false) ? "true" : "false",
                camper.photoPath ?? ""
            ]
            
            let line = fields.joined(separator: ",")
            camperLines.append(line)
        }
        
        
        let csvText = ([header] + camperLines).joined(separator: "\n")
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ CSV generated at: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            print("❌ Failed to generate CSV: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func saveInventoryCSVToDocuments(from campers: [Camper]) -> URL {
        let fileName = "CamperInventory.csv"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        let header = "Year,Make,Model,ModelName,VIN,Location,AssignedTo,Status1,Date1,Status2,Date2,Type,IsSelected,PhotoPath"
        let lines = campers.map { $0.toCSVLine() }
        let csv = ([header] + lines).joined(separator: "\n")
        
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            print("✅ Inventory CSV saved")
        } catch {
            print("❌ Failed to save inventory CSV: \(error)")
        }
        
        return url
    }

    static func generateInventoryCSV(from campers: [Camper]) -> URL? {
        let fileName = "CamperInventory.csv"  // Constant file name
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        let header = "Year,Make,Model,ModelName,VIN,Location,Type"
        
        let selectedLines = campers
            .filter { $0.isSelected == true }
            .map {
                "\($0.year),\($0.make),\($0.model),\($0.modelName),\($0.vin),\($0.location),\($0.type ?? "")"
            }

        let unselectedLines = campers
            .filter { $0.isSelected != true }
            .map {
                "\($0.year),\($0.make),\($0.model),\($0.modelName),\($0.vin),\($0.location),\($0.type ?? "")"
            }

        let section1 = ["✅ INVENTORIED"] + selectedLines
        let section2 = ["", "❌ NOT INVENTORIED"] + unselectedLines
        let allLines = [header] + section1 + section2
        let csvText = allLines.joined(separator: "\n")
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Inventory CSV generated: \(fileName)")
            return fileURL
        } catch {
            print("❌ Failed to save inventory CSV: \(error.localizedDescription)")
            return nil
        }
    }


    // MARK: - 🚚 Camper Loading and Saving
    static func saveCSVToDocuments(from campers: [Camper]) {
            guard !campers.isEmpty else {
                print("⚠️ Skipping CSV save: No campers in list.")
                return
            }
        let fileName = "Camper Show Log.csv"
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        let header = "Year,Make,Model,ModelName,VIN,Location,AssignedTo,Status1,Date1,Status2,Date2,Type,IsSelected,PhotoPath"
        
        let camperLines = campers.map { $0.toCSVLine() }
        
        let csvText = ([header] + camperLines).joined(separator: "\n")
        
        do {
            try csvText.write(to: url, atomically: true, encoding: .utf8)
            print("✅ CSV saved at: \(url.lastPathComponent)")
        } catch {
            print("❌ Save failed: \(error.localizedDescription)")
        }
    }
}
// 📄 End of CamperViewModel.swift


