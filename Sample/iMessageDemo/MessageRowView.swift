import SwiftUI
import iMessageExport

struct MessageRowView: View {
    let message: Message
    let handles: [Int32: String]
    let reactions: [Message]
    @ObservedObject var contactManager: ContactManager
    
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
            
            // Main message content with reactions
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                MessageBubbleView(message: message)
                    .frame(maxWidth: 280, alignment: message.isFromMe ? .trailing : .leading)
                
                // Reactions attached to this message
                if !reactions.isEmpty {
                    ReactionsView(reactions: reactions, handles: handles)
                        .frame(maxWidth: 280, alignment: message.isFromMe ? .trailing : .leading)
                }
            }
            
            // Message metadata
            MessageMetadataView(message: message)
        }
        .frame(maxWidth: .infinity, alignment: message.isFromMe ? .trailing : .leading)
        .padding(.horizontal)
    }
    
    private var senderName: String {
        if let handleId = message.handleId,
           let name = handles[handleId] {
            return contactManager.lookupContactName(for: name) ?? name
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
                
            case .tapback:
                // This should only render if the message has text content (handled by filtering)
                NormalMessageView(message: message)
                
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
            if let text = message.effectiveText, !text.isEmpty {
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
            if let text = message.effectiveText {
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
            
            if let text = message.effectiveText, !text.isEmpty {
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
            
            if message.isFromMe {
                if message.readDate != nil {
                    Label("Read", systemImage: "checkmark.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if message.deliveredDate != nil {
                    Label("Delivered", systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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

struct ReactionsView: View {
    let reactions: [Message]
    let handles: [Int32: String]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.id) { reaction in
                if case .tapback(let action, let tapback) = reaction.variant {
                    ReactionBubbleView(
                        tapback: tapback,
                        action: action,
                        senderName: senderName(for: reaction)
                    )
                }
            }
        }
    }
    
    private func senderName(for reaction: Message) -> String {
        if reaction.isFromMe {
            return "You"
        } else if let handleId = reaction.handleId,
                  let name = handles[handleId] {
            return name
        }
        return "Unknown"
    }
}

struct ReactionBubbleView: View {
    let tapback: Tapback
    let action: TapbackAction
    let senderName: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(tapback.displayName)
                .font(.caption)
            
            Text(senderName)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .opacity(action == .removed ? 0.5 : 1.0)
    }
}
