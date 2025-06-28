@_exported import Foundation

/// Represents a single row in the `message` table.
public struct Message: Sendable, Hashable, Codable, Identifiable {
    /// The unique identifier for the message in the database
    public let rowid: Int32
    /// The globally unique identifier for the message
    public let guid: String
    /// The text of the message
    public let text: String?
    /// Binary attributed body containing rich text data
    public let attributedBody: Data?
    /// The service the message was sent from
    public let service: String?
    /// The ID of the person who sent the message
    public let handleId: Int32?
    /// The address the database owner received the message at
    public let destinationCallerId: String?
    /// The content of the Subject field
    public let subject: String?
    /// The date the message was written to the database (nanoseconds since 2001-01-01)
    public let date: Int64
    /// The date the message was read (nanoseconds since 2001-01-01)
    public let dateRead: Int64
    /// The date a message was delivered (nanoseconds since 2001-01-01)
    public let dateDelivered: Int64
    /// `true` if the database owner sent the message, else `false`
    public let isFromMe: Bool
    /// `true` if the message was read by the recipient, else `false`
    public let isRead: Bool
    /// Intermediate data for determining the message variant
    public let itemType: Int32
    /// Optional handle for the recipient of a message that includes shared content
    public let otherHandle: Int32?
    /// Whether some shared data is active or inactive
    public let shareStatus: Bool
    /// Direction shared data was sent
    public let shareDirection: Bool?
    /// If the message updates the display name of the chat
    public let groupTitle: String?
    /// If the message modified a group
    public let groupActionType: Int32
    /// The message GUID of a message associated with this one
    public let associatedMessageGuid: String?
    /// The type of associated message
    public let associatedMessageType: Int32
    /// Bundle ID for app integrations
    public let balloonBundleId: String?
    /// Expressive send style identifier
    public let expressiveSendStyleId: String?
    /// GUID of the thread originator message
    public let threadOriginatorGuid: String?
    /// Part of the thread originator
    public let threadOriginatorPart: String?
    /// Date the message was edited
    public let dateEdited: Int64?
    /// Emoji associated with the message
    public let associatedMessageEmoji: String?
    
    // Additional computed fields
    /// Chat ID this message belongs to
    public let chatId: Int32?
    /// Number of attachments
    public let numAttachments: Int32
    /// Chat ID this message was deleted from
    public let deletedFrom: Int32?
    /// Number of replies to this message
    public let numReplies: Int32
    
    public var id: Int32 { rowid }
    
    public init(
        rowid: Int32,
        guid: String,
        text: String? = nil,
        attributedBody: Data? = nil,
        service: String? = nil,
        handleId: Int32? = nil,
        destinationCallerId: String? = nil,
        subject: String? = nil,
        date: Int64,
        dateRead: Int64 = 0,
        dateDelivered: Int64 = 0,
        isFromMe: Bool,
        isRead: Bool = false,
        itemType: Int32 = 0,
        otherHandle: Int32? = nil,
        shareStatus: Bool = false,
        shareDirection: Bool? = nil,
        groupTitle: String? = nil,
        groupActionType: Int32 = 0,
        associatedMessageGuid: String? = nil,
        associatedMessageType: Int32 = 0,
        balloonBundleId: String? = nil,
        expressiveSendStyleId: String? = nil,
        threadOriginatorGuid: String? = nil,
        threadOriginatorPart: String? = nil,
        dateEdited: Int64? = nil,
        associatedMessageEmoji: String? = nil,
        chatId: Int32? = nil,
        numAttachments: Int32 = 0,
        deletedFrom: Int32? = nil,
        numReplies: Int32 = 0
    ) {
        self.rowid = rowid
        self.guid = guid
        self.text = text
        self.attributedBody = attributedBody
        self.service = service
        self.handleId = handleId
        self.destinationCallerId = destinationCallerId
        self.subject = subject
        self.date = date
        self.dateRead = dateRead
        self.dateDelivered = dateDelivered
        self.isFromMe = isFromMe
        self.isRead = isRead
        self.itemType = itemType
        self.otherHandle = otherHandle
        self.shareStatus = shareStatus
        self.shareDirection = shareDirection
        self.groupTitle = groupTitle
        self.groupActionType = groupActionType
        self.associatedMessageGuid = associatedMessageGuid
        self.associatedMessageType = associatedMessageType
        self.balloonBundleId = balloonBundleId
        self.expressiveSendStyleId = expressiveSendStyleId
        self.threadOriginatorGuid = threadOriginatorGuid
        self.threadOriginatorPart = threadOriginatorPart
        self.dateEdited = dateEdited
        self.associatedMessageEmoji = associatedMessageEmoji
        self.chatId = chatId
        self.numAttachments = numAttachments
        self.deletedFrom = deletedFrom
        self.numReplies = numReplies
    }
    
