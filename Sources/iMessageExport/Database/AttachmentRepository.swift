import Foundation
import SQLite

/// Repository for accessing attachment data from the database
@DatabaseActor
public final class AttachmentRepository: Sendable {
    private let connection: DatabaseConnection
    
    public init(connection: DatabaseConnection) {
        self.connection = connection
    }
    
    /// Fetch all attachments from the database
    public func fetchAllAttachments() async throws -> [Attachment] {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch a specific attachment by ID
    public func fetchAttachment(withId attachmentId: Int32) async throws -> Attachment? {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            WHERE rowid = \(attachmentId)
            LIMIT 1
        """
        
        let results = try connection.execute(query)
        return results.first.flatMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch attachments for a specific message
    public func fetchAttachments(forMessageId messageId: Int32) async throws -> [Attachment] {
        let query = """
            SELECT a.ROWID as rowid, a.filename, a.uti, a.mime_type, a.transfer_name, a.total_bytes, 
                   a.is_sticker, a.hide_attachment, a.emoji_image_short_description
            FROM attachment a
            JOIN message_attachment_join maj ON a.rowid = maj.attachment_id
            WHERE maj.message_id = \(messageId)
            ORDER BY a.rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch attachments by MIME type
    public func fetchAttachments(withMimeType mimeType: String) async throws -> [Attachment] {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            WHERE mime_type = '\(mimeType)'
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch image attachments only
    public func fetchImageAttachments() async throws -> [Attachment] {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            WHERE mime_type LIKE 'image/%'
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch video attachments only
    public func fetchVideoAttachments() async throws -> [Attachment] {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            WHERE mime_type LIKE 'video/%'
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch audio attachments only
    public func fetchAudioAttachments() async throws -> [Attachment] {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            WHERE mime_type LIKE 'audio/%'
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Fetch sticker attachments only
    public func fetchStickerAttachments() async throws -> [Attachment] {
        let query = """
            SELECT ROWID as rowid, filename, uti, mime_type, transfer_name, total_bytes, 
                   is_sticker, hide_attachment, emoji_image_short_description
            FROM attachment
            WHERE is_sticker = 1
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseAttachment(from: row)
        }
    }
    
    /// Get attachment statistics
    public func getAttachmentStatistics() async throws -> AttachmentStatistics {
        let totalQuery = "SELECT COUNT(*) as total FROM attachment"
        let imageQuery = "SELECT COUNT(*) as count FROM attachment WHERE mime_type LIKE 'image/%'"
        let videoQuery = "SELECT COUNT(*) as count FROM attachment WHERE mime_type LIKE 'video/%'"
        let audioQuery = "SELECT COUNT(*) as count FROM attachment WHERE mime_type LIKE 'audio/%'"
        let stickerQuery = "SELECT COUNT(*) as count FROM attachment WHERE is_sticker = 1"
        let totalSizeQuery = "SELECT SUM(total_bytes) as total_size FROM attachment WHERE total_bytes IS NOT NULL"
        
        let totalResults = try connection.execute(totalQuery)
        let imageResults = try connection.execute(imageQuery)
        let videoResults = try connection.execute(videoQuery)
        let audioResults = try connection.execute(audioQuery)
        let stickerResults = try connection.execute(stickerQuery)
        let totalSizeResults = try connection.execute(totalSizeQuery)
        
        let total = (totalResults.first?["total"] as? Int64) ?? 0
        let imageCount = (imageResults.first?["count"] as? Int64) ?? 0
        let videoCount = (videoResults.first?["count"] as? Int64) ?? 0
        let audioCount = (audioResults.first?["count"] as? Int64) ?? 0
        let stickerCount = (stickerResults.first?["count"] as? Int64) ?? 0
        let totalSize = (totalSizeResults.first?["total_size"] as? Int64) ?? 0
        
        return AttachmentStatistics(
            totalCount: Int(total),
            imageCount: Int(imageCount),
            videoCount: Int(videoCount),
            audioCount: Int(audioCount),
            stickerCount: Int(stickerCount),
            totalSizeBytes: totalSize
        )
    }
    
    /// Parse an attachment from database row data
    private func parseAttachment(from row: [String: Any]) -> Attachment? {
        guard let rowid = row["rowid"] as? Int64 else {
            return nil
        }
        
        return Attachment(
            rowid: Int32(rowid),
            filename: row["filename"] as? String,
            uti: row["uti"] as? String,
            mimeType: row["mime_type"] as? String,
            transferName: row["transfer_name"] as? String,
            totalBytes: row["total_bytes"] as? Int64,
            isSticker: ((row["is_sticker"] as? Int64) ?? 0) != 0,
            hideAttachment: ((row["hide_attachment"] as? Int64) ?? 0) != 0,
            emojiImageShortDescription: row["emoji_image_short_description"] as? String
        )
    }
}

/// Statistics for attachments
public struct AttachmentStatistics: Sendable, Hashable, Codable {
    /// Total number of attachments
    public let totalCount: Int
    /// Number of image attachments
    public let imageCount: Int
    /// Number of video attachments
    public let videoCount: Int
    /// Number of audio attachments
    public let audioCount: Int
    /// Number of sticker attachments
    public let stickerCount: Int
    /// Total size of all attachments in bytes
    public let totalSizeBytes: Int64
    
    /// Formatted total size string
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
    
    public init(
        totalCount: Int,
        imageCount: Int,
        videoCount: Int,
        audioCount: Int,
        stickerCount: Int,
        totalSizeBytes: Int64
    ) {
        self.totalCount = totalCount
        self.imageCount = imageCount
        self.videoCount = videoCount
        self.audioCount = audioCount
        self.stickerCount = stickerCount
        self.totalSizeBytes = totalSizeBytes
    }
}