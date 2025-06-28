import Foundation

/// Defines different types of services we can receive messages from.
@frozen
public enum Service: Sendable, Hashable, CaseIterable {
    /// An iMessage
    case iMessage
    /// A message sent as SMS
    case sms
    /// A message sent as RCS
    case rcs
    /// A message sent via satellite
    case satellite
    /// Any other type of message
    case other(String)
    /// Used when service field is not set
    case unknown
    
    public static var allCases: [Service] {
        [.iMessage, .sms, .rcs, .satellite, .unknown]
    }
    
    /// Creates a Service enum variant based on the provided service name string.
    public static func from(_ service: String?) -> Service {
        guard let serviceName = service?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .unknown
        }
        
        switch serviceName {
        case "iMessage":
            return .iMessage

        case "iMessageLite":
            return .satellite

        case "SMS":
            return .sms

        case "rcs", "RCS":
            return .rcs

        case "":
            return .unknown

        default:
            return .other(serviceName)
        }
    }
}

extension Service: CustomStringConvertible {
    public var description: String {
        switch self {
        case .iMessage:
            return "iMessage"

        case .sms:
            return "SMS"

        case .rcs:
            return "RCS"

        case .satellite:
            return "Satellite"

        case .other(let name):
            return name

        case .unknown:
            return "Unknown"
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        description
    }
}
