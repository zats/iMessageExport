import Foundation
import SQLite

/// Repository for accessing handle data from the database
@DatabaseActor
public final class HandleRepository: Sendable {
    private let connection: DatabaseConnection
    
    public init(connection: DatabaseConnection) {
        self.connection = connection
    }
    
    /// Fetch all handles from the database
    public func fetchAllHandles() async throws -> [Handle] {
        let query = """
            SELECT rowid, id, person_centric_id
            FROM handle
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseHandle(from: row)
        }
    }
    
    /// Fetch a specific handle by ID
    public func fetchHandle(withId handleId: Int32) async throws -> Handle? {
        let query = """
            SELECT rowid, id, person_centric_id
            FROM handle
            WHERE rowid = \(handleId)
            LIMIT 1
        """
        
        let results = try connection.execute(query)
        return results.first.flatMap { row in
            parseHandle(from: row)
        }
    }
    
    /// Fetch handles for a specific chat
    public func fetchHandles(forChatId chatId: Int32) async throws -> [Handle] {
        let query = """
            SELECT DISTINCT h.rowid, h.id, h.person_centric_id
            FROM handle h
            JOIN chat_handle_join chj ON h.rowid = chj.handle_id
            WHERE chj.chat_id = \(chatId)
            ORDER BY h.rowid
        """
        
        let results = try connection.execute(query)
        return results.compactMap { row in
            parseHandle(from: row)
        }
    }
    
    /// Fetch handle by contact identifier
    public func fetchHandle(withContactId contactId: String) async throws -> Handle? {
        let query = """
            SELECT rowid, id, person_centric_id
            FROM handle
            WHERE id = '\(contactId)'
            LIMIT 1
        """
        
        let results = try connection.execute(query)
        return results.first.flatMap { row in
            parseHandle(from: row)
        }
    }
    
    /// Fetch handles that share the same person_centric_id (duplicates)
    public func fetchDuplicateHandles() async throws -> [[Handle]] {
        let query = """
            SELECT rowid, id, person_centric_id
            FROM handle
            WHERE person_centric_id IS NOT NULL
            ORDER BY person_centric_id, rowid
        """
        
        let results = try connection.execute(query)
        let handles = results.compactMap { row in
            parseHandle(from: row)
        }
        
        // Group by person_centric_id
        var groups: [String: [Handle]] = [:]
        for handle in handles {
            guard let personCentricId = handle.personCentricId else { continue }
            groups[personCentricId, default: []].append(handle)
        }
        
        // Return only groups with more than one handle
        return groups.values.filter { $0.count > 1 }
    }
    
    /// Create a mapping of handle IDs to contact identifiers
    public func createHandleMapping() async throws -> [Int32: String] {
        let query = """
            SELECT rowid, id
            FROM handle
            ORDER BY rowid
        """
        
        let results = try connection.execute(query)
        var mapping: [Int32: String] = [:]
        
        // Handle ID 0 represents "Me" in group chats
        mapping[0] = "Me"
        
        for row in results {
            guard let rowid = row["rowid"] as? Int64,
                  let id = row["id"] as? String else {
                continue
            }
            mapping[Int32(rowid)] = id
        }
        
        return mapping
    }
    
    /// Parse a handle from database row data
    private func parseHandle(from row: [String: Any]) -> Handle? {
        guard let rowid = row["rowid"] as? Int64,
              let id = row["id"] as? String else {
            return nil
        }
        
        return Handle(
            rowid: Int32(rowid),
            id: id,
            personCentricId: row["person_centric_id"] as? String
        )
    }
}