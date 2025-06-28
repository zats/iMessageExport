import Foundation

/// Main classification enum for different types of iMessage content
public enum MessageVariant: Sendable, Hashable, Codable {
    /// Regular text message or attachment
    case normal
    /// Edited or unsent message
    case edited
    /// Reaction (tapback) to another message
    case tapback(TapbackAction, Tapback)
    /// App integration message
    case app(CustomBalloon)
    /// SharePlay session message
    case sharePlay
    /// Group management action
    case groupAction(GroupAction)
    /// Audio message kept notification
    case audioMessageKept
    /// Location sharing message
    case locationShare(ShareStatus)
    /// Unknown message type
    case unknown(Int32)
    
    /// Whether this variant represents a reaction/tapback
    public var isReaction: Bool {
        if case .tapback = self { return true }
        return false
    }
    
    /// Whether this variant represents a group announcement
    public var isAnnouncement: Bool {
        if case .groupAction = self { return true }
        return false
    }
    
    /// Whether this variant represents an app integration
    public var isApp: Bool {
        if case .app = self { return true }
        return false
    }
    
    /// Whether this variant represents a normal message
    public var isNormal: Bool {
        if case .normal = self { return true }
        return false
    }
    
    /// Whether this variant represents an edited message
    public var isEdited: Bool {
        if case .edited = self { return true }
        return false
    }
    
    /// User-friendly description
    public var description: String {
        switch self {
        case .normal:
            return "Normal Message"

        case .edited:
            return "Edited Message"

        case .tapback(let action, let tapback):
            return "\(action == .added ? "Added" : "Removed") \(tapback.displayName)"

        case .app(let balloon):
            return "App: \(balloon.displayName)"

        case .sharePlay:
            return "SharePlay"

        case .groupAction(let action):
            return "Group: \(action.description)"

        case .audioMessageKept:
            return "Audio Message Kept"

        case .locationShare(let status):
            return "Location: \(status)"

        case .unknown(let itemType):
            return "Unknown (\(itemType))"
        }
    }
}

/// Action type for tapback reactions
public enum TapbackAction: Sendable, Hashable, Codable {
    /// Tapback was added
    case added
    /// Tapback was removed
    case removed
}

/// Types of tapback reactions
public enum Tapback: Sendable, Hashable, Codable {
    /// Heart reaction (2000/3000)
    case loved
    /// Thumbs up reaction (2001/3001)
    case liked
    /// Thumbs down reaction (2002/3002)
    case disliked
    /// Laughing face reaction (2003/3003)
    case laughed
    /// Exclamation points reaction (2004/3004)
    case emphasized
    /// Question marks reaction (2005/3005)
    case questioned
    /// Custom emoji reaction (2006/3006)
    case emoji(String?)
    /// Sticker reaction (1000/2007/3007)
    case sticker
    
    /// Create tapback from associated_message_type
    public static func from(associatedMessageType: Int32, emoji: String? = nil) -> (TapbackAction, Tapback)? {
        switch associatedMessageType {
        case 1000:
            return (.added, .sticker)

        case 2000:
            return (.added, .loved)

        case 2001:
            return (.added, .liked)

        case 2002:
            return (.added, .disliked)

        case 2003:
            return (.added, .laughed)

        case 2004:
            return (.added, .emphasized)

        case 2005:
            return (.added, .questioned)

        case 2006:
            return (.added, .emoji(emoji))

        case 2007:
            return (.added, .sticker)

        case 3000:
            return (.removed, .loved)

        case 3001:
            return (.removed, .liked)

        case 3002:
            return (.removed, .disliked)

        case 3003:
            return (.removed, .laughed)

        case 3004:
            return (.removed, .emphasized)

        case 3005:
            return (.removed, .questioned)

        case 3006:
            return (.removed, .emoji(emoji))

        case 3007:
            return (.removed, .sticker)

        default:
            return nil
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .loved: return "❤️"
        case .liked: return "👍"
        case .disliked: return "👎"
        case .laughed: return "😂"
        case .emphasized: return "‼️"
        case .questioned: return "❓"
        case .emoji(let emoji): return emoji ?? "😀"
        case .sticker: return "Sticker"
        }
    }
}

