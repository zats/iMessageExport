import Foundation

/// Configuration options for markdown export
public struct MarkdownExportOptions: Sendable {
    /// Directory path where attachment files should be copied
    public let attachmentsDirectory: String
    /// Whether to include reactions in the export
    public let includeReactions: Bool
    /// Whether to include system messages and announcements
    public let includeSystemMessages: Bool
    /// Whether to sanitize usernames by removing special characters
    public let sanitizeUsernames: Bool
    /// Maximum length for quoted message context (0 = unlimited)
    public let maxQuoteLength: Int
    /// Date range filter for messages
    public let dateRange: DateRange?
    /// Maximum number of messages to export (0 = unlimited)
    public let messageLimit: Int
    /// Whether to include only messages that are part of threads
    public let threadsOnly: Bool
    /// Specific thread originator GUID to export (nil = all threads)
    public let specificThreadGuid: String?
    
    public init(
        attachmentsDirectory: String = "./attachments",
        includeReactions: Bool = true,
        includeSystemMessages: Bool = false,
        sanitizeUsernames: Bool = true,
        maxQuoteLength: Int = 150,
        dateRange: DateRange? = nil,
        messageLimit: Int = 0,
        threadsOnly: Bool = false,
        specificThreadGuid: String? = nil
    ) {
        self.attachmentsDirectory = attachmentsDirectory
        self.includeReactions = includeReactions
        self.includeSystemMessages = includeSystemMessages
        self.sanitizeUsernames = sanitizeUsernames
        self.maxQuoteLength = maxQuoteLength
        self.dateRange = dateRange
        self.messageLimit = messageLimit
        self.threadsOnly = threadsOnly
        self.specificThreadGuid = specificThreadGuid
    }
}

/// Date range for filtering messages
public struct DateRange: Sendable {
    public let startDate: Date
    public let endDate: Date
    
    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    /// Create a date range for the last N days
    public static func lastDays(_ days: Int) -> DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    /// Create a date range for the last N hours
    public static func lastHours(_ hours: Int) -> DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: endDate)!
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    /// Create a date range for a specific day
    public static func day(_ date: Date) -> DateRange {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    /// Check if a date falls within this range
    public func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }
}

/// Thread-safe message grouping for proper reply context
public struct MessageGroup: Sendable {
    public let parentMessage: Message
    public let replies: [Message]
    public let reactions: [Message]
}

/// Exports iMessage conversations to LLM-Extended Markdown format
@DatabaseActor
public final class MarkdownExporter: Sendable {
    private let exporter: iMessageExport
    private let options: MarkdownExportOptions
    private let dateFormatter: DateFormatter
    
    public init(exporter: iMessageExport, options: MarkdownExportOptions = MarkdownExportOptions()) {
        self.exporter = exporter
        self.options = options
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        self.dateFormatter.timeZone = TimeZone.current
    }
    
    /// Export a single chat conversation to markdown format
    public func exportChat(chatId: Int32) async throws -> String {
        let chat = try await exporter.getChat(withId: chatId)
        guard let chat = chat else {
            throw MarkdownExportError.chatNotFound(chatId)
        }
        
        let messages = try await exporter.getMessages(forChatId: chatId)
        let handles = try await exporter.getHandles(forChatId: chatId)
        let handleMapping = try await exporter.createHandleMapping()
        
        return try await exportMessages(messages, chat: chat, handles: handles, handleMapping: handleMapping)
    }
    
    /// Export all messages from a specific chat identifier
    public func exportChat(identifier: String) async throws -> String {
        let chat = try await exporter.getChat(withIdentifier: identifier)
        guard let chat = chat else {
            throw MarkdownExportError.chatNotFoundByIdentifier(identifier)
        }
        
        return try await exportChat(chatId: chat.rowid)
    }
    
    /// Export all chats and return a dictionary of chat names to markdown
    public func exportAllChats() async throws -> [String: String] {
        let chats = try await exporter.getAllChats()
        var results: [String: String] = [:]
        
        for chat in chats {
            let markdown = try await exportChat(chatId: chat.rowid)
            results[chat.name] = markdown
        }
        
        return results
    }
    
