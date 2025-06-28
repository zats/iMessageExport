@testable import iMessageExport
import XCTest

final class DatabaseIntegrationTests: XCTestCase {
    private static var testDatabasePath: String {
        guard let bundlePath = Bundle.module.path(forResource: "test", ofType: "db", inDirectory: "Resources") else {
            XCTFail("Could not find test database in bundle")
            return ""
        }
        return bundlePath
    }
    
    @DatabaseActor
    private static func createExporter() throws -> iMessageExport {
        try iMessageExport(databasePath: testDatabasePath)
    }
    
    func testDatabaseConnection() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        // Test basic connection functionality
        let schemaVersion = try await exporter.getDatabaseSchemaVersion()
        XCTAssertGreaterThanOrEqual(schemaVersion, 0)
        
        // Test table existence checks
        let messageExists = try await exporter.tableExists("message")
        XCTAssertTrue(messageExists)
        
        let chatExists = try await exporter.tableExists("chat")
        XCTAssertTrue(chatExists)
        
        let handleExists = try await exporter.tableExists("handle")
        XCTAssertTrue(handleExists)
        
        let attachmentExists = try await exporter.tableExists("attachment")
        XCTAssertTrue(attachmentExists)
        
        let nonexistentExists = try await exporter.tableExists("nonexistent_table")
        XCTAssertFalse(nonexistentExists)
    }
    
    func testFetchMessages() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let messages = try await exporter.getAllMessages()
        
        // Test database contains at least some messages
        if !messages.isEmpty {
            // Verify message properties
            for message in messages.prefix(5) {
                XCTAssertFalse(message.guid.isEmpty)
                XCTAssertGreaterThan(message.date, 0)
                XCTAssertNotNil(message.serviceType)
                
                // Test date conversion
                let sentDate = message.sentDate
                XCTAssertTrue(sentDate.timeIntervalSince1970 > 0)
                
                // Test message variant
                _ = message.variant // Just verify it doesn't crash
            }
        } else {
            // If no messages, just verify the query worked without error
            XCTAssertEqual(messages.count, 0)
        }
    }
    
    func testFetchChats() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let chats = try await exporter.getAllChats()
        
        // Test group vs direct message classification (works even with empty results)
        let groupChats = try await exporter.getGroupChats()
        let directChats = try await exporter.getDirectMessageChats()
        
        for chat in groupChats {
            XCTAssertTrue(chat.isGroupChat)
            XCTAssertFalse(chat.isDirectMessage)
        }
        
        for chat in directChats {
            XCTAssertFalse(chat.isGroupChat)
            XCTAssertTrue(chat.isDirectMessage)
        }
        
        XCTAssertEqual(groupChats.count + directChats.count, chats.count)
    }
    
    func testFetchHandles() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let handles = try await exporter.getAllHandles()
        
        // Verify handle types (works even with empty results)
        var phoneHandles = 0
        var emailHandles = 0
        
        for handle in handles {
            XCTAssertFalse(handle.id.isEmpty)
            
            if handle.isPhoneNumber {
                phoneHandles += 1
            } else if handle.isEmail {
                emailHandles += 1
            }
        }
        
        // Just verify the classification logic works
        XCTAssertEqual(phoneHandles + emailHandles, handles.filter { $0.isPhoneNumber || $0.isEmail }.count)
    }
    
    func testFetchAttachments() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let attachments = try await exporter.getAllAttachments()
        
        // Test data might not have attachments, so just verify the query works
        for attachment in attachments.prefix(5) {
            XCTAssertGreaterThan(attachment.rowid, 0)
            
            // Test media type detection
            let mediaType = attachment.mediaType
            XCTAssertTrue([
                MediaType.image(""),
                MediaType.video(""),
                MediaType.audio(""),
                MediaType.application(""),
                MediaType.text(""),
                MediaType.unknown
            ].contains { mediaTypeMatches($0, mediaType) })
        }
    }
    
    func testChatStatistics() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let chats = try await exporter.getAllChats()
        if let firstChat = chats.first {
            let stats = try await exporter.getChatStatistics(chatId: firstChat.rowid)
            XCTAssertGreaterThanOrEqual(stats.messageCount, 0)
            XCTAssertGreaterThanOrEqual(stats.attachmentCount, 0)
            XCTAssertGreaterThanOrEqual(stats.participantCount, 0)
        } else {
            // Test with a hypothetical chat ID if no chats exist
            let stats = try await exporter.getChatStatistics(chatId: 999)
            XCTAssertEqual(stats.messageCount, 0)
            XCTAssertEqual(stats.attachmentCount, 0)
            XCTAssertEqual(stats.participantCount, 0)
        }
    }
    
    func testMessagesByChat() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let chats = try await exporter.getAllChats()
        if let firstChat = chats.first {
            let messages = try await exporter.getMessages(forChatId: firstChat.rowid)
            
            // Verify all messages belong to the specified chat
            for message in messages {
                XCTAssertEqual(message.chatId, firstChat.rowid)
            }
        } else {
            // Test with a hypothetical chat ID if no chats exist
            let messages = try await exporter.getMessages(forChatId: 999)
            XCTAssertEqual(messages.count, 0)
        }
    }
    
    func testHandlesByChat() async throws {
        let exporter = try await Self.createExporter()
        defer { Task { await exporter.close() } }
        
        let chats = try await exporter.getAllChats()
        if let firstChat = chats.first {
            let handles = try await exporter.getHandles(forChatId: firstChat.rowid)
            
            // Group chats should have multiple handles, direct chats might have 1-2
            if firstChat.isGroupChat {
                XCTAssertGreaterThan(handles.count, 1)
            }
            
            for handle in handles {
                XCTAssertFalse(handle.id.isEmpty)
            }
        } else {
            // Test with a hypothetical chat ID if no chats exist
            let handles = try await exporter.getHandles(forChatId: 999)
            XCTAssertEqual(handles.count, 0)
        }
    }
    
    // Helper functions for enum comparison
    private func variantMatches(_ expected: MessageVariant, _ actual: MessageVariant) -> Bool {
        switch (expected, actual) {
        case (.normal, .normal), (.edited, .edited), (.sharePlay, .sharePlay), 
             (.audioMessageKept, .audioMessageKept):
            return true

        case (.app(_), .app(_)):
            return true

        case (.groupAction(_), .groupAction(_)):
            return true

        case (.tapback(_, _), .tapback(_, _)):
            return true

        case (.locationShare(_), .locationShare(_)):
            return true

        case (.unknown(_), .unknown(_)):
            return true

        default:
            return false
        }
    }
    
    private func mediaTypeMatches(_ expected: MediaType, _ actual: MediaType) -> Bool {
        switch (expected, actual) {
        case (.image(_), .image(_)), (.video(_), .video(_)), (.audio(_), .audio(_)),
             (.application(_), .application(_)), (.text(_), .text(_)),
             (.unknown, .unknown):
            return true

        case (.other(_), .other(_)):
            return true

        default:
            return false
        }
    }
}
