import Foundation
import SQLite

/// Errors that can occur during database operations
public enum DatabaseError: Error, Sendable {
    case fileNotFound(String)
    case connectionFailed(String)
    case queryFailed(String)
    case invalidData(String)
    case permissionDenied(String)
}

/// Actor that manages the SQLite database connection for thread safety
@globalActor
public actor DatabaseActor {
    public static let shared = DatabaseActor()
    private init() {}
}

/// Thread-safe database connection manager
@DatabaseActor
public final class DatabaseConnection: Sendable {
    private let connection: Connection
    private let path: String
    
    /// Initialize a new database connection
    public init(path: String) throws {
        self.path = path
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw DatabaseError.fileNotFound("Database file not found at path: \(path)")
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw DatabaseError.permissionDenied("Cannot read database file at path: \(path)")
        }
        
        do {
            self.connection = try Connection(path, readonly: true)
        } catch {
            throw DatabaseError.connectionFailed("Failed to connect to database: \(error.localizedDescription)")
        }
    }
    
    /// Get the default iMessage database path
    nonisolated public static func defaultDatabasePath() -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Messages")
            .appendingPathComponent("chat.db")
            .path
    }
    
    /// Create a connection to the default iMessage database
    public static func defaultConnection() throws -> DatabaseConnection {
        let path = defaultDatabasePath()
        return try DatabaseConnection(path: path)
    }
    
    /// Execute a query and return the raw results
    internal func execute(_ query: String) throws -> [[String: Any]] {
        do {
            var results: [[String: Any]] = []
            let statement = try connection.prepare(query)
            
            for row in statement {
                var rowDict: [String: Any] = [:]
                for (index, value) in row.enumerated() {
                    let columnName = statement.columnNames[index]
                    rowDict[columnName] = value
                }
                results.append(rowDict)
            }
            
            return results
        } catch {
            throw DatabaseError.queryFailed("Query failed: \(error.localizedDescription)")
        }
    }
    
    /// Execute a prepared statement
    internal func prepare(_ query: String) throws -> Statement {
        do {
            return try connection.prepare(query)
        } catch {
            throw DatabaseError.queryFailed("Failed to prepare statement: \(error.localizedDescription)")
        }
    }
    
    /// Get table information
    public func getTableInfo(_ tableName: String) throws -> [[String: Any]] {
        let query = "PRAGMA table_info(\(tableName))"
        return try execute(query)
    }
    
    /// Check if a table exists
    public func tableExists(_ tableName: String) throws -> Bool {
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(tableName)'"
        let results = try execute(query)
        return !results.isEmpty
    }
    
    /// Get the database schema version
    public func getSchemaVersion() throws -> Int {
        let query = "PRAGMA user_version"
        let results = try execute(query)
        
        guard let first = results.first,
              let version = first["user_version"] as? Int64 else {
            return 0
        }
        
        return Int(version)
    }
    
    /// Close the database connection
    public func close() {
        // SQLite.swift handles connection cleanup automatically
    }
}
