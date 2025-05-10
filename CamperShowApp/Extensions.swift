// MARK: - CSV Functions
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        Array(Set(self))
    }
}

extension Camper {
    var displayVIN: String {
        let trimmedVIN = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperVIN = trimmedVIN.uppercased()
        
        if upperVIN.hasSuffix("F") || upperVIN.hasSuffix("D") {
            let strippedVIN = String(trimmedVIN.dropLast())
            return String(strippedVIN.suffix(5))
        } else {
            return String(trimmedVIN.suffix(5))
        }
    }
    
    var isFifthWheel: Bool {
        vin.uppercased().hasSuffix("F") || type == "FW"
    }
    
    var isDrivable: Bool {
        vin.uppercased().hasSuffix("D") || type == "Drive"
    }
}

extension Camper {
    var displayTypeTag: String {
        switch type {
        case "FW": return "(FW)"
        case "BP": return "(BP)"
        case "Park": return "(Park)"
        case "Drive": return "(DR)"
        default: return ""
        }
    }
}
