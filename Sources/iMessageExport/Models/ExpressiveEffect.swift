import Foundation

/// Expressive send effects for messages
public enum ExpressiveEffect: Sendable, Hashable, Codable {
    /// Full screen effect
    case screen(ScreenEffect)
    /// Bubble effect
    case bubble(BubbleEffect)
    /// Unknown effect
    case unknown(String)
    /// No effect
    case none
    
    /// Create from expressive_send_style_id string
    public static func from(styleId: String?) -> ExpressiveEffect {
        guard let styleId = styleId else { return .none }
        
        // Check for bubble effects first
        if let bubbleEffect = BubbleEffect.from(styleId: styleId) {
            return .bubble(bubbleEffect)
        }
        
        // Check for screen effects
        if let screenEffect = ScreenEffect.from(styleId: styleId) {
            return .screen(screenEffect)
        }
        
        return .unknown(styleId)
    }
    
    /// Whether this is no effect
    public var isNone: Bool {
        if case .none = self { return true }
        return false
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .screen(let effect):
            return "Screen: \(effect.displayName)"
        case .bubble(let effect):
            return "Bubble: \(effect.displayName)"
        case .unknown(let styleId):
            return "Unknown Effect: \(styleId)"
        case .none:
            return "No Effect"
        }
    }
}

/// Bubble effects that affect message appearance
public enum BubbleEffect: Sendable, Hashable, Codable {
    /// Slam effect (impact)
    case slam
    /// Loud effect (loud)
    case loud
    /// Gentle effect (gentle)
    case gentle
    /// Invisible ink effect (invisibleink)
    case invisibleInk
    
    /// Create from style ID string
    public static func from(styleId: String) -> BubbleEffect? {
        switch styleId.lowercased() {
        case "impact":
            return .slam
        case "loud":
            return .loud
        case "gentle":
            return .gentle
        case "invisibleink":
            return .invisibleInk
        default:
            return nil
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .slam: return "Slam"
        case .loud: return "Loud"
        case .gentle: return "Gentle"
        case .invisibleInk: return "Invisible Ink"
        }
    }
}

/// Full screen effects
public enum ScreenEffect: Sendable, Hashable, Codable {
    /// Confetti effect
    case confetti
    /// Echo effect
    case echo
    /// Fireworks effect
    case fireworks
    /// Balloons effect
    case balloons
    /// Heart effect
    case heart
    /// Lasers effect
    case lasers
    /// Shooting star effect
    case shootingStar
    /// Sparkles effect
    case sparkles
    /// Spotlight effect
    case spotlight
    
    /// Create from style ID string
    public static func from(styleId: String) -> ScreenEffect? {
        switch styleId.lowercased() {
        case "confetti":
            return .confetti
        case "echo":
            return .echo
        case "fireworks":
            return .fireworks
        case "balloons":
            return .balloons
        case "heart":
            return .heart
        case "lasers":
            return .lasers
        case "shootingstar", "shooting-star":
            return .shootingStar
        case "sparkles":
            return .sparkles
        case "spotlight":
            return .spotlight
        default:
            return nil
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .confetti: return "Confetti"
        case .echo: return "Echo"
        case .fireworks: return "Fireworks"
        case .balloons: return "Balloons"
        case .heart: return "Heart"
        case .lasers: return "Lasers"
        case .shootingStar: return "Shooting Star"
        case .sparkles: return "Sparkles"
        case .spotlight: return "Spotlight"
        }
    }
}