    /// The service type for this message
    public var serviceType: Service {
        Service.from(service)
    }
    
    /// The expressive effect for this message
    public var expressiveEffect: ExpressiveEffect {
        ExpressiveEffect.from(styleId: expressiveSendStyleId)
    }
    
    /// Convert nanoseconds since 2001-01-01 to Date
    public static func dateFromNanoseconds(_ nanoseconds: Int64) -> Date {
        let referenceDate = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01 00:00:00 UTC
        let seconds = Double(nanoseconds) / 1_000_000_000.0
        return referenceDate.addingTimeInterval(seconds)
    }
    
    /// The actual date this message was sent
    public var sentDate: Date {
        Message.dateFromNanoseconds(date)
    }
    
    /// The actual date this message was read
    public var readDate: Date? {
        guard dateRead > 0 else { return nil }
        return Message.dateFromNanoseconds(dateRead)
    }
    
    /// The actual date this message was delivered
    public var deliveredDate: Date? {
        guard dateDelivered > 0 else { return nil }
        return Message.dateFromNanoseconds(dateDelivered)
    }
    
    /// The actual date this message was edited
    public var editedDate: Date? {
        guard let dateEdited = dateEdited, dateEdited > 0 else { return nil }
        return Message.dateFromNanoseconds(dateEdited)
    }
    
    /// Whether this message has attachments
    public var hasAttachments: Bool {
        numAttachments > 0
    }
    
    /// Whether this message is a reply to another message
    public var isReply: Bool {
        threadOriginatorGuid != nil
    }
    
    /// Whether this message has replies
    public var hasReplies: Bool {
        numReplies > 0
    }
    
    /// Whether this message was edited
    public var wasEdited: Bool {
        dateEdited != nil && dateEdited! > 0
    }
    
    /// Whether this message has expressive effects
    public var hasExpressiveEffect: Bool {
        !expressiveEffect.isNone
    }
    
    /// Whether this message is a reaction/tapback
    public var isReaction: Bool {
        variant.isReaction
    }
    
    /// Whether this message is a group announcement
    public var isAnnouncement: Bool {
        variant.isAnnouncement
    }
    
    /// Whether this message is an app integration
    public var isAppMessage: Bool {
        variant.isApp
    }
    
    /// Whether this message is normal text/content
    public var isNormalMessage: Bool {
        variant.isNormal
    }
    
    /// Whether this message was deleted
    public var wasDeleted: Bool {
        deletedFrom != nil
    }
    
    /// The effective text content, preferring regular text but falling back to streamtyped parsing
    public var effectiveText: String? {
        // If we have regular text, use it
        if let text = text, !text.isEmpty {
            return text
        }
        
        // Fall back to parsing attributedBody for streamtyped content
        if let attributedBody = attributedBody {
            return parseStreamtypedText(from: attributedBody)
        }
        
        return nil
    }
    
    /// Message variant based on comprehensive analysis of message properties
    /// Follows the same classification logic as the Rust imessage-exporter
    public var variant: MessageVariant {
        // Priority 1: Edited messages
        if wasEdited {
            return .edited
        }
        
        // Priority 2: Associated message types (reactions/tapbacks)
        if let (action, tapback) = Tapback.from(associatedMessageType: associatedMessageType, emoji: associatedMessageEmoji) {
            return .tapback(action, tapback)
        }
        
        // Priority 3: SharePlay
        if itemType == 6 {
            return .sharePlay
        }
        
        // Priority 4: Group actions
        if let groupAction = GroupAction.from(itemType: itemType, groupActionType: groupActionType, otherHandle: otherHandle, groupTitle: groupTitle) {
            return .groupAction(groupAction)
        }
        
        // Priority 5: Audio message kept
        if itemType == 5 {
            return .audioMessageKept
        }
        
        // Priority 6: Location sharing
        if itemType == 4 {
            let shareStatus = ShareStatus.from(shareStatus: shareStatus, shareDirection: shareDirection)
            return .locationShare(shareStatus)
        }
        
        // Priority 7: App integrations (check balloon bundle ID)
        if associatedMessageType == 0 || associatedMessageType == 2 || associatedMessageType == 3 {
            let balloon = CustomBalloon.from(bundleId: balloonBundleId)
            if case .unknown = balloon {
                // Fall through to normal message
            } else {
                return .app(balloon)
            }
        }
        
        // Priority 8: Default to normal message
        if itemType == 0 {
            return .normal
        }
        
        // Unknown item type
        return .unknown(itemType)
    }
}

