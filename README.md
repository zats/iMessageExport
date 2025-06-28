# iMessageExport

A Swift package for reading and analyzing iMessage data from the macOS Messages app database. Built with Swift 6 concurrency and provides comprehensive semantic classification of message types.

## Installation

Add this package to your Swift project:

```swift
dependencies: [
    .package(path: "/path/to/iMessageExport")
]
```

## Demo App

The package includes a beautiful **native macOS SwiftUI app** that showcases all features:

```bash
swift run iMessageDemo
```

This will launch a **native macOS SwiftUI app** with:

### 🎯 **Features**
- **Split-view interface** - Chat list on the left, messages on the right
- **Real-time loading** - Async data loading with progress indicators
- **Search functionality** - Find conversations quickly
- **Semantic message display** - All message types rendered appropriately:
  - 💬 Normal text messages with proper bubble styling
  - ✏️ Edited messages with edit indicators
  - 😍 Reactions/tapbacks with emoji display
  - 📱 App integrations (Apple Pay, Music, URLs, etc.)
  - 👥 Group actions (member changes, name changes)
  - 🎯 SharePlay invitations
  - 📍 Location sharing
  - 🎵 Audio message notifications

### 🎨 **macOS UI Highlights**
- **Native macOS styling** - Uses NSColor and macOS design patterns
- **Split-view navigation** - NavigationSplitView with proper column sizing
- **Sidebar list style** - macOS-native sidebar appearance
- **Unified toolbar** - macOS-style window toolbar
- **Message bubbles** - Proper styling for sent vs received
- **Service badges** - Visual indicators for iMessage/SMS/RCS
- **Chat statistics** - Message and attachment counts
- **Thread indicators** - Reply and delivery status
- **Expressive effects** - Send effect indicators
- **Keyboard shortcuts** - ⌘R to refresh data
- **Error handling** - Helpful error messages with permission tips

### 📸 **Screenshots**
The app provides a comprehensive view of your iMessage data with:
- Conversation list with search and filtering
- Individual message display with semantic rendering
- Proper macOS native styling and behavior
- Real-time statistics and metadata

**Note:** You may need to grant Full Disk Access to Xcode in System Preferences > Security & Privacy > Privacy > Full Disk Access for the app to access your iMessage database.

## Basic Usage

```swift
import iMessageExport

// Initialize with default database path
let exporter = try await iMessageExport()

// Or specify custom path
let exporter = try await iMessageExport(databasePath: "/path/to/chat.db")

// Fetch data
let messages = try await exporter.getAllMessages()
let chats = try await exporter.getAllChats()
let handles = try await exporter.getAllHandles()

// Always close when done
await exporter.close()
```

## Message Classification System

The package provides rich semantic classification of messages through the `MessageVariant` enum:

### Message Types

```swift
let message: Message = // ... fetch from database

switch message.variant {
case .normal:
    // Regular text message or attachment
    print("Text: \(message.text ?? "No text")")
    
case .edited:
    // Message was edited or unsent
    print("Edited message")
    
case .tapback(let action, let tapback):
    // Reaction/emoji response to another message
    print("\(action == .added ? "Added" : "Removed") \(tapback.displayName)")
    
case .app(let balloon):
    // App integration (URL, Apple Pay, Music, etc.)
    print("App message: \(balloon.displayName)")
    
case .groupAction(let action):
    // Group management (add/remove participant, name change, etc.)
    print("Group action: \(action.description)")
    
case .sharePlay:
    // SharePlay session
    print("SharePlay invitation")
    
case .locationShare(let status):
    // Location sharing
    print("Location sharing: \(status)")
    
case .audioMessageKept:
    // Audio message kept notification
    print("Audio message kept")
    
case .unknown(let itemType):
    // Unknown message type
    print("Unknown message type: \(itemType)")
}
```

### Quick Classification

```swift
if message.isReaction {
    // Handle reactions/tapbacks
    print("This is a reaction")
}

if message.isAnnouncement {
    // Handle group announcements
    print("This is a group announcement")
}

if message.isAppMessage {
    // Handle app integrations
    print("This is an app message")
}

if message.isNormalMessage {
    // Handle regular content
    print("This is normal content")
}
```

## SwiftUI Message Rendering

Here's a simple but comprehensive SwiftUI view for rendering messages:

```swift
import SwiftUI
import iMessageExport

struct MessageView: View {
    let message: Message
    let handles: [Int32: String] // Handle ID to display name mapping
    
    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
            // Message header with sender and timestamp
            HStack {
                if !message.isFromMe {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(message.sentDate, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Main message content
            MessageBubbleView(message: message)
                .frame(maxWidth: 280, alignment: message.isFromMe ? .trailing : .leading)
            
            // Message metadata (if relevant)
            MessageMetadataView(message: message)
        }
        .frame(maxWidth: .infinity, alignment: message.isFromMe ? .trailing : .leading)
        .padding(.horizontal)
    }
    
    private var senderName: String {
        if let handleId = message.handleId,
           let name = handles[handleId] {
            return name
        }
        return "Unknown"
    }
}

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        Group {
            switch message.variant {
            case .normal:
                NormalMessageView(message: message)
                
            case .edited:
                EditedMessageView(message: message)
                
            case .tapback(let action, let tapback):
                TapbackView(action: action, tapback: tapback)
                
            case .app(let balloon):
                AppMessageView(message: message, balloon: balloon)
                
            case .groupAction(let action):
                GroupActionView(action: action)
                
            case .sharePlay:
                SharePlayView()
                
            case .locationShare(let status):
                LocationShareView(status: status)
                
            case .audioMessageKept:
                AudioKeptView()
                
            case .unknown(let itemType):
                UnknownMessageView(itemType: itemType)
            }
        }
        .modifier(MessageBubbleModifier(isFromMe: message.isFromMe))
    }
}

struct NormalMessageView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Text content
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .textSelection(.enabled)
            }
            
            // Attachments
            if message.hasAttachments {
                HStack {
                    Image(systemName: "paperclip")
                    Text("\(message.numAttachments) attachment\(message.numAttachments == 1 ? "" : "s")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Expressive effects
            if message.hasExpressiveEffect {
                HStack {
                    Image(systemName: "star.fill")
                    Text(message.expressiveEffect.displayName)
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }
}

struct EditedMessageView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let text = message.text {
                Text(text)
                    .textSelection(.enabled)
            }
            
            HStack {
                Image(systemName: "pencil")
                Text("Edited")
                if let editDate = message.editedDate {
                    Text(editDate, style: .time)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct TapbackView: View {
    let action: TapbackAction
    let tapback: Tapback
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tapback.displayName)
                .font(.title2)
            
            Text(action == .added ? "added" : "removed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.2))
        )
    }
}

struct AppMessageView: View {
    let message: Message
    let balloon: CustomBalloon
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: appIcon)
                    .foregroundColor(appColor)
                Text(balloon.displayName)
                    .font(.headline)
            }
            
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .font(.body)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appColor.opacity(0.1))
        )
    }
    
    private var appIcon: String {
        switch balloon {
        case .url: return "link"
        case .applePay: return "creditcard"
        case .music: return "music.note"
        case .findMy: return "location"
        case .handwriting: return "scribble"
        case .digitalTouch: return "hand.tap"
        default: return "app"
        }
    }
    
    private var appColor: Color {
        switch balloon {
        case .url: return .blue
        case .applePay: return .green
        case .music: return .pink
        case .findMy: return .orange
        default: return .purple
        }
    }
}

struct GroupActionView: View {
    let action: GroupAction
    
    var body: some View {
        HStack {
            Image(systemName: "person.2")
                .foregroundColor(.secondary)
            Text(action.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

struct SharePlayView: View {
    var body: some View {
        HStack {
            Image(systemName: "shareplay")
                .foregroundColor(.purple)
            Text("SharePlay Invitation")
                .font(.headline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }
}

struct LocationShareView: View {
    let status: ShareStatus
    
    var body: some View {
        HStack {
            Image(systemName: "location")
                .foregroundColor(.blue)
            Text("Location: \(status)")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct AudioKeptView: View {
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.orange)
            Text("Audio message kept")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct UnknownMessageView: View {
    let itemType: Int32
    
    var body: some View {
        HStack {
            Image(systemName: "questionmark")
                .foregroundColor(.gray)
            Text("Unknown message type: \(itemType)")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct MessageMetadataView: View {
    let message: Message
    
    var body: some View {
        HStack(spacing: 12) {
            // Thread indicator
            if message.isReply {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Replies count
            if message.hasReplies {
                Label("\(message.numReplies) replies", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Delivery status
            if let deliveredDate = message.deliveredDate {
                Label("Delivered", systemImage: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            if let readDate = message.readDate {
                Label("Read", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct MessageBubbleModifier: ViewModifier {
    let isFromMe: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isFromMe ? Color.blue : Color.secondary.opacity(0.2))
            )
            .foregroundColor(isFromMe ? .white : .primary)
    }
}
```