/// Group management actions
public enum GroupAction: Sendable, Hashable, Codable {
    /// Participant was added to group (item_type=1, group_action_type=0)
    case participantAdded(handleId: Int32)
    /// Participant was removed from group (item_type=1, group_action_type=1)
    case participantRemoved(handleId: Int32)
    /// Group name was changed (item_type=2)
    case nameChanged(String?)
    /// Participant left the group (item_type=3, group_action_type=0)
    case participantLeft
    /// Group icon was changed (item_type=3, group_action_type=1)
    case iconChanged
    /// Group icon was removed (item_type=3, group_action_type=2)
    case iconRemoved
    
    /// Create group action from item_type and group_action_type
    public static func from(itemType: Int32, groupActionType: Int32, otherHandle: Int32?, groupTitle: String?) -> GroupAction? {
        switch (itemType, groupActionType) {
        case (1, 0):
            return .participantAdded(handleId: otherHandle ?? 0)

        case (1, 1):
            return .participantRemoved(handleId: otherHandle ?? 0)

        case (2, _):
            return .nameChanged(groupTitle)

        case (3, 0):
            return .participantLeft

        case (3, 1):
            return .iconChanged

        case (3, 2):
            return .iconRemoved

        default:
            return nil
        }
    }
    
    /// User-friendly description
    public var description: String {
        switch self {
        case .participantAdded(let handleId):
            return "Added participant (handle: \(handleId))"

        case .participantRemoved(let handleId):
            return "Removed participant (handle: \(handleId))"

        case .nameChanged(let name):
            return "Changed group name to \"\(name ?? "Unknown")\""

        case .participantLeft:
            return "Left the group"

        case .iconChanged:
            return "Changed group icon"

        case .iconRemoved:
            return "Removed group icon"
        }
    }
}

/// App balloon/integration types
public enum CustomBalloon: Sendable, Hashable, Codable {
    /// URL preview
    case url
    /// Handwritten message
    case handwriting
    /// Digital Touch message
    case digitalTouch
    /// Apple Pay transaction
    case applePay
    /// Fitness app integration
    case fitness
    /// Photos slideshow
    case slideshow
    /// Check In safety feature
    case checkIn
    /// Find My app integration
    case findMy
    /// App Store app integration
    case appStore
    /// Music app integration
    case music
    /// Game integration
    case game
    /// Business message
    case business
    /// Third-party app
    case application(String)
    /// Unknown balloon type
    case unknown(String?)
    
    /// Create balloon type from bundle ID
    public static func from(bundleId: String?) -> CustomBalloon {
        guard let bundleId = bundleId else { return .unknown(nil) }
        
        // Map bundle IDs to balloon types based on Rust implementation
        switch bundleId {
        case "com.apple.messages.URLBalloonProvider":
            return .url

        case "com.apple.Handwriting.HandwritingProvider":
            return .handwriting

        case "com.apple.DigitalTouchBalloonProvider":
            return .digitalTouch

        case "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.PassbookUIService.PeerPaymentMessagesExtension":
            return .applePay

        case "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.Fitness.FitnessMessagesExtension":
            return .fitness

        case "com.apple.messages.PhotosBalloonProvider":
            return .slideshow

        case "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.SharingViewService.SharingMessagesExtension":
            return .checkIn

        case "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.findmy.FindMyMessagesExtension":
            return .findMy

        case "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.AppStore.MessagesExtension":
            return .appStore

        case "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.Music.MessagesExtension":
            return .music

        case let id where id.contains("GameCenter"):
            return .game

        case let id where id.contains("Business"):
            return .business

        default:
            return .application(bundleId)
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .url: return "URL"
        case .handwriting: return "Handwriting"
        case .digitalTouch: return "Digital Touch"
        case .applePay: return "Apple Pay"
        case .fitness: return "Fitness"
        case .slideshow: return "Photos"
        case .checkIn: return "Check In"
        case .findMy: return "Find My"
        case .appStore: return "App Store"
        case .music: return "Music"
        case .game: return "Game"
        case .business: return "Business"
        case .application(let bundleId): return "App (\(bundleId))"
        case .unknown(let bundleId): return "Unknown (\(bundleId ?? "nil"))"
        }
    }
}

/// Location sharing status
public enum ShareStatus: Sendable, Hashable, Codable {
    /// Not shared
    case notShared
    /// Currently sharing
    case sharing
    /// Sharing ended
    case ended
    /// Unknown status
    case unknown(Bool)
    
    /// Create from share_status boolean
    public static func from(shareStatus: Bool, shareDirection: Bool?) -> ShareStatus {
        switch (shareStatus, shareDirection) {
        case (false, _):
            return .notShared

        case (true, true):
            return .sharing

        case (true, false):
            return .ended

        case (true, nil):
            return .unknown(true)
        }
    }
}