extension Message: CustomStringConvertible {
    public var description: String {
        "Message(rowid: \(rowid), guid: \(guid), text: \(effectiveText?.prefix(50) ?? "nil"), service: \(service ?? "nil"), isFromMe: \(isFromMe))"
    }
}

// MARK: - Streamtyped Parsing
extension Message {
    /// Parse text content from binary attributedBody data using streamtyped format
    private func parseStreamtypedText(from data: Data) -> String? {
        // Check if this is streamtyped data by looking for the header
        guard data.count > 12 else { return nil }
        
        let streamtypedHeader = "streamtyped".data(using: .utf8)!
        let dataPrefix = data.prefix(streamtypedHeader.count)
        
        // If it starts with "streamtyped", use the streamtyped parser
        if dataPrefix == streamtypedHeader {
            return parseStreamtypedLegacy(data: data)
        }
        
        // Try modern NSKeyedUnarchiver approach for typedstream data
        return parseTypedstream(data: data)
    }
    
    /// Parse legacy streamtyped format following Rust implementation exactly
    private func parseStreamtypedLegacy(data: Data) -> String? {
        let startPattern: [UInt8] = [0x01, 0x2B] // SOH + '+'
        let endPattern: [UInt8] = [0x86, 0x84]   // SSA + IND
        
        var bytes = Array(data)
        
        // Step 1: Find start pattern and drain everything before and including it
        var foundStart = false
        for idx in 0..<bytes.count {
            if idx + 2 > bytes.count {
                return nil // NoStartPattern
            }
            
            let part = Array(bytes[idx..<idx + 2])
            if part == startPattern {
                // Remove everything up to and including the start pattern
                bytes.removeFirst(idx + 2)
                foundStart = true
                break
            }
        }
        
        guard foundStart else { return nil }
        
        // Step 2: Find end pattern starting from position 1 and truncate there
        var foundEnd = false
        for idx in 1..<bytes.count {
            if idx >= bytes.count - 2 {
                return nil // NoEndPattern
            }
            
            let part = Array(bytes[idx..<idx + 2])
            if part == endPattern {
                // Truncate at the end pattern position
                bytes = Array(bytes[..<idx])
                foundEnd = true
                break
            }
        }
        
        guard foundEnd else { return nil }
        
        // Step 3: Convert to UTF-8 and handle prefix removal
        return extractTextWithPrefixHandling(from: bytes)
    }
    
    /// Extract text with proper prefix character removal following Rust logic exactly
    private func extractTextWithPrefixHandling(from bytes: [UInt8]) -> String? {
        let data = Data(bytes)
        
        // Match Rust: String::from_utf8(stream).map_err(|non_utf8| String::from_utf8_lossy(...))
        if let validString = String(data: data, encoding: .utf8) {
            // UTF-8 conversion succeeded: drop exactly 1 character
            return dropCharacters(1, from: validString)
        } else {
            // UTF-8 conversion failed: use lossy conversion and drop 3 characters
            let lossyString = String(decoding: data, as: UTF8.self)
            return dropCharacters(3, from: lossyString)
        }
    }
    
    /// Drop the specified number of characters from the beginning of the string
    /// Uses char_indices() equivalent to handle multi-byte UTF-8 correctly
    private func dropCharacters(_ count: Int, from string: String) -> String? {
        guard count > 0 else { return string }
        
        let characters = Array(string)
        guard characters.count > count else { return nil }
        
        let remainingCharacters = Array(characters[count...])
        let result = String(remainingCharacters)
        
        return result.isEmpty ? nil : result
    }
    
    /// Try to parse modern typedstream/NSKeyedUnarchiver format
    private func parseTypedstream(data: Data) -> String? {
        // Try NSKeyedUnarchiver for modern attributed strings
        do {
            if let attributedString = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSAttributedString {
                let text = attributedString.string
                return text.isEmpty ? nil : text
            }
        } catch {
            // Fallback to legacy parsing if NSKeyedUnarchiver fails
        }
        
        // If NSKeyedUnarchiver fails, try the legacy streamtyped parser anyway
        return parseStreamtypedLegacy(data: data)
    }
}
