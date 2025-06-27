import Foundation

/// Represents a single row in the `handle` table.
public struct Handle: Sendable, Hashable, Codable, Identifiable {
    /// The unique identifier for the handle in the database
    public let rowid: Int32
    /// Identifier for a contact, i.e. a phone number or email address
    public let id: String
    /// Field used to disambiguate divergent handles that represent the same contact
    public let personCentricId: String?
    
    public init(rowid: Int32, id: String, personCentricId: String? = nil) {
        self.rowid = rowid
        self.id = id
        self.personCentricId = personCentricId
    }
    
    /// Whether this handle represents an email address
    public var isEmail: Bool {
        id.contains("@")
    }
    
    /// Whether this handle represents a phone number
    public var isPhoneNumber: Bool {
        !isEmail && (id.hasPrefix("+") || id.allSatisfy { $0.isNumber || $0 == "-" || $0 == "(" || $0 == ")" || $0 == " " })
    }
    
    /// Formatted version of the handle ID for display
    public var displayId: String {
        if isPhoneNumber {
            return formatPhoneNumber(id)
        }
        return id
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.filter { $0.isNumber }
        
        if digitsOnly.count == 10 {
            let areaCode = digitsOnly.prefix(3)
            let prefix = digitsOnly.dropFirst(3).prefix(3)
            let number = digitsOnly.suffix(4)
            return "(\(areaCode)) \(prefix)-\(number)"
        } else if digitsOnly.count == 11 && digitsOnly.hasPrefix("1") {
            let withoutCountryCode = String(digitsOnly.dropFirst())
            return formatPhoneNumber(withoutCountryCode)
        }
        
        return number
    }
}

extension Handle: CustomStringConvertible {
    public var description: String {
        "Handle(rowid: \(rowid), id: \(id), personCentricId: \(personCentricId ?? "nil"))"
    }
}