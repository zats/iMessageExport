import Foundation

/// Contact lookup function type for resolving identifiers to display names
public typealias ContactLookupFunction = @Sendable (String) async -> String?

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
    /// Optional contact lookup function for resolving identifiers to display names
    public let contactLookup: ContactLookupFunction?
    
    public init(
        attachmentsDirectory: String = "./attachments",
        includeReactions: Bool = true,
        includeSystemMessages: Bool = false,
        sanitizeUsernames: Bool = true,
        maxQuoteLength: Int = 150,
        dateRange: DateRange? = nil,
        messageLimit: Int = 0,
        threadsOnly: Bool = false,
        specificThreadGuid: String? = nil,
        contactLookup: ContactLookupFunction? = nil
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
        self.contactLookup = contactLookup
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
            specificThreadGuid: threadGuid,
            contactLookup: threadOptions.contactLookup
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
            specificThreadGuid: limitedOptions.specificThreadGuid,
            contactLookup: limitedOptions.contactLookup
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
            specificThreadGuid: dateRangeOptions.specificThreadGuid,
            contactLookup: dateRangeOptions.contactLookup
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
            specificThreadGuid: threadsOptions.specificThreadGuid,
            contactLookup: threadsOptions.contactLookup
        )
        
        let threadsExporter = MarkdownExporter(exporter: exporter, options: threadsOptions)
        return try await threadsExporter.exportChat(chatId: chatId)
    }
    
    /// Export chat as a bundle with markdown, HTML, and attachments
    public func exportChatBundle(chatId: Int32, to bundleURL: URL) async throws {
        let chat = try await exporter.getChat(withId: chatId)
        guard let chat = chat else {
            throw MarkdownExportError.chatNotFound(chatId)
        }
        
        // Create bundle directory
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        
        // Export markdown
        let markdown = try await exportChat(chatId: chatId)
        let indexMarkdownURL = bundleURL.appendingPathComponent("index.md")
        try markdown.write(to: indexMarkdownURL, atomically: true, encoding: .utf8)
        
        // Create attachments directory
        let attachmentsURL = bundleURL.appendingPathComponent("attachments")
        try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        
        // Copy attachments
        let messages = try await exporter.getMessages(forChatId: chatId)
        for message in messages {
            if message.hasAttachments {
                let attachments = try await exporter.getAttachments(forMessageId: message.rowid)
                for attachment in attachments {
                    try await copyAttachmentToBundle(attachment, to: attachmentsURL)
                }
            }
        }
        
        // Generate HTML version
        let html = try await generateHTML(from: markdown, chatTitle: chat.name)
        let indexHTMLURL = bundleURL.appendingPathComponent("index.html")
        try html.write(to: indexHTMLURL, atomically: true, encoding: .utf8)
    }
    
    public func copyAttachmentToBundle(_ attachment: Attachment, to attachmentsDirectory: URL) async throws {
        // Get the original file path and expand ~ if needed
        let originalPath: String
        if let filename = attachment.filename {
            originalPath = filename
        } else if let transferName = attachment.transferName {
            originalPath = transferName
        } else {
            // Fallback: create a metadata file
            let metadataFilename = "attachment_\(attachment.rowid).txt"
            let metadataURL = attachmentsDirectory.appendingPathComponent(metadataFilename)
            
            let metadata = """
            Attachment: \(attachment.displayName)
            MIME Type: \(attachment.mimeType ?? "unknown")
            Size: \(attachment.totalBytes ?? 0) bytes
            Is Sticker: \(attachment.isSticker)
            """
            
            try metadata.write(to: metadataURL, atomically: true, encoding: .utf8)
            return
        }
        
        // Expand ~ to home directory
        let expandedPath = NSString(string: originalPath).expandingTildeInPath
        let sourceURL = URL(fileURLWithPath: expandedPath)
        
        // Extract just the filename (last component) for the destination
        let destinationFilename = sourceURL.lastPathComponent
        let destinationURL = attachmentsDirectory.appendingPathComponent(destinationFilename)
        
        // Try to copy the actual file
        do {
            // Check if source file exists
            if FileManager.default.fileExists(atPath: expandedPath) {
                // If destination already exists, add a number suffix
                var finalDestinationURL = destinationURL
                var counter = 1
                while FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    let nameWithoutExtension = destinationURL.deletingPathExtension().lastPathComponent
                    let fileExtension = destinationURL.pathExtension
                    let numberedName = "\(nameWithoutExtension)_\(counter).\(fileExtension)"
                    finalDestinationURL = attachmentsDirectory.appendingPathComponent(numberedName)
                    counter += 1
                }
                
                try FileManager.default.copyItem(at: sourceURL, to: finalDestinationURL)
            } else {
                // Source file doesn't exist, create a metadata file instead
                let metadataFilename = destinationFilename + ".missing.txt"
                let metadataURL = attachmentsDirectory.appendingPathComponent(metadataFilename)
                
                let metadata = """
                Missing Attachment: \(destinationFilename)
                Original Path: \(originalPath)
                Expanded Path: \(expandedPath)
                MIME Type: \(attachment.mimeType ?? "unknown")
                Size: \(attachment.totalBytes ?? 0) bytes
                Is Sticker: \(attachment.isSticker)
                """
                
                try metadata.write(to: metadataURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // If copying fails, create a metadata file with error info
            let errorFilename = destinationFilename + ".error.txt"
            let errorURL = attachmentsDirectory.appendingPathComponent(errorFilename)
            
            let errorMetadata = """
            Failed to Copy Attachment: \(destinationFilename)
            Original Path: \(originalPath)
            Expanded Path: \(expandedPath)
            Error: \(error.localizedDescription)
            MIME Type: \(attachment.mimeType ?? "unknown")
            Size: \(attachment.totalBytes ?? 0) bytes
            Is Sticker: \(attachment.isSticker)
            """
            
            try errorMetadata.write(to: errorURL, atomically: true, encoding: .utf8)
        }
    }
    
    public func generateHTML(from markdown: String, chatTitle: String) async throws -> String {
        // Parse the markdown and convert to proper HTML structure
        let htmlBody = try await convertMarkdownToHTML(markdown)
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(chatTitle) - iMessage Export</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 900px;
                    margin: 0 auto;
                    padding: 20px;
                    line-height: 1.6;
                    background-color: #f5f5f7;
                }
                .chat-container {
                    background: white;
                    border-radius: 12px;
                    padding: 20px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                }
                .chat-title {
                    color: #1d1d1f;
                    border-bottom: 2px solid #e5e5e7;
                    padding-bottom: 16px;
                    margin-bottom: 24px;
                    font-size: 28px;
                    font-weight: 600;
                }
                .message {
                    margin-bottom: 16px;
                    padding: 12px 16px;
                    border-radius: 18px;
                    max-width: 70%;
                    word-wrap: break-word;
                }
                .message.from-me {
                    background: #007aff;
                    color: white;
                    margin-left: auto;
                    text-align: right;
                }
                .message.from-other {
                    background: #e5e5ea;
                    color: #1d1d1f;
                }
                .message-header {
                    font-size: 12px;
                    opacity: 0.7;
                    margin-bottom: 4px;
                    font-weight: 500;
                }
                .message-content {
                    margin: 0;
                }
                .message-content img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 8px 0;
                    display: block;
                }
                .message-content video {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 8px 0;
                    display: block;
                }
                .attachment-link {
                    display: inline-block;
                    padding: 8px 12px;
                    background: rgba(255,255,255,0.2);
                    border-radius: 8px;
                    text-decoration: none;
                    color: inherit;
                    margin: 4px 0;
                    border: 1px solid rgba(255,255,255,0.3);
                }
                .message.from-other .attachment-link {
                    background: rgba(0,0,0,0.05);
                    border: 1px solid rgba(0,0,0,0.1);
                }
                .reactions {
                    margin-top: 8px;
                    font-size: 11px;
                    opacity: 0.8;
                    font-style: italic;
                }
                .quote {
                    border-left: 3px solid rgba(255,255,255,0.3);
                    padding-left: 12px;
                    margin: 8px 0;
                    font-style: italic;
                    opacity: 0.8;
                }
                .message.from-other .quote {
                    border-left-color: rgba(0,0,0,0.2);
                }
            </style>
        </head>
        <body>
            <div class="chat-container">
                <h1 class="chat-title">\(escapeHTML(chatTitle))</h1>
                \(htmlBody)
            </div>
        </body>
        </html>
        """
    }
    
    private func convertMarkdownToHTML(_ markdown: String) async throws -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html = ""
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and separators
            if line.isEmpty || line == "---" {
                i += 1
                continue
            }
            
            // Parse message headers (### username [timestamp])
            if line.hasPrefix("### ") {
                let headerContent = String(line.dropFirst(4))
                let (username, timestamp, isFromMe) = parseMessageHeader(headerContent)
                
                // Start message div
                let messageClass = isFromMe ? "message from-me" : "message from-other"
                html += "<div class=\"\(messageClass)\">\n"
                html += "<div class=\"message-header\">\(escapeHTML(username)) • \(escapeHTML(timestamp))</div>\n"
                
                // Parse message content
                i += 1
                var messageContent = ""
                var hasQuote = false
                
                while i < lines.count {
                    let contentLine = lines[i]
                    
                    // Stop at next message or separator
                    if contentLine.hasPrefix("### ") || contentLine == "---" {
                        break
                    }
                    
                    // Handle quotes
                    if contentLine.hasPrefix("> ") {
                        if !hasQuote {
                            messageContent += "<div class=\"quote\">\n"
                            hasQuote = true
                        }
                        messageContent += escapeHTML(String(contentLine.dropFirst(2))) + "<br>\n"
                    } else if hasQuote && !contentLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        messageContent += "</div>\n"
                        hasQuote = false
                        messageContent += processContentLine(contentLine)
                    } else if contentLine.hasPrefix("[Attachment:") {
                        messageContent += processAttachmentLine(contentLine)
                    } else if contentLine.hasPrefix("[Reactions:") {
                        // Close any open quote
                        if hasQuote {
                            messageContent += "</div>\n"
                            hasQuote = false
                        }
                        messageContent += "<div class=\"reactions\">\(escapeHTML(contentLine))</div>\n"
                    } else if !contentLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        messageContent += processContentLine(contentLine)
                    }
                    
                    i += 1
                }
                
                // Close any open quote
                if hasQuote {
                    messageContent += "</div>\n"
                }
                
                html += "<div class=\"message-content\">\(messageContent)</div>\n"
                html += "</div>\n"
            } else {
                i += 1
            }
        }
        
        return html
    }
    
    private func parseMessageHeader(_ header: String) -> (username: String, timestamp: String, isFromMe: Bool) {
        // Parse "username [timestamp]" format
        if let bracketStart = header.lastIndex(of: "["),
           let bracketEnd = header.lastIndex(of: "]") {
            let username = String(header[..<bracketStart]).trimmingCharacters(in: .whitespaces)
            let timestamp = String(header[header.index(after: bracketStart)..<bracketEnd])
            let isFromMe = username == "me"
            return (username, timestamp, isFromMe)
        }
        return (header, "", false)
    }
    
    private func processContentLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "<br>\n"
        }
        
        // Check if this line contains a markdown link (from URL app messages)
        let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: linkPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            
            let textRange = Range(match.range(at: 1), in: trimmed)!
            let urlRange = Range(match.range(at: 2), in: trimmed)!
            
            let linkText = String(trimmed[textRange])
            let linkURL = String(trimmed[urlRange])
            
            return "<a href=\"\(escapeHTML(linkURL))\" target=\"_blank\">\(escapeHTML(linkText))</a><br>\n"
        }
        
        return escapeHTML(trimmed) + "<br>\n"
    }
    
    private func processAttachmentLine(_ line: String) -> String {
        // Parse [Attachment: filename](path) format
        let pattern = #"\[Attachment: ([^\]]+)\]\(([^)]+)\)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            
            let filenameRange = Range(match.range(at: 1), in: line)!
            let pathRange = Range(match.range(at: 2), in: line)!
            
            let filename = String(line[filenameRange])
            let path = String(line[pathRange])
            
            // Determine file type and render accordingly
            let fileExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
            
            if ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(fileExtension) {
                return "<img src=\"\(escapeHTML(path))\" alt=\"\(escapeHTML(filename))\" title=\"\(escapeHTML(filename))\">\n"
            } else if ["mp4", "mov", "avi", "mkv", "webm"].contains(fileExtension) {
                return "<video controls><source src=\"\(escapeHTML(path))\" type=\"video/\(fileExtension)\">Your browser does not support the video tag.</video>\n"
            } else if ["mp3", "wav", "aac", "m4a"].contains(fileExtension) {
                return "<audio controls><source src=\"\(escapeHTML(path))\" type=\"audio/\(fileExtension)\">Your browser does not support the audio tag.</audio>\n"
            } else {
                return "<a href=\"\(escapeHTML(path))\" class=\"attachment-link\">📎 \(escapeHTML(filename))</a>\n"
            }
        }
        
        return escapeHTML(line) + "<br>\n"
    }
    
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
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
                output += await formatReactions(group.reactions, handleMapping: handleMapping)
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
                
                // Always include URL app messages (they should be treated as regular content)
                if message.isAppMessage && message.balloonBundleId == "com.apple.messages.URLBalloonProvider" {
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
        let username = await formatUsername(message: message, handleMapping: handleMapping)
        let timestamp = dateFormatter.string(from: message.sentDate)
        
        var output = "### \(username) [\(timestamp)]\n\n"
        
        // Add message content
        if let text = message.effectiveText {
            // Special handling for URL app messages
            if message.balloonBundleId == "com.apple.messages.URLBalloonProvider" {
                // Format URL messages with proper markdown link syntax
                if let url = extractURLFromText(text) {
                    output += "[\(text)](\(url))\n\n"
                } else {
                    // Fallback: treat as regular text if URL extraction fails
                    output += text + "\n\n"
                }
            } else {
                output += text + "\n\n"
            }
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
        let username = await formatUsername(message: reply, handleMapping: handleMapping)
        let timestamp = dateFormatter.string(from: reply.sentDate)
        let parentUsername = await formatUsername(message: parentMessage, handleMapping: handleMapping)
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
            // Special handling for URL app messages
            if reply.balloonBundleId == "com.apple.messages.URLBalloonProvider" {
                // Format URL messages with proper markdown link syntax
                if let url = extractURLFromText(text) {
                    output += "[\(text)](\(url))\n\n"
                } else {
                    // Fallback: treat as regular text if URL extraction fails
                    output += text + "\n\n"
                }
            } else {
                output += text + "\n\n"
            }
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
    
    private func formatReactions(_ reactions: [Message], handleMapping: [Int32: String]) async -> String {
        var reactionList: [String] = []
        
        for reaction in reactions {
            let username = await formatUsername(message: reaction, handleMapping: handleMapping)
            if let emoji = reaction.associatedMessageEmoji {
                reactionList.append("\(username) \(emoji)")
            }
        }
        
        guard !reactionList.isEmpty else { return "" }
        
        return "[Reactions: \(reactionList.joined(separator: ", "))]\n\n"
    }
    
    private func formatAttachment(_ attachment: Attachment) -> String {
        // Use just the filename component, not the full path
        let originalPath: String
        if let filename = attachment.filename {
            originalPath = filename
        } else if let transferName = attachment.transferName {
            originalPath = transferName
        } else {
            originalPath = attachment.displayName
        }
        
        // Extract just the filename for the markdown link
        let filename: String
        if originalPath.contains("/") {
            // Extract just the last component of the path
            filename = URL(fileURLWithPath: originalPath).lastPathComponent
        } else {
            filename = originalPath
        }
        
        let path = "\(options.attachmentsDirectory)/\(filename)"
        
        var output = "[Attachment: \(filename)](\(path))"
        
        // Add description for images or other media
        if let description = attachment.emojiImageShortDescription {
            output += "\n\n_\(description)_"
        }
        
        return output
    }
    
    private func formatUsername(message: Message, handleMapping: [Int32: String]) async -> String {
        var username: String
        
        if message.isFromMe {
            username = "me"
        } else if let handleId = message.handleId, let handle = handleMapping[handleId] {
            // Try contact lookup first if available
            if let contactLookup = options.contactLookup {
                if let displayName = await contactLookup(handle) {
                    username = displayName
                } else {
                    username = handle
                }
            } else {
                username = handle
            }
        } else {
            username = "unknown"
        }
        
        if options.sanitizeUsernames {
            username = sanitizeUsername(username)
        }
        
        return username // Use identifier as-is, no @ prefix
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
    
    private func extractURLFromText(_ text: String) -> String? {
        // Try to extract URL using NSDataDetector
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector.matches(in: text, options: [], range: range)
        
        // Return the first URL found
        if let match = matches.first, let url = match.url {
            return url.absoluteString
        }
        
        // Fallback: if the entire text looks like a URL, return it
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            return text
        }
        
        return nil
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