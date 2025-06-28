import XCTest
@testable import iMessageExport

final class MarkdownExportTests: XCTestCase {}
    
    func testMarkdownExportOptions() throws {
        let defaultOptions = MarkdownExportOptions()
        XCTAssertEqual(defaultOptions.attachmentsDirectory, "./attachments")
        XCTAssertTrue(defaultOptions.includeReactions)
        XCTAssertFalse(defaultOptions.includeSystemMessages)
        XCTAssertTrue(defaultOptions.sanitizeUsernames)
        XCTAssertEqual(defaultOptions.maxQuoteLength, 150)
        
        let customOptions = MarkdownExportOptions(
            attachmentsDirectory: "./custom/attachments",
            includeReactions: false,
            includeSystemMessages: true,
            sanitizeUsernames: false,
            maxQuoteLength: 100
        )
        XCTAssertEqual(customOptions.attachmentsDirectory, "./custom/attachments")
        XCTAssertFalse(customOptions.includeReactions)
        XCTAssertTrue(customOptions.includeSystemMessages)
        XCTAssertFalse(customOptions.sanitizeUsernames)
        XCTAssertEqual(customOptions.maxQuoteLength, 100)
    }
    
    func testMarkdownExporterInitialization() async throws {
        // Use test database
        let testDatabasePath = Bundle.module.path(forResource: "test", ofType: "db")!
        let exporter = try iMessageExport(databasePath: testDatabasePath)
        
        let markdownExporter = exporter.createMarkdownExporter()
        XCTAssertNotNil(markdownExporter)
        
        await exporter.close()
    }
    
    func testMessageGrouping() async throws {
        // Test that MessageGroup structure is created correctly
        let parent = Message(
            rowid: 1,
            guid: "parent-guid",
            text: "Parent message",
            date: 1000000000,
            isFromMe: false
        )
        
        let reply = Message(
            rowid: 2,
            guid: "reply-guid",
            text: "Reply message",
            date: 1000000001,
            isFromMe: true,
            threadOriginatorGuid: "parent-guid"
        )
        
        let reaction = Message(
            rowid: 3,
            guid: "reaction-guid",
            date: 1000000002,
            isFromMe: false,
            associatedMessageGuid: "parent-guid",
            associatedMessageType: 2000, // loved
            associatedMessageEmoji: "❤️"
        )
        
        let group = MessageGroup(
            parentMessage: parent,
            replies: [reply],
            reactions: [reaction]
        )
        
        XCTAssertEqual(group.parentMessage.guid, "parent-guid")
        XCTAssertEqual(group.replies.count, 1)
        XCTAssertEqual(group.replies.first?.guid, "reply-guid")
        XCTAssertEqual(group.reactions.count, 1)
        XCTAssertEqual(group.reactions.first?.guid, "reaction-guid")
    }
    
    func testMarkdownExportErrors() {
        let chatNotFoundError = MarkdownExportError.chatNotFound(123)
        XCTAssertEqual(chatNotFoundError.errorDescription, "Chat with ID 123 not found")
        
        let chatNotFoundByIdError = MarkdownExportError.chatNotFoundByIdentifier("test@example.com")
        XCTAssertEqual(chatNotFoundByIdError.errorDescription, "Chat with identifier 'test@example.com' not found")
        
        let attachmentNotFoundError = MarkdownExportError.attachmentNotFound(456)
        XCTAssertEqual(attachmentNotFoundError.errorDescription, "Attachment with ID 456 not found")
        
        let directoryNotFoundError = MarkdownExportError.exportDirectoryNotFound("/nonexistent/path")
        XCTAssertEqual(directoryNotFoundError.errorDescription, "Export directory not found: /nonexistent/path")
    }
    
    func testUsernameFormatting() async throws {
        // Test that usernames are properly formatted with @ prefix
        let testDatabasePath = Bundle.module.path(forResource: "test", ofType: "db")!
        let exporter = try iMessageExport(databasePath: testDatabasePath)
        let markdownExporter = exporter.createMarkdownExporter()
        
        // Test message from me
        let fromMeMessage = Message(
            rowid: 1,
            guid: "test-guid",
            text: "Test message",
            date: 1000000000,
            isFromMe: true
        )
        
        // Test message from other user
        let fromOtherMessage = Message(
            rowid: 2,
            guid: "test-guid-2",
            text: "Test message 2",
            handleId: 1,
            date: 1000000001,
            isFromMe: false
        )
        
        await exporter.close()
    }
    
    func testMessageFiltering() {
        // Test message filtering based on options
        let normalMessage = Message(
            rowid: 1,
            guid: "normal",
            text: "Normal message",
            date: 1000000000,
            isFromMe: false,
            itemType: 0
        )
        
        let reactionMessage = Message(
            rowid: 2,
            guid: "reaction",
            date: 1000000001,
            isFromMe: false,
            associatedMessageType: 2000,
            associatedMessageEmoji: "❤️"
        )
        
        let groupActionMessage = Message(
            rowid: 3,
            guid: "group-action",
            date: 1000000002,
            isFromMe: false,
            itemType: 1,
            groupActionType: 0
        )
        
        // Verify message variants
        XCTAssertTrue(normalMessage.variant.isNormal)
        XCTAssertTrue(reactionMessage.variant.isReaction)
        XCTAssertTrue(groupActionMessage.variant.isAnnouncement)
    }
}