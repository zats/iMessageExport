import Foundation
import SQLite

/// Repository for accessing message data from the database
@DatabaseActor
public final class MessageRepository: Sendable {
    private let connection: DatabaseConnection
    
    public init(connection: DatabaseConnection) {
        self.connection = connection
    }
    
    /// Fetch all messages from the database
    public func fetchAllMessages() async throws -> [Message] {
        let query = """
            SELECT 
                m.ROWID as rowid, m.guid, m.text, m.attributedBody, m.service, m.handle_id, m.destination_caller_id, 
                m.subject, m.date, m.date_read, m.date_delivered, m.is_from_me, m.is_read, 
                m.item_type, m.other_handle, m.share_status, m.share_direction, m.group_title, 
                m.group_action_type, m.associated_message_guid, m.associated_message_type, 
                m.balloon_bundle_id, m.expressive_send_style_id, m.thread_originator_guid, 
                m.thread_originator_part, m.date_edited, m.associated_message_emoji,
                c.chat_id,
                (SELECT COUNT(*) FROM message_attachment_join a WHERE m.ROWID = a.message_id) as num_attachments,
                d.chat_id as deleted_from,
                (SELECT COUNT(*) FROM message m2 WHERE m2.thread_originator_guid = m.guid) as num_replies
            FROM message as m
            LEFT JOIN chat_message_join as c ON m.ROWID = c.message_id
            LEFT JOIN chat_recoverable_message_join as d ON m.ROWID = d.message_id
            ORDER BY m.date
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseMessage(from: row)
        }
    }
    
    /// Fetch messages for a specific chat
    public func fetchMessages(forChatId chatId: Int32) async throws -> [Message] {
        let query = """
            SELECT 
                m.ROWID as rowid, m.guid, m.text, m.attributedBody, m.service, m.handle_id, m.destination_caller_id, 
                m.subject, m.date, m.date_read, m.date_delivered, m.is_from_me, m.is_read, 
                m.item_type, m.other_handle, m.share_status, m.share_direction, m.group_title, 
                m.group_action_type, m.associated_message_guid, m.associated_message_type, 
                m.balloon_bundle_id, m.expressive_send_style_id, m.thread_originator_guid, 
                m.thread_originator_part, m.date_edited, m.associated_message_emoji,
                c.chat_id,
                (SELECT COUNT(*) FROM message_attachment_join a WHERE m.ROWID = a.message_id) as num_attachments,
                d.chat_id as deleted_from,
                (SELECT COUNT(*) FROM message m2 WHERE m2.thread_originator_guid = m.guid) as num_replies
            FROM message as m
            LEFT JOIN chat_message_join as c ON m.ROWID = c.message_id
            LEFT JOIN chat_recoverable_message_join as d ON m.ROWID = d.message_id
            WHERE c.chat_id = \(chatId)
            ORDER BY m.date
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseMessage(from: row)
        }
    }
    
    /// Fetch a specific message by GUID
    public func fetchMessage(withGuid guid: String) async throws -> Message? {
        let query = """
            SELECT 
                m.ROWID as rowid, m.guid, m.text, m.attributedBody, m.service, m.handle_id, m.destination_caller_id, 
                m.subject, m.date, m.date_read, m.date_delivered, m.is_from_me, m.is_read, 
                m.item_type, m.other_handle, m.share_status, m.share_direction, m.group_title, 
                m.group_action_type, m.associated_message_guid, m.associated_message_type, 
                m.balloon_bundle_id, m.expressive_send_style_id, m.thread_originator_guid, 
                m.thread_originator_part, m.date_edited, m.associated_message_emoji,
                c.chat_id,
                (SELECT COUNT(*) FROM message_attachment_join a WHERE m.ROWID = a.message_id) as num_attachments,
                d.chat_id as deleted_from,
                (SELECT COUNT(*) FROM message m2 WHERE m2.thread_originator_guid = m.guid) as num_replies
            FROM message as m
            LEFT JOIN chat_message_join as c ON m.ROWID = c.message_id
            LEFT JOIN chat_recoverable_message_join as d ON m.ROWID = d.message_id
            WHERE m.guid = '\(guid)'
            LIMIT 1
        """
        
        let results = try connection.execute(query)
        return results.first.flatMap { row in
            parseMessage(from: row)
        }
    }
    
    /// Fetch messages with attachments
    public func fetchMessagesWithAttachments() async throws -> [Message] {
        let query = """
            SELECT 
                m.ROWID as rowid, m.guid, m.text, m.attributedBody, m.service, m.handle_id, m.destination_caller_id, 
                m.subject, m.date, m.date_read, m.date_delivered, m.is_from_me, m.is_read, 
                m.item_type, m.other_handle, m.share_status, m.share_direction, m.group_title, 
                m.group_action_type, m.associated_message_guid, m.associated_message_type, 
                m.balloon_bundle_id, m.expressive_send_style_id, m.thread_originator_guid, 
                m.thread_originator_part, m.date_edited, m.associated_message_emoji,
                c.chat_id,
                (SELECT COUNT(*) FROM message_attachment_join a WHERE m.ROWID = a.message_id) as num_attachments,
                d.chat_id as deleted_from,
                (SELECT COUNT(*) FROM message m2 WHERE m2.thread_originator_guid = m.guid) as num_replies
            FROM message as m
            LEFT JOIN chat_message_join as c ON m.ROWID = c.message_id
            LEFT JOIN chat_recoverable_message_join as d ON m.ROWID = d.message_id
            WHERE EXISTS (SELECT 1 FROM message_attachment_join a WHERE m.ROWID = a.message_id)
            ORDER BY m.date
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseMessage(from: row)
        }
    }
    
    /// Parse a message from database row data
    private func parseMessage(from row: [String: Any]) -> Message? {
        guard let rowid = row["rowid"] as? Int64,
              let guid = row["guid"] as? String,
              let date = row["date"] as? Int64,
              let isFromMe = row["is_from_me"] as? Int64 else {
            return nil
        }
        
        func data(from value: Any?) -> Data? {
            guard let value else { return nil }
            if let value = value as? Data {
                return value
            } else if let value = value as? Blob {
                return Data(value.bytes)
            }
            return nil
        }
        
        return Message(
            rowid: Int32(rowid),
            guid: guid,
            text: row["text"] as? String,
            attributedBody: data(from: row["attributedBody"]),
            service: row["service"] as? String,
            handleId: (row["handle_id"] as? Int64).map(Int32.init),
            destinationCallerId: row["destination_caller_id"] as? String,
            subject: row["subject"] as? String,
            date: date,
            dateRead: (row["date_read"] as? Int64) ?? 0,
            dateDelivered: (row["date_delivered"] as? Int64) ?? 0,
            isFromMe: isFromMe != 0,
            isRead: ((row["is_read"] as? Int64) ?? 0) != 0,
            itemType: Int32((row["item_type"] as? Int64) ?? 0),
            otherHandle: (row["other_handle"] as? Int64).map(Int32.init),
            shareStatus: ((row["share_status"] as? Int64) ?? 0) != 0,
            shareDirection: (row["share_direction"] as? Int64).map { $0 != 0 },
            groupTitle: row["group_title"] as? String,
            groupActionType: Int32((row["group_action_type"] as? Int64) ?? 0),
            associatedMessageGuid: row["associated_message_guid"] as? String,
            associatedMessageType: Int32((row["associated_message_type"] as? Int64) ?? 0),
            balloonBundleId: row["balloon_bundle_id"] as? String,
            expressiveSendStyleId: row["expressive_send_style_id"] as? String,
            threadOriginatorGuid: row["thread_originator_guid"] as? String,
            threadOriginatorPart: row["thread_originator_part"] as? String,
            dateEdited: row["date_edited"] as? Int64,
            associatedMessageEmoji: row["associated_message_emoji"] as? String,
            chatId: (row["chat_id"] as? Int64).map(Int32.init),
            numAttachments: Int32((row["num_attachments"] as? Int64) ?? 0),
            deletedFrom: (row["deleted_from"] as? Int64).map(Int32.init),
            numReplies: Int32((row["num_replies"] as? Int64) ?? 0)
        )
    }
}