## Complete Chat View Example

```swift
struct ChatView: View {
    @State private var messages: [Message] = []
    @State private var handles: [Int32: String] = [:]
    @State private var exporter: iMessageExport?
    
    let chatId: Int32
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                    MessageView(message: message, handles: handles)
                }
            }
            .padding(.vertical)
        }
        .task {
            await loadData()
        }
        .onDisappear {
            Task {
                await exporter?.close()
            }
        }
    }
    
    private func loadData() async {
        do {
            let exporter = try await iMessageExport()
            self.exporter = exporter
            
            // Load messages and handles
            async let messagesTask = exporter.getMessages(forChatId: chatId)
            async let handlesTask = exporter.createHandleMapping()
            
            (messages, handles) = try await (messagesTask, handlesTask)
        } catch {
            print("Error loading data: \(error)")
        }
    }
}
```

## Semantic Enums Reference

### MessageVariant
- `.normal` - Regular text/attachment messages
- `.edited` - Edited or unsent messages
- `.tapback(action, type)` - Reactions with specific emoji/action
- `.app(balloon)` - App integrations (URL, Apple Pay, Music, etc.)
- `.groupAction(action)` - Group management actions
- `.sharePlay` - SharePlay invitations
- `.locationShare(status)` - Location sharing
- `.audioMessageKept` - Audio message notifications
- `.unknown(itemType)` - Unknown message types

### Tapback Types
- `.loved` ❤️ - Heart reaction
- `.liked` 👍 - Thumbs up
- `.disliked` 👎 - Thumbs down  
- `.laughed` 😂 - Laughing face
- `.emphasized` ‼️ - Exclamation points
- `.questioned` ❓ - Question marks
- `.emoji(String?)` - Custom emoji
- `.sticker` - Sticker reactions

### GroupAction Types
- `.participantAdded(handleId)` - Someone was added
- `.participantRemoved(handleId)` - Someone was removed
- `.nameChanged(String?)` - Group name changed
- `.participantLeft` - Someone left
- `.iconChanged` - Group photo changed
- `.iconRemoved` - Group photo removed

### CustomBalloon Types
- `.url` - URL preview
- `.applePay` - Apple Pay transaction
- `.music` - Music sharing
- `.handwriting` - Handwritten message
- `.digitalTouch` - Digital Touch
- `.findMy` - Find My location
- `.checkIn` - Safety Check In
- `.slideshow` - Photos slideshow
- `.application(bundleId)` - Third-party app

### ExpressiveEffect Types
- `.bubble(effect)` - Bubble effects (slam, loud, gentle, invisibleInk)
- `.screen(effect)` - Screen effects (confetti, fireworks, balloons, etc.)
- `.none` - No effect

## Key Properties for Rendering

### Message Classification
- `message.variant` - Main message type classification
- `message.isReaction` - Quick check for reactions
- `message.isAnnouncement` - Quick check for group actions
- `message.isAppMessage` - Quick check for app integrations
- `message.isNormalMessage` - Quick check for regular content

### Content
- `message.text` - Message text content
- `message.hasAttachments` - Whether message has attachments
- `message.numAttachments` - Number of attachments

### Metadata
- `message.isFromMe` - Whether message was sent by user
- `message.sentDate` - When message was sent
- `message.readDate` - When message was read (if available)
- `message.deliveredDate` - When message was delivered (if available)
- `message.editedDate` - When message was edited (if available)

### Threading
- `message.isReply` - Whether this is a reply to another message
- `message.hasReplies` - Whether this message has replies
- `message.numReplies` - Number of replies to this message

### Effects
- `message.hasExpressiveEffect` - Whether message has send effects
- `message.expressiveEffect` - The specific effect (bubble or screen)

## Requirements

- Swift 6.0+
- macOS 14.0+
- Access to the iMessage database (requires Full Disk Access on macOS)

## Database Location

The default iMessage database is located at:
```
~/Library/Messages/chat.db
```

## Security Considerations

- This library only reads data; it never modifies the iMessage database
- On macOS, your app may need Full Disk Access permission to read the iMessage database
- The library opens the database in read-only mode for safety

## Credits

Based on the excellent [imessage-exporter](https://github.com/ReagentX/imessage-exporter) Rust project by Christopher Sardegna.