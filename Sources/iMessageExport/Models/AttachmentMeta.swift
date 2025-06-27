import Foundation

/// Representation of attachment metadata used for rendering message body in a conversation feed.
public struct AttachmentMeta: Sendable, Hashable, Codable {
    /// GUID of the attachment in the `attachment` table
    public let guid: String?
    /// The transcription, if the attachment was an audio message
    public let transcription: String?
    /// The height of the attachment in points
    public let height: Double?
    /// The width of the attachment in points
    public let width: Double?
    /// The attachment's original filename
    public let name: String?
    
    public init(
        guid: String? = nil,
        transcription: String? = nil,
        height: Double? = nil,
        width: Double? = nil,
        name: String? = nil
    ) {
        self.guid = guid
        self.transcription = transcription
        self.height = height
        self.width = width
        self.name = name
    }
    
    /// Whether this attachment has audio transcription available
    public var hasTranscription: Bool {
        transcription != nil && !(transcription?.isEmpty ?? true)
    }
    
    /// Whether this attachment has dimensional information
    public var hasDimensions: Bool {
        height != nil && width != nil
    }
    
    /// The aspect ratio of the attachment, if dimensions are available
    public var aspectRatio: Double? {
        guard let height = height, let width = width, height > 0 else { return nil }
        return width / height
    }
}