import Foundation

/// Example usage of the MarkdownExporter
@DatabaseActor
public enum MarkdownExportExample {
    
    /// Export a specific chat by ID to markdown
    public static func exportChatToMarkdown(chatId: Int32) async throws -> String {
        // Initialize the iMessage exporter
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        // Create markdown exporter with custom options
        let options = MarkdownExportOptions(
            attachmentsDirectory: "./attachments",
            includeReactions: true,
            includeSystemMessages: false,
            maxQuoteLength: 150
        )
        
        let markdownExporter = exporter.createMarkdownExporter(options: options)
        
        // Export the chat and return markdown string
        return try await markdownExporter.exportChat(chatId: chatId)
    }
    
    /// Export all chats and return a dictionary of chat names to markdown
    public static func exportAllChats() async throws -> [String: String] {
        // Initialize the iMessage exporter
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let chats = try await exporter.getAllChats()
        let markdownExporter = exporter.createMarkdownExporter()
        
        var results: [String: String] = [:]
        
        for chat in chats {
            let markdown = try await markdownExporter.exportChat(chatId: chat.rowid)
            results[chat.name] = markdown
        }
        
        return results
    }
    
    /// Get information about available chats
    public static func getChatList() async throws -> [(id: Int32, name: String, messageCount: Int, isGroup: Bool)] {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let chats = try await exporter.getAllChatsSortedByLastMessage()
        var chatInfo: [(id: Int32, name: String, messageCount: Int, isGroup: Bool)] = []
        
        for chat in chats.prefix(20) { // Show first 20 chats
            let stats = try await exporter.getChatStatistics(chatId: chat.rowid)
            chatInfo.append((
                id: chat.rowid,
                name: chat.name,
                messageCount: stats.messageCount,
                isGroup: chat.isGroupChat
            ))
        }
        
        return chatInfo
    }
    
    /// Export a specific conversation by phone number or identifier
    public static func exportChatByIdentifier(_ identifier: String) async throws -> String {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let markdownExporter = exporter.createMarkdownExporter()
        return try await markdownExporter.exportChat(identifier: identifier)
    }
    
    /// Export the last N messages from a chat
    public static func exportRecentMessages(chatId: Int32, messageLimit: Int) async throws -> String {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let markdownExporter = exporter.createMarkdownExporter()
        return try await markdownExporter.exportChatWithLimit(chatId: chatId, messageLimit: messageLimit)
    }
    
    /// Export messages from the last N days
    public static func exportLastDays(chatId: Int32, days: Int) async throws -> String {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let dateRange = DateRange.lastDays(days)
        let markdownExporter = exporter.createMarkdownExporter()
        return try await markdownExporter.exportChatInDateRange(chatId: chatId, dateRange: dateRange)
    }
    
    /// Export only threaded conversations (messages with replies)
    public static func exportThreadsOnly(chatId: Int32) async throws -> String {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let markdownExporter = exporter.createMarkdownExporter()
        return try await markdownExporter.exportThreadsOnly(chatId: chatId)
    }
    
    /// Export a specific thread by its originator message GUID
    public static func exportSpecificThread(chatId: Int32, threadGuid: String) async throws -> String {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        let markdownExporter = exporter.createMarkdownExporter()
        return try await markdownExporter.exportThread(threadGuid: threadGuid, chatId: chatId)
    }
    
    /// Export with custom filtering options
    public static func exportWithCustomOptions(chatId: Int32) async throws -> String {
        let exporter = try iMessageExport()
        defer { Task { await exporter.close() } }
        
        // Create custom export options
        let options = MarkdownExportOptions(
            attachmentsDirectory: "./attachments",
            includeReactions: true,
            includeSystemMessages: false,
            maxQuoteLength: 100,
            dateRange: DateRange.lastDays(7), // Only last 7 days
            messageLimit: 50, // Max 50 messages
            threadsOnly: false,
            specificThreadGuid: nil
        )
        
        let markdownExporter = exporter.createMarkdownExporter(options: options)
        return try await markdownExporter.exportChat(chatId: chatId)
    }
}