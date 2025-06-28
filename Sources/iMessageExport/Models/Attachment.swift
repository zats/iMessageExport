import Foundation
import UniformTypeIdentifiers

/// Represents the MIME type of a message's attachment data
@frozen
public enum MediaType: Sendable, Hashable, Codable {
    /// Image MIME type, such as "image/png" or "image/jpeg"
    case image(String)
    /// Video MIME type, such as "video/mp4" or "video/quicktime"
    case video(String)
    /// Audio MIME type, such as "audio/mp3" or "audio/x-m4a"
    case audio(String)
    /// Text MIME type, such as "text/plain" or "text/html"
    case text(String)
    /// Application MIME type, such as "application/pdf" or "application/json"
    case application(String)
    /// Other MIME types that don't fit the standard categories
    case other(String)
    /// Unknown MIME type when the type could not be determined
    case unknown
    
    /// Given a MediaType, generate the corresponding MIME type string
    public var mimeType: String {
        switch self {
        case .image(let subtype):
            return "image/\(subtype)"

        case .video(let subtype):
            return "video/\(subtype)"

        case .audio(let subtype):
            return "audio/\(subtype)"

        case .text(let subtype):
            return "text/\(subtype)"

        case .application(let subtype):
            return "application/\(subtype)"

        case .other(let mime):
            return mime

        case .unknown:
            return ""
        }
    }
    
    /// Create a MediaType from a MIME type string
    public static func from(mimeType: String?) -> MediaType {
        guard let mimeType = mimeType else { return .unknown }
        
        let components = mimeType.split(separator: "/", maxSplits: 1)
        guard components.count == 2 else { return .other(mimeType) }
        
        let type = String(components[0]).lowercased()
        let subtype = String(components[1])
        
        switch type {
        case "image":
            return .image(subtype)

        case "video":
            return .video(subtype)

        case "audio":
            return .audio(subtype)

        case "text":
            return .text(subtype)

        case "application":
            return .application(subtype)

        default:
            return .other(mimeType)
        }
    }
}

/// Sticker effects that can be applied to images
@frozen
public enum StickerEffect: String, Sendable, Hashable, Codable, CaseIterable {
    case none = "none"
    case outline = "outline"
    case comic = "comic"
    case puffy = "puffy"
    case shiny = "shiny"
}

/// The source of a sticker
@frozen
public enum StickerSource: Sendable, Hashable, Codable {
    /// Built-in system stickers
    case system
    /// Third-party app stickers
    case app(String)
    /// User-created stickers
    case user
    /// Unknown source
    case unknown
}

/// Represents a single row in the `attachment` table.
public struct Attachment: Sendable, Hashable, Codable, Identifiable {
    /// The unique identifier for the attachment in the database
    public let rowid: Int32
    /// The original filename of the attachment
    public let filename: String?
    /// The Uniform Type Identifier
    public let uti: String?
    /// The MIME type of the attachment
    public let mimeType: String?
    /// The transfer name used during transmission
    public let transferName: String?
    /// The total size of the attachment in bytes
    public let totalBytes: Int64?
    /// Whether this attachment is a sticker
    public let isSticker: Bool
    /// Whether this attachment should be hidden
    public let hideAttachment: Bool
    /// Short description for emoji images
    public let emojiImageShortDescription: String?
    
    public var id: Int32 { rowid }
    
    public init(
        rowid: Int32,
        filename: String? = nil,
        uti: String? = nil,
        mimeType: String? = nil,
        transferName: String? = nil,
        totalBytes: Int64? = nil,
        isSticker: Bool = false,
        hideAttachment: Bool = false,
        emojiImageShortDescription: String? = nil
    ) {
        self.rowid = rowid
        self.filename = filename
        self.uti = uti
        self.mimeType = mimeType
        self.transferName = transferName
        self.totalBytes = totalBytes
        self.isSticker = isSticker
        self.hideAttachment = hideAttachment
        self.emojiImageShortDescription = emojiImageShortDescription
    }
    
    /// The media type of this attachment
    public var mediaType: MediaType {
        MediaType.from(mimeType: mimeType)
    }
    
    /// The file extension derived from the filename or UTI
    public var fileExtension: String? {
        if let filename = filename {
            return URL(fileURLWithPath: filename).pathExtension
        }
        
        if let uti = uti,
           let utType = UTType(uti),
           let preferredExtension = utType.preferredFilenameExtension {
            return preferredExtension
        }
        
        return nil
    }
    
    /// Whether this attachment is an image
    public var isImage: Bool {
        if case .image = mediaType { return true }
        return false
    }
    
    /// Whether this attachment is a video
    public var isVideo: Bool {
        if case .video = mediaType { return true }
        return false
    }
    
    /// Whether this attachment is audio
    public var isAudio: Bool {
        if case .audio = mediaType { return true }
        return false
    }
    
    /// Formatted file size string
    public var formattedFileSize: String? {
        guard let bytes = totalBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    /// The display name for this attachment
    public var displayName: String {
        filename ?? transferName ?? "Attachment \(rowid)"
    }
}

extension Attachment: CustomStringConvertible {
    public var description: String {
        "Attachment(rowid: \(rowid), filename: \(filename ?? "nil"), mimeType: \(mimeType ?? "nil"), size: \(totalBytes ?? 0) bytes)"
    }
}
