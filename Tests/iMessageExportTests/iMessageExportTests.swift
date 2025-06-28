@testable import iMessageExport
import XCTest

final class iMessageExportTests: XCTestCase {
    func testServiceCreation() {
        let iMessageService = Service.from("iMessage")
        XCTAssertEqual(iMessageService, .iMessage)
        
        let smsService = Service.from("SMS")
        XCTAssertEqual(smsService, .sms)
        
        let unknownService = Service.from(nil)
        XCTAssertEqual(unknownService, .unknown)
    }
    
    func testTextAttributes() {
        let attributes = TextAttributes(start: 0, end: 5, effects: [.bold, .italic])
        XCTAssertEqual(attributes.start, 0)
        XCTAssertEqual(attributes.end, 5)
        XCTAssertEqual(attributes.length, 5)
        XCTAssertEqual(attributes.range, 0..<5)
        XCTAssertTrue(attributes.effects.contains(.bold))
        XCTAssertTrue(attributes.effects.contains(.italic))
    }
    
    func testAttachmentMeta() {
        let meta = AttachmentMeta(
            guid: "test-guid",
            transcription: "Hello world",
            height: 100.0,
            width: 200.0,
            name: "test.jpg"
        )
        
        XCTAssertEqual(meta.guid, "test-guid")
        XCTAssertTrue(meta.hasTranscription)
        XCTAssertTrue(meta.hasDimensions)
        XCTAssertEqual(meta.aspectRatio, 2.0)
    }
    
    func testBubbleComponent() {
        let textComponent = BubbleComponent.text([])
        XCTAssertTrue(textComponent.isText)
        XCTAssertFalse(textComponent.isAttachment)
        
        let attachmentComponent = BubbleComponent.attachment(AttachmentMeta())
        XCTAssertTrue(attachmentComponent.isAttachment)
        XCTAssertFalse(attachmentComponent.isText)
    }
    
    func testHandle() {
        let phoneHandle = Handle(rowid: 1, id: "+1234567890")
        XCTAssertTrue(phoneHandle.isPhoneNumber)
        XCTAssertFalse(phoneHandle.isEmail)
        
        let emailHandle = Handle(rowid: 2, id: "test@example.com")
        XCTAssertTrue(emailHandle.isEmail)
        XCTAssertFalse(emailHandle.isPhoneNumber)
    }
    
    func testMediaType() {
        let imageType = MediaType.from(mimeType: "image/jpeg")
        if case .image(let subtype) = imageType {
            XCTAssertEqual(subtype, "jpeg")
        } else {
            XCTFail("Expected image type")
        }
        
        XCTAssertEqual(imageType.mimeType, "image/jpeg")
        
        let unknownType = MediaType.from(mimeType: nil)
        XCTAssertEqual(unknownType, .unknown)
    }
    
    func testMessage() {
        let message = Message(
            rowid: 1,
            guid: "test-guid",
            text: "Hello world",
            service: "iMessage",
            date: 0,
            isFromMe: true
        )
        
        XCTAssertEqual(message.id, 1)
        XCTAssertEqual(message.serviceType, .iMessage)
        XCTAssertTrue(message.isFromMe)
        XCTAssertFalse(message.hasAttachments)
        XCTAssertFalse(message.wasEdited)
    }
    
    func testChat() {
        let chat = Chat(
            rowid: 1,
            chatIdentifier: "chat123456",
            serviceName: "iMessage",
            displayName: "Test Group"
        )
        
        XCTAssertEqual(chat.id, 1)
        XCTAssertTrue(chat.isGroupChat)
        XCTAssertFalse(chat.isDirectMessage)
        XCTAssertEqual(chat.name, "Test Group")
        XCTAssertTrue(chat.hasCustomName)
    }
    
    func testAttachment() {
        let attachment = Attachment(
            rowid: 1,
            filename: "test.jpg",
            mimeType: "image/jpeg",
            totalBytes: 1024
        )
        
        XCTAssertEqual(attachment.id, 1)
        XCTAssertTrue(attachment.isImage)
        XCTAssertFalse(attachment.isVideo)
        XCTAssertEqual(attachment.fileExtension, "jpg")
        XCTAssertNotNil(attachment.formattedFileSize)
    }
    
    func testDatabasePath() {
        let path = DatabaseConnection.defaultDatabasePath()
        XCTAssertTrue(path.contains("Library/Messages/chat.db"))
    }
}
