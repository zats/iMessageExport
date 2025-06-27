import Foundation

/// Defines the parts of a message bubble, i.e. the content that can exist in a single message.
///
/// A single iMessage contains data that may be represented across multiple bubbles.
@frozen
public enum BubbleComponent: Sendable, Hashable, Codable {
    /// A text message with associated formatting
    case text([TextAttributes])
    /// An attachment
    case attachment(AttachmentMeta)
    /// An app integration
    case app
    /// A component that was retracted
    case retracted
}

extension BubbleComponent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .text(let attributes):
            return "Text(\(attributes.count) attributes)"
        case .attachment(let meta):
            return "Attachment(guid: \(meta.guid ?? "nil"))"
        case .app:
            return "App"
        case .retracted:
            return "Retracted"
        }
    }
}

extension BubbleComponent {
    /// Whether this component contains text content
    public var isText: Bool {
        if case .text = self { return true }
        return false
    }
    
    /// Whether this component contains an attachment
    public var isAttachment: Bool {
        if case .attachment = self { return true }
        return false
    }
    
    /// Whether this component is an app integration
    public var isApp: Bool {
        if case .app = self { return true }
        return false
    }
    
    /// Whether this component was retracted
    public var isRetracted: Bool {
        if case .retracted = self { return true }
        return false
    }
    
    /// Extract text attributes if this is a text component
    public var textAttributes: [TextAttributes]? {
        if case .text(let attributes) = self { return attributes }
        return nil
    }
    
    /// Extract attachment metadata if this is an attachment component
    public var attachmentMeta: AttachmentMeta? {
        if case .attachment(let meta) = self { return meta }
        return nil
    }
}