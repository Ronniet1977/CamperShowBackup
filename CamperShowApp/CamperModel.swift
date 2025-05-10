import Foundation

var type: String? // <-- Add this to your camper model


struct Camper: Identifiable, Codable {
    var id = UUID()
    var year: String
    var make: String
    var model: String
    var modelName: String
    var vin: String
    var location: String
    var assignedTo: String?
    var status1: String?
    var date1: String?
    var status2: String?
    var date2: String?
    var type: String?
    var isSelected: Bool? = false
    var photoPath: String?
    var roundNumber: Int? = nil

}
extension Camper {
    func toCSVLine() -> String {
        var fields: [String] = []
        fields.append(year)
        fields.append(make)
        fields.append(model)
        fields.append(modelName)
        fields.append(vin)
        fields.append(location)
        fields.append(assignedTo ?? "")
        fields.append(status1 ?? "")
        fields.append(date1 ?? "")
        fields.append(status2 ?? "")
        fields.append(date2 ?? "")
        fields.append(type ?? "")
        fields.append((isSelected ?? false) ? "true" : "false")
        fields.append(photoPath ?? "")
        fields.append(roundNumber != nil ? String(roundNumber!) : "")
        return fields.joined(separator: ",")
    }
}
