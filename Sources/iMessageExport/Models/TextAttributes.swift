@_exported import Foundation

/// Defines ranges of text and associated attributes parsed from `attributedBody` data.
///
/// Ranges specify locations where attributes are applied to specific portions of a Message's text.
/// For example, given message text with a mention like "What's up, Christopher?",
/// there will be 3 ranges covering the plain text, the mention, and the final punctuation.
public struct TextAttributes: Sendable, Hashable, Codable {
    /// The start index of the affected range of message text
    public let start: Int
    /// The end index of the affected range of message text
    public let end: Int
    /// The effects applied to the specified range
    public let effects: [TextEffect]
    
    /// Creates a new TextAttributes with the specified start index, end index, and text effects.
    public init(start: Int, end: Int, effects: [TextEffect]) {
        self.start = start
        self.end = end
        self.effects = effects
    }
    
    /// The range of text affected by these attributes
    public var range: Range<Int> {
        start..<end
    }
    
    /// The length of the affected text range
    public var length: Int {
        end - start
    }
}

/// Text effects that can be applied to message text
@frozen
public enum TextEffect: Sendable, Hashable, Codable {
    /// Default text with no special formatting
    case `default`
    /// Bold text
    case bold
    /// Italic text
    case italic
    /// Underlined text
    case underline
    /// Strikethrough text
    case strikethrough
    /// A mention of a contact (contains phone number or email)
    case mention(String)
    /// A clickable link
    case link(URL)
    /// Text with a specific font
    case font(String)
    /// Text with a specific color (hex format)
    case color(String)
    /// Other unknown text effect
    case other(String)
}

extension TextEffect: CustomStringConvertible {
    public var description: String {
        switch self {
        case .default:
            return "Default"

        case .bold:
            return "Bold"

        case .italic:
            return "Italic"

        case .underline:
            return "Underline"

        case .strikethrough:
            return "Strikethrough"

        case .mention(let contact):
            return "Mention(\(contact))"

        case .link(let url):
            return "Link(\(url))"

        case .font(let fontName):
            return "Font(\(fontName))"

        case .color(let colorHex):
            return "Color(\(colorHex))"

        case .other(let effect):
            return "Other(\(effect))"
        }
    }
}