    /// Export a specific thread by its originator message GUID
    public func exportThread(threadGuid: String, chatId: Int32) async throws -> String {
        let chat = try await exporter.getChat(withId: chatId)
        guard let chat = chat else {
            throw MarkdownExportError.chatNotFound(chatId)
        }
        
        let messages = try await exporter.getMessages(forChatId: chatId)
        let handles = try await exporter.getHandles(forChatId: chatId)
        let handleMapping = try await exporter.createHandleMapping()
        
        // Create options to export only this specific thread
        var threadOptions = options
        threadOptions = MarkdownExportOptions(
            attachmentsDirectory: threadOptions.attachmentsDirectory,
            includeReactions: threadOptions.includeReactions,
            includeSystemMessages: threadOptions.includeSystemMessages,
            sanitizeUsernames: threadOptions.sanitizeUsernames,
            maxQuoteLength: threadOptions.maxQuoteLength,
            dateRange: threadOptions.dateRange,
            messageLimit: threadOptions.messageLimit,
            threadsOnly: false,
            specificThreadGuid: threadGuid
        )
        
        let threadExporter = MarkdownExporter(exporter: exporter, options: threadOptions)
        return try await threadExporter.exportMessages(messages, chat: chat, handles: handles, handleMapping: handleMapping)
    }
    
    /// Export chat with a specific number of most recent messages
    public func exportChatWithLimit(chatId: Int32, messageLimit: Int) async throws -> String {
        var limitedOptions = options
        limitedOptions = MarkdownExportOptions(
            attachmentsDirectory: limitedOptions.attachmentsDirectory,
            includeReactions: limitedOptions.includeReactions,
            includeSystemMessages: limitedOptions.includeSystemMessages,
            sanitizeUsernames: limitedOptions.sanitizeUsernames,
            maxQuoteLength: limitedOptions.maxQuoteLength,
            dateRange: limitedOptions.dateRange,
            messageLimit: messageLimit,
            threadsOnly: limitedOptions.threadsOnly,
            specificThreadGuid: limitedOptions.specificThreadGuid
        )
        
        let limitedExporter = MarkdownExporter(exporter: exporter, options: limitedOptions)
        return try await limitedExporter.exportChat(chatId: chatId)
    }
    
    /// Export chat within a specific date range
    public func exportChatInDateRange(chatId: Int32, dateRange: DateRange) async throws -> String {
        var dateRangeOptions = options
        dateRangeOptions = MarkdownExportOptions(
            attachmentsDirectory: dateRangeOptions.attachmentsDirectory,
            includeReactions: dateRangeOptions.includeReactions,
            includeSystemMessages: dateRangeOptions.includeSystemMessages,
            sanitizeUsernames: dateRangeOptions.sanitizeUsernames,
            maxQuoteLength: dateRangeOptions.maxQuoteLength,
            dateRange: dateRange,
            messageLimit: dateRangeOptions.messageLimit,
            threadsOnly: dateRangeOptions.threadsOnly,
            specificThreadGuid: dateRangeOptions.specificThreadGuid
        )
        
        let dateRangeExporter = MarkdownExporter(exporter: exporter, options: dateRangeOptions)
        return try await dateRangeExporter.exportChat(chatId: chatId)
    }
    
    /// Export only threaded conversations from a chat
    public func exportThreadsOnly(chatId: Int32) async throws -> String {
        var threadsOptions = options
        threadsOptions = MarkdownExportOptions(
            attachmentsDirectory: threadsOptions.attachmentsDirectory,
            includeReactions: threadsOptions.includeReactions,
            includeSystemMessages: threadsOptions.includeSystemMessages,
            sanitizeUsernames: threadsOptions.sanitizeUsernames,
            maxQuoteLength: threadsOptions.maxQuoteLength,
            dateRange: threadsOptions.dateRange,
            messageLimit: threadsOptions.messageLimit,
            threadsOnly: true,
            specificThreadGuid: threadsOptions.specificThreadGuid
        )
        
        let threadsExporter = MarkdownExporter(exporter: exporter, options: threadsOptions)
        return try await threadsExporter.exportChat(chatId: chatId)
    }
    
