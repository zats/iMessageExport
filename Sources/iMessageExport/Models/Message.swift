@_exported import Foundation

/// Group actions that can be performed in a chat
@frozen
public enum GroupAction: Int32, Sendable, Hashable, Codable, CaseIterable {
    case none = 0
    case addMember = 1
    case removeMember = 2
    case changeName = 3
    case changePhoto = 4
    case leaveGroup = 5
}

/// Tapback actions for reacting to messages
@frozen
public enum TapbackAction: Int32, Sendable, Hashable, Codable, CaseIterable {
    case none = 0
    case love = 2000
    case like = 2001
    case dislike = 2002
    case laugh = 2003
    case emphasize = 2004
    case question = 2005
    
    /// Remove reactions
    case removeLove = 3000
    case removeLike = 3001
    case removeDislike = 3002
    case removeLaugh = 3003
    case removeEmphasize = 3004
    case removeQuestion = 3005
}

/// Message variants that determine the type and behavior of a message
@frozen
public enum MessageVariant: Sendable, Hashable, Codable {
    /// Regular text message
    case text
    /// Message with attachments
    case attachment
    /// Group chat announcement
    case announcement(GroupAction)
    /// Tapback reaction to another message
    case tapback(TapbackAction, String) // action, target message GUID
    /// Sticker message
    case sticker
    /// App integration message
    case app(String?) // bundle ID
    /// Digital touch message
    case digitalTouch
    /// Handwriting message
    case handwriting
    /// Music/media sharing
    case music
    /// Location sharing
    case location
    /// Edited message
    case edited(String?) // original message GUID
    /// Unknown message type
    case unknown(Int32) // item_type
}

/// Edit status for messages
@frozen
public enum EditStatus: Sendable, Hashable, Codable {
    /// Message was not edited
    case notEdited
    /// Message was edited
    case edited
    /// Message was unsent/deleted
    case unsent
}

/// Expressive send effects
@frozen
public enum ExpressiveEffect: String, Sendable, Hashable, Codable, CaseIterable {
    case none = ""
    case slam = "com.apple.MobileSMS.expressivesend.impact"
    case loud = "com.apple.MobileSMS.expressivesend.loud"
    case gentle = "com.apple.MobileSMS.expressivesend.gentle"
    case invisibleInk = "com.apple.messages.effect.CKInvisibleInkBalloonView"
}

/// Represents a single row in the `message` table.
public struct Message: Sendable, Hashable, Codable, Identifiable {
    /// The unique identifier for the message in the database
    public let rowid: Int32
    /// The globally unique identifier for the message
    public let guid: String
    /// The text of the message
    public let text: String?
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
    
    /// The group action for this message
    public var groupAction: GroupAction {
        GroupAction(rawValue: groupActionType) ?? .none
    }
    
    /// The tapback action for this message
    public var tapbackAction: TapbackAction? {
        TapbackAction(rawValue: associatedMessageType)
    }
    
    /// The expressive effect for this message
    public var expressiveEffect: ExpressiveEffect {
        ExpressiveEffect(rawValue: expressiveSendStyleId ?? "") ?? .none
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
    
    /// Whether this message is a group action
    public var isGroupAction: Bool {
        groupAction != .none
    }
    
    /// Whether this message is a tapback reaction
    public var isTapback: Bool {
        tapbackAction != nil
    }
    
    /// Whether this message has expressive effects
    public var hasExpressiveEffect: Bool {
        expressiveEffect != .none
    }
    
    /// Whether this message was deleted
    public var wasDeleted: Bool {
        deletedFrom != nil
    }
    
    /// Message variant based on item type and other properties
    public var variant: MessageVariant {
        if isTapback, let action = tapbackAction, let targetGuid = associatedMessageGuid {
            return .tapback(action, targetGuid)
        }
        
        if isGroupAction {
            return .announcement(groupAction)
        }
        
        if hasAttachments {
            return .attachment
        }
        
        if let bundleId = balloonBundleId, !bundleId.isEmpty {
            return .app(bundleId)
        }
        
        if wasEdited {
            return .edited(associatedMessageGuid)
        }
        
        switch itemType {
        case 0:
            return .text
        case 1:
            return .attachment
        case 2:
            return .location
        case 3:
            return .announcement(groupAction)
        case 5:
            return .sticker
        default:
            return .unknown(itemType)
        }
    }
}

extension Message: CustomStringConvertible {
    public var description: String {
        "Message(rowid: \(rowid), guid: \(guid), text: \(text?.prefix(50) ?? "nil"), service: \(service ?? "nil"), isFromMe: \(isFromMe))"
    }
}