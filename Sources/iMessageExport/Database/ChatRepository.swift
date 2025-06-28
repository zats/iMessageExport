import Foundation
import SQLite

/// Repository for accessing chat data from the database
@DatabaseActor
public final class ChatRepository: Sendable {
    private let connection: DatabaseConnection
    
    public init(connection: DatabaseConnection) {
        self.connection = connection
    }
    
    /// Fetch all chats from the database
    public func fetchAllChats() async throws -> [Chat] {
        let query = """
            SELECT ROWID as rowid, chat_identifier, service_name, display_name, properties
            FROM chat
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseChat(from: row)
        }
    }
    
    /// Fetch all chats sorted by last message time (most recent first)
    public func fetchAllChatsSortedByLastMessage() async throws -> [Chat] {
        let query = """
            SELECT c.ROWID as rowid, c.chat_identifier, c.service_name, c.display_name, c.properties
            FROM chat c
            LEFT JOIN chat_message_join cmj ON c.ROWID = cmj.chat_id
            LEFT JOIN message m ON cmj.message_id = m.ROWID
            GROUP BY c.ROWID
            ORDER BY MAX(m.date) DESC NULLS LAST
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseChat(from: row)
        }
    }
    
    /// Fetch a specific chat by ID
    public func fetchChat(withId chatId: Int32) async throws -> Chat? {
        let query = """
            SELECT ROWID as rowid, chat_identifier, service_name, display_name, properties
            FROM chat
            WHERE rowid = \(chatId)
            LIMIT 1
        """
        
        let results = try connection.execute(query)
        return results.first.flatMap { row in
            parseChat(from: row)
        }
    }
    
    /// Fetch a chat by its identifier
    public func fetchChat(withIdentifier identifier: String) async throws -> Chat? {
        let query = """
            SELECT ROWID as rowid, chat_identifier, service_name, display_name, properties
            FROM chat
            WHERE chat_identifier = '\(identifier)'
            LIMIT 1
        """
        
        let results = try connection.execute(query)
        return results.first.flatMap { row in
            parseChat(from: row)
        }
    }
    
    /// Fetch group chats only
    public func fetchGroupChats() async throws -> [Chat] {
        let query = """
            SELECT ROWID as rowid, chat_identifier, service_name, display_name, properties
            FROM chat
            WHERE chat_identifier LIKE 'chat%'
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseChat(from: row)
        }
    }
    
    /// Fetch direct message chats only
    public func fetchDirectMessageChats() async throws -> [Chat] {
        let query = """
            SELECT ROWID as rowid, chat_identifier, service_name, display_name, properties
            FROM chat
            WHERE chat_identifier NOT LIKE 'chat%'
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseChat(from: row)
        }
    }
    
    /// Get chat statistics
    public func getChatStatistics(chatId: Int32) async throws -> ChatStatistics {
        let messageCountQuery = """
            SELECT COUNT(*) as message_count
            FROM message m
            JOIN chat_message_join c ON m.rowid = c.message_id
            WHERE c.chat_id = \(chatId)
        """
        
        let attachmentCountQuery = """
            SELECT COUNT(*) as attachment_count
            FROM message m
            JOIN chat_message_join c ON m.rowid = c.message_id
            JOIN message_attachment_join a ON m.rowid = a.message_id
            WHERE c.chat_id = \(chatId)
        """
        
        let participantCountQuery = """
            SELECT COUNT(DISTINCT handle_id) as participant_count
            FROM message m
            JOIN chat_message_join c ON m.rowid = c.message_id
            WHERE c.chat_id = \(chatId) AND handle_id IS NOT NULL
        """
        
        let messageResults = try connection.execute(messageCountQuery)
        let attachmentResults = try connection.execute(attachmentCountQuery)
        let participantResults = try connection.execute(participantCountQuery)
        
        let messageCount = (messageResults.first?["message_count"] as? Int64) ?? 0
        let attachmentCount = (attachmentResults.first?["attachment_count"] as? Int64) ?? 0
        let participantCount = (participantResults.first?["participant_count"] as? Int64) ?? 0
        
        return ChatStatistics(
            messageCount: Int(messageCount),
            attachmentCount: Int(attachmentCount),
            participantCount: Int(participantCount)
        )
    }
    
    /// Parse a chat from database row data
    private func parseChat(from row: [String: Any]) -> Chat? {
        guard let rowid = row["rowid"] as? Int64,
              let chatIdentifier = row["chat_identifier"] as? String else {
            return nil
        }
        
        // Parse properties if available
        var properties: ChatProperties?
        if let propertiesData = row["properties"] as? Data {
            properties = parseChatProperties(from: propertiesData)
        }
        
        return Chat(
            rowid: Int32(rowid),
            chatIdentifier: chatIdentifier,
            serviceName: row["service_name"] as? String,
            displayName: row["display_name"] as? String,
            properties: properties
        )
    }
    
    /// Parse chat properties from plist data
    private func parseChatProperties(from data: Data) -> ChatProperties? {
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                return ChatProperties(
                    readReceiptsEnabled: plist["EnableReadReceiptForChat"] as? Bool ?? false,
                    lastMessageGuid: plist["lastSeenMessageGuid"] as? String,
                    forcedSms: plist["shouldForceToSMS"] as? Bool ?? false,
                    groupPhotoGuid: plist["groupPhotoGuid"] as? String
                )
            }
        } catch {
            // Failed to parse plist, return nil
        }
        return nil
    }
}

/// Statistics for a chat
public struct ChatStatistics: Sendable, Hashable, Codable {
    /// Total number of messages in the chat
    public let messageCount: Int
    /// Total number of attachments in the chat
    public let attachmentCount: Int
    /// Number of unique participants in the chat
    public let participantCount: Int
    
    public init(messageCount: Int, attachmentCount: Int, participantCount: Int) {
        self.messageCount = messageCount
        self.attachmentCount = attachmentCount
        self.participantCount = participantCount
    }
}