    // MARK: - Private Implementation
    
    private func exportMessages(
        _ messages: [Message],
        chat: Chat,
        handles: [Handle],
        handleMapping: [Int32: String]
    ) async throws -> String {
        // Filter messages based on options
        let filteredMessages = filterMessages(messages)
        
        // Group messages by thread structure
        let messageGroups = groupMessagesByThread(filteredMessages)
        
        var output = ""
        
        for group in messageGroups {
            // Export parent message
            output += try await formatMessage(group.parentMessage, handleMapping: handleMapping)
            
            // Add reactions if enabled
            if options.includeReactions && !group.reactions.isEmpty {
                output += formatReactions(group.reactions, handleMapping: handleMapping)
            }
            
            output += "\n---\n\n"
            
            // Export replies
            for reply in group.replies {
                output += try await formatReply(reply, parentMessage: group.parentMessage, handleMapping: handleMapping)
                output += "\n---\n\n"
            }
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func filterMessages(_ messages: [Message]) -> [Message] {
        var filteredMessages = messages.filter { message in
            // Filter by message type first
            let includeByType: Bool = {
                // Always include normal messages
                if message.isNormalMessage {
                    return true
                }
                
                // Include reactions if enabled
                if options.includeReactions && message.isReaction {
                    return true
                }
                
                // Include system messages if enabled
                if options.includeSystemMessages && (message.isAnnouncement || message.isAppMessage) {
                    return true
                }
                
                return false
            }()
            
            guard includeByType else { return false }
            
            // Filter by date range if specified
            if let dateRange = options.dateRange {
                guard dateRange.contains(message.sentDate) else { return false }
            }
            
            // Filter by specific thread if specified
            if let threadGuid = options.specificThreadGuid {
                // Include the thread originator itself or messages that reply to it
                if message.guid == threadGuid || message.threadOriginatorGuid == threadGuid {
                    return true
                }
                // Also include reactions to the thread originator or its replies
                if message.isReaction, let associatedGuid = message.associatedMessageGuid {
                    // Check if the reaction is for the thread originator or any of its replies
                    let isReactionToThread = associatedGuid == threadGuid || 
                                           messages.contains { $0.guid == associatedGuid && $0.threadOriginatorGuid == threadGuid }
                    return isReactionToThread
                }
                return false
            }
            
            // Filter by threads only if specified
            if options.threadsOnly {
                // Include only messages that are replies or have replies
                return message.isReply || message.hasReplies
            }
            
            return true
        }
        
        // Sort by date to ensure chronological order
        filteredMessages.sort { $0.date < $1.date }
        
        // Apply message limit if specified
        if options.messageLimit > 0 && filteredMessages.count > options.messageLimit {
            filteredMessages = Array(filteredMessages.prefix(options.messageLimit))
        }
        
        return filteredMessages
    }
    
    private func groupMessagesByThread(_ messages: [Message]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        var messageDict: [String: Message] = [:]
        
        // Create lookup dictionary
        for message in messages {
            messageDict[message.guid] = message
        }
        
        // Find all parent messages (non-replies, non-reactions)
        let parentMessages = messages.filter { !$0.isReply && !$0.isReaction }
        
        for parent in parentMessages {
            let replies = messages.filter { 
                $0.threadOriginatorGuid == parent.guid && !$0.isReaction 
            }
            let reactions = messages.filter { 
                $0.associatedMessageGuid == parent.guid && $0.isReaction 
            }
            
            let group = MessageGroup(
                parentMessage: parent,
                replies: replies.sorted { $0.date < $1.date },
                reactions: reactions.sorted { $0.date < $1.date }
            )
            groups.append(group)
        }
        
        return groups.sorted { $0.parentMessage.date < $1.parentMessage.date }
    }
    
    private func formatMessage(_ message: Message, handleMapping: [Int32: String]) async throws -> String {
        let username = formatUsername(message: message, handleMapping: handleMapping)
        let timestamp = dateFormatter.string(from: message.sentDate)
        
        var output = "### \(username) [\(timestamp)]\n\n"
        
        // Add message content
        if let text = message.effectiveText {
            output += text + "\n\n"
        }
        
        // Add attachments
        if message.hasAttachments {
            let attachments = try await exporter.getAttachments(forMessageId: message.rowid)
            for attachment in attachments {
                output += formatAttachment(attachment) + "\n\n"
            }
        }
        
        return output
    }
    
    private func formatReply(_ reply: Message, parentMessage: Message, handleMapping: [Int32: String]) async throws -> String {
        let username = formatUsername(message: reply, handleMapping: handleMapping)
        let timestamp = dateFormatter.string(from: reply.sentDate)
        let parentUsername = formatUsername(message: parentMessage, handleMapping: handleMapping)
        let parentTimestamp = dateFormatter.string(from: parentMessage.sentDate)
        
        var output = "### \(username) [\(timestamp)]\n\n"
        
        // Add quoted parent message
        var quotedText = parentMessage.effectiveText ?? ""
        if options.maxQuoteLength > 0 && quotedText.count > options.maxQuoteLength {
            quotedText = String(quotedText.prefix(options.maxQuoteLength)) + "..."
        }
        
        output += "> \(parentUsername) [\(parentTimestamp)]:  \n"
        output += "> \(quotedText)\n\n"
        
        // Add reply content
        if let text = reply.effectiveText {
            output += text + "\n\n"
        }
        
        // Add attachments
        if reply.hasAttachments {
            let attachments = try await exporter.getAttachments(forMessageId: reply.rowid)
            for attachment in attachments {
                output += formatAttachment(attachment) + "\n\n"
            }
        }
        
        return output
    }
    
    private func formatReactions(_ reactions: [Message], handleMapping: [Int32: String]) -> String {
        var reactionList: [String] = []
        
        for reaction in reactions {
            let username = formatUsername(message: reaction, handleMapping: handleMapping)
            if let emoji = reaction.associatedMessageEmoji {
                reactionList.append("\(username) \(emoji)")
            }
        }
        
        guard !reactionList.isEmpty else { return "" }
        
        return "[Reactions: \(reactionList.joined(separator: ", "))]\n\n"
    }
    
    private func formatAttachment(_ attachment: Attachment) -> String {
        let filename = attachment.displayName
        let path = "\(options.attachmentsDirectory)/\(filename)"
        
        var output = "[Attachment: \(filename)](\(path))"
        
        // Add description for images or other media
        if let description = attachment.emojiImageShortDescription {
            output += "\n\n_\(description)_"
        }
        
        return output
    }
    
    private func formatUsername(message: Message, handleMapping: [Int32: String]) -> String {
        var username: String
        
        if message.isFromMe {
            username = "me"
        } else if let handleId = message.handleId, let handle = handleMapping[handleId] {
            username = handle
        } else {
            username = "unknown"
        }
        
        if options.sanitizeUsernames {
            username = sanitizeUsername(username)
        }
        
        return "@\(username)"
    }
    
    private func sanitizeUsername(_ username: String) -> String {
        // Remove special characters and spaces, keep only alphanumeric and basic punctuation
        return username
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "+", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        return filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .filter { !$0.isWhitespace || $0 == " " }
    }
}

/// Errors that can occur during markdown export
public enum MarkdownExportError: Error, LocalizedError {
    case chatNotFound(Int32)
    case chatNotFoundByIdentifier(String)
    case attachmentNotFound(Int32)
    case exportDirectoryNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .chatNotFound(let chatId):
            return "Chat with ID \(chatId) not found"
        case .chatNotFoundByIdentifier(let identifier):
            return "Chat with identifier '\(identifier)' not found"
        case .attachmentNotFound(let attachmentId):
            return "Attachment with ID \(attachmentId) not found"
        case .exportDirectoryNotFound(let path):
            return "Export directory not found: \(path)"
        }
    }
}