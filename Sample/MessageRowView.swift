import iMessageExport
import SwiftUI

struct MessageRowView: View {
    let message: Message
    let handles: [Int32: String]
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Sender avatar/indicator
            VStack {
                if message.isFromMe {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("Me")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Header with sender and timestamp
                HStack {
                    Text(senderName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(message.sentDate, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Main message content based on variant
                MessageContentView(message: message)
                
                // Message metadata
                MessageMetadataView(message: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var senderName: String {
        if message.isFromMe {
            return "You"
        } else if let handleId = message.handleId,
                  let name = handles[handleId] {
            return name
        } else {
            return "Unknown"
        }
    }
}

struct MessageContentView: View {
    let message: Message
    
    var body: some View {
        Group {
            switch message.variant {
            case .normal:
                NormalMessageContent(message: message)
                
            case .edited:
                EditedMessageContent(message: message)
                
            case .tapback(let action, let tapback):
                TapbackContent(action: action, tapback: tapback)
                
            case .app(let balloon):
                AppMessageContent(message: message, balloon: balloon)
                
            case .groupAction(let action):
                GroupActionContent(action: action)
                
            case .sharePlay:
                SharePlayContent()
                
            case .locationShare(let status):
                LocationShareContent(status: status)
                
            case .audioMessageKept:
                AudioKeptContent()
                
            case .unknown(let itemType):
                UnknownMessageContent(itemType: itemType)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NormalMessageContent: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isFromMe ? Color.blue : Color.secondary.opacity(0.2))
                    )
                    .foregroundColor(message.isFromMe ? .white : .primary)
            }
            
            if message.hasAttachments {
                AttachmentIndicator(count: Int(message.numAttachments))
            }
            
            if message.hasExpressiveEffect {
                ExpressiveEffectIndicator(effect: message.expressiveEffect)
            }
        }
    }
}

struct EditedMessageContent: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isFromMe ? Color.blue : Color.secondary.opacity(0.2))
                    )
                    .foregroundColor(message.isFromMe ? .white : .primary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.caption)
                Text("Edited")
                    .font(.caption)
                if let editDate = message.editedDate {
                    Text("at \(editDate, format: .dateTime.hour().minute())")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
    }
}

struct TapbackContent: View {
    let action: TapbackAction
    let tapback: Tapback
    
    var body: some View {
        HStack(spacing: 8) {
            Text(tapback.displayName)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(action == .added ? "Reaction added" : "Reaction removed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(tapback.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct AppMessageContent: View {
    let message: Message
    let balloon: CustomBalloon
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: appIcon)
                    .foregroundColor(appColor)
                    .font(.headline)
                
                VStack(alignment: .leading) {
                    Text(balloon.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("App Integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(appColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(appColor.opacity(0.3), lineWidth: 1)
                )
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
        case .slideshow: return "photo.stack"
        case .checkIn: return "checkmark.shield"
        case .appStore: return "app.badge"
        case .fitness: return "figure.run"
        case .game: return "gamecontroller"
        case .business: return "building.2"
        default: return "app"
        }
    }
    
    private var appColor: Color {
        switch balloon {
        case .url: return .blue
        case .applePay: return .green
        case .music: return .pink
        case .findMy: return .orange
        case .handwriting: return .purple
        case .digitalTouch: return .indigo
        case .slideshow: return .cyan
        case .checkIn: return .mint
        case .appStore: return .blue
        case .fitness: return .orange
        case .game: return .red
        case .business: return .brown
        default: return .gray
        }
    }
}

struct GroupActionContent: View {
    let action: GroupAction
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2")
                .foregroundColor(.blue)
            
            Text(action.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct SharePlayContent: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shareplay")
                .foregroundColor(.purple)
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("SharePlay Invitation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Shared activity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct LocationShareContent: View {
    let status: ShareStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location")
                .foregroundColor(.blue)
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Location Sharing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Status: \(String(describing: status))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AudioKeptContent: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundColor(.orange)
            
            Text("Audio message kept")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct UnknownMessageContent: View {
    let itemType: Int32
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark")
                .foregroundColor(.gray)
            
            Text("Unknown message type: \(itemType)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct AttachmentIndicator: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "paperclip")
                .font(.caption)
            Text("\(count) attachment\(count == 1 ? "" : "s")")
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

struct ExpressiveEffectIndicator: View {
    let effect: ExpressiveEffect
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
            Text(effect.displayName)
                .font(.caption)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct MessageMetadataView: View {
    let message: Message
    
    var body: some View {
        HStack(spacing: 12) {
            // Thread indicators
            if message.isReply {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.hasReplies {
                Label("\(message.numReplies) replies", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Delivery status
            if message.deliveredDate != nil {
                Label("Delivered", systemImage: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            if message.readDate != nil {
                Label("Read", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            // Service indicator
            ServiceBadge(service: message.serviceType)
                .font(.caption2)
        }
        .opacity(0.8)
    }
}
