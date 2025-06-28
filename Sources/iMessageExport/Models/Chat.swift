import Foundation

/// Chat properties are stored as a plist in the database
/// This represents the metadata for a chatroom
public struct ChatProperties: Sendable, Hashable, Codable {
    /// Whether the chat has read receipts enabled
    public let readReceiptsEnabled: Bool
    /// The most recent message in the chat
    public let lastMessageGuid: String?
    /// Whether the chat was forced to use SMS/RCS instead of iMessage
    public let forcedSms: Bool
    /// GUID of the group photo, if it exists in the attachments table
    public let groupPhotoGuid: String?
    
    public init(
        readReceiptsEnabled: Bool = false,
        lastMessageGuid: String? = nil,
        forcedSms: Bool = false,
        groupPhotoGuid: String? = nil
    ) {
        self.readReceiptsEnabled = readReceiptsEnabled
        self.lastMessageGuid = lastMessageGuid
        self.forcedSms = forcedSms
        self.groupPhotoGuid = groupPhotoGuid
    }
}

/// Represents a single row in the `chat` table.
public struct Chat: Sendable, Hashable, Codable, Identifiable {
    /// The unique identifier for the chat in the database
    public let rowid: Int32
    /// The identifier for the chat, typically a phone number, email, or group chat ID
    public let chatIdentifier: String
    /// The service the chat used, i.e. iMessage, SMS, IRC, etc.
    public let serviceName: String?
    /// Optional custom name created for the chat
    public let displayName: String?
    /// Chat properties parsed from plist data
    public let properties: ChatProperties?
    
    public var id: Int32 { rowid }
    
    public init(
        rowid: Int32,
        chatIdentifier: String,
        serviceName: String? = nil,
        displayName: String? = nil,
        properties: ChatProperties? = nil
    ) {
        self.rowid = rowid
        self.chatIdentifier = chatIdentifier
        self.serviceName = serviceName
        self.displayName = displayName
        self.properties = properties
    }
    
    /// The service type for this chat
    public var service: Service {
        Service.from(serviceName)
    }
    
    /// Whether this is a group chat
    public var isGroupChat: Bool {
        chatIdentifier.hasPrefix("chat")
    }
    
    /// Whether this is a direct message chat
    public var isDirectMessage: Bool {
        !isGroupChat
    }
    
    /// The display name for the chat, falling back to chat identifier if no custom name
    public var name: String {
        displayName ?? chatIdentifier
    }
    
    /// Whether this chat has a custom display name
    public var hasCustomName: Bool {
        displayName != nil && !displayName!.isEmpty
    }
    
    /// Whether this chat has a group photo
    public var hasGroupPhoto: Bool {
        properties?.groupPhotoGuid != nil
    }
}

extension Chat: CustomStringConvertible {
    public var description: String {
        "Chat(rowid: \(rowid), identifier: \(chatIdentifier), service: \(service), displayName: \(displayName ?? "nil"))"
    }
}
