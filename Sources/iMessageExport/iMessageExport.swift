import Foundation

/// Main interface for accessing iMessage data
@DatabaseActor
public final class iMessageExport: Sendable {
    private let connection: DatabaseConnection
    private let messageRepository: MessageRepository
    private let chatRepository: ChatRepository
    private let handleRepository: HandleRepository
    private let attachmentRepository: AttachmentRepository
    
    /// Initialize with a custom database path
    public init(databasePath: String) throws {
        self.connection = try DatabaseConnection(path: databasePath)
        self.messageRepository = MessageRepository(connection: connection)
        self.chatRepository = ChatRepository(connection: connection)
        self.handleRepository = HandleRepository(connection: connection)
        self.attachmentRepository = AttachmentRepository(connection: connection)
    }
    
    /// Initialize with the default iMessage database
    public convenience init() throws {
        try self.init(databasePath: DatabaseConnection.defaultDatabasePath())
    }
    
    // MARK: - Message Operations
    
    /// Fetch all messages from the database
    public func getAllMessages() async throws -> [Message] {
        try await messageRepository.fetchAllMessages()
    }
    
    /// Fetch messages for a specific chat
    public func getMessages(forChatId chatId: Int32) async throws -> [Message] {
        try await messageRepository.fetchMessages(forChatId: chatId)
    }
    
    /// Fetch a specific message by GUID
    public func getMessage(withGuid guid: String) async throws -> Message? {
        try await messageRepository.fetchMessage(withGuid: guid)
    }
    
    /// Fetch messages with attachments
    public func getMessagesWithAttachments() async throws -> [Message] {
        try await messageRepository.fetchMessagesWithAttachments()
    }
    
    // MARK: - Chat Operations
    
    /// Fetch all chats from the database
    public func getAllChats() async throws -> [Chat] {
        try await chatRepository.fetchAllChats()
    }
    
    /// Fetch all chats sorted by last message time (most recent first)
    public func getAllChatsSortedByLastMessage() async throws -> [Chat] {
        try await chatRepository.fetchAllChatsSortedByLastMessage()
    }
    
    /// Fetch a specific chat by ID
    public func getChat(withId chatId: Int32) async throws -> Chat? {
        try await chatRepository.fetchChat(withId: chatId)
    }
    
    /// Fetch a chat by its identifier
    public func getChat(withIdentifier identifier: String) async throws -> Chat? {
        try await chatRepository.fetchChat(withIdentifier: identifier)
    }
    
    /// Fetch group chats only
    public func getGroupChats() async throws -> [Chat] {
        try await chatRepository.fetchGroupChats()
    }
    
    /// Fetch direct message chats only
    public func getDirectMessageChats() async throws -> [Chat] {
        try await chatRepository.fetchDirectMessageChats()
    }
    
    /// Get statistics for a chat
    public func getChatStatistics(chatId: Int32) async throws -> ChatStatistics {
        try await chatRepository.getChatStatistics(chatId: chatId)
    }
    
    // MARK: - Handle Operations
    
    /// Fetch all handles from the database
    public func getAllHandles() async throws -> [Handle] {
        try await handleRepository.fetchAllHandles()
    }
    
    /// Fetch a specific handle by ID
    public func getHandle(withId handleId: Int32) async throws -> Handle? {
        try await handleRepository.fetchHandle(withId: handleId)
    }
    
    /// Fetch handles for a specific chat
    public func getHandles(forChatId chatId: Int32) async throws -> [Handle] {
        try await handleRepository.fetchHandles(forChatId: chatId)
    }
    
    /// Create a mapping of handle IDs to display names
    public func createHandleMapping() async throws -> [Int32: String] {
        try await handleRepository.createHandleMapping()
    }
    
    // MARK: - Attachment Operations
    
    /// Fetch all attachments from the database
    public func getAllAttachments() async throws -> [Attachment] {
        try await attachmentRepository.fetchAllAttachments()
    }
    
    /// Fetch attachments for a specific message
    public func getAttachments(forMessageId messageId: Int32) async throws -> [Attachment] {
        try await attachmentRepository.fetchAttachments(forMessageId: messageId)
    }
    
    /// Fetch a specific attachment by ID
    public func getAttachment(withId attachmentId: Int32) async throws -> Attachment? {
        try await attachmentRepository.fetchAttachment(withId: attachmentId)
    }
    
    // MARK: - Database Information
    
    /// Get database schema version
    public func getDatabaseSchemaVersion() async throws -> Int {
        try connection.getSchemaVersion()
    }
    
    /// Check if a table exists in the database
    public func tableExists(_ tableName: String) async throws -> Bool {
        try connection.tableExists(tableName)
    }
    
    /// Close the database connection
    public func close() async {
        connection.close()
    }
    
    // MARK: - Export Operations
    
    /// Create a markdown exporter for this database
    public func createMarkdownExporter(options: MarkdownExportOptions = MarkdownExportOptions()) -> MarkdownExporter {
        MarkdownExporter(exporter: self, options: options)
    }
}
