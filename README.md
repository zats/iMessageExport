# iMessageExport

A Swift 6 library for reading and accessing iMessage data from the local SQLite database on macOS and iOS.

## Overview

This library provides Swift data structures and APIs to read iMessage data directly from the chat.db SQLite database. It's designed with Swift 6 in mind, featuring full concurrency support, strict typing, and modern Swift practices.

## Features

- **Swift 6 Compatible**: Built with Swift 6 language features and strict concurrency
- **Thread-Safe**: Uses actors for safe concurrent database access
- **Comprehensive Data Models**: Full support for messages, chats, attachments, and contacts
- **Type-Safe**: Strongly typed enums and structures for all iMessage data types
- **Modern Swift**: Uses async/await, Sendable types, and Swift 6 features

## Data Models

### Core Types

- **Message**: Represents individual iMessage/SMS messages with full metadata
- **Chat**: Represents conversations (both group chats and direct messages)
- **Handle**: Represents contacts (phone numbers, email addresses)
- **Attachment**: Represents file attachments with metadata
- **Service**: Message service types (iMessage, SMS, RCS, Satellite)

### Message Features Supported

- Text messages with formatting attributes
- Attachments (images, videos, audio, documents)
- Group chat actions (add/remove members, name changes)
- Tapback reactions
- Message editing and unsending
- Thread replies
- Expressive send effects
- Digital Touch and handwriting messages
- App integrations and stickers

## Usage

```swift
import iMessageExport

// Initialize with default iMessage database
let exporter = try iMessageExport()

// Or with custom database path
let exporter = try iMessageExport(databasePath: "/path/to/chat.db")

// Fetch all messages
let messages = try await exporter.getAllMessages()

// Fetch messages for a specific chat
let chatMessages = try await exporter.getMessages(forChatId: 1)

// Fetch all chats
let chats = try await exporter.getAllChats()

// Fetch group chats only
let groupChats = try await exporter.getGroupChats()

// Fetch attachments
let attachments = try await exporter.getAllAttachments()

// Get chat statistics
let stats = try await exporter.getChatStatistics(chatId: 1)
print("Messages: \\(stats.messageCount), Attachments: \\(stats.attachmentCount)")

// Close connection when done
await exporter.close()
```

## Data Access Patterns

### Messages

```swift
for message in messages {
    print("From: \\(message.isFromMe ? "Me" : "Other")")
    print("Text: \\(message.text ?? "No text")")
    print("Service: \\(message.serviceType)")
    print("Date: \\(message.sentDate)")
    
    if message.hasAttachments {
        let attachments = try await exporter.getAttachments(forMessageId: message.rowid)
        print("Attachments: \\(attachments.count)")
    }
    
    if message.wasEdited {
        print("Edited on: \\(message.editedDate!)")
    }
}
```

### Chats

```swift
for chat in chats {
    print("Chat: \\(chat.name)")
    print("Type: \\(chat.isGroupChat ? "Group" : "Direct")")
    print("Service: \\(chat.service)")
    
    let stats = try await exporter.getChatStatistics(chatId: chat.rowid)
    print("Messages: \\(stats.messageCount)")
}
```

## Requirements

- Swift 6.0+
- macOS 14.0+ / iOS 17.0+
- Access to the iMessage database (typically requires Full Disk Access on macOS)

## Database Location

The default iMessage database is located at:
```
~/Library/Messages/chat.db
```

## Security Considerations

- This library only reads data; it never modifies the iMessage database
- On macOS, your app may need Full Disk Access permission to read the iMessage database
- The library opens the database in read-only mode for safety

## Architecture

The library is organized into several key components:

- **Models**: Swift data structures representing iMessage entities
- **Database**: Thread-safe database connection and query execution
- **Repositories**: Specialized data access objects for different entity types
- **Main Interface**: The primary `iMessageExport` class providing the public API

All database operations are performed through a global actor (`DatabaseActor`) to ensure thread safety and prevent data races.

## Swift 6 Features Used

- **Strict Concurrency**: All types are `Sendable` and thread-safe
- **Global Actors**: Database operations are isolated using `@DatabaseActor`
- **Modern Language Features**: Uses upcoming Swift features like `ExistentialAny`
- **Type Safety**: Extensive use of `@frozen` enums and strong typing

## License

This project is licensed under the same license as the original Rust implementation (GPL-3.0-or-later).

## Credits

Based on the excellent [imessage-exporter](https://github.com/ReagentX/imessage-exporter) Rust project by Christopher Sardegna.