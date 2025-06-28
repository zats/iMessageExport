import iMessageExport
import SwiftUI

struct ConversationListView: View {
    @Binding var selectedChat: Chat?
    @Binding var isLoading: Bool
    @Binding var error: (any Error)?
    @Binding var exporter: iMessageExport?
    
    @State private var chats: [Chat] = []
    @State private var handles: [Int32: String] = [:]
    @State private var chatStats: [Int32: ChatStatistics] = [:]
    @State private var searchText = ""
    @State private var loadingChats = false
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chats
        } else {
            return chats.filter { chat in
                chat.name.localizedCaseInsensitiveContains(searchText) ||
                (chat.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack {
            if let error = error {
                ErrorView(error: error) {
                    await loadData()
                }
            } else {
                List(filteredChats, id: \.rowid, selection: $selectedChat) { chat in
                    ConversationRowView(
                        chat: chat,
                        handles: handles,
                        stats: chatStats[chat.rowid]
                    )
                    .tag(chat)
                }
                .listStyle(.sidebar)
                .searchable(text: $searchText, prompt: "Search conversations")
                .navigationTitle("Messages (\(chats.count))")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { Task { await loadData() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(loadingChats)
                    }
                }
                .overlay {
                    if loadingChats {
                        ProgressView("Loading conversations...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    }
                }
            }
        }
        .task {
            if exporter != nil && chats.isEmpty {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        guard let exporter = exporter else { return }
        
        do {
            loadingChats = true
            error = nil
            
            // Load chats and handles concurrently
            async let chatsTask = exporter.getAllChats()
            async let handlesTask = exporter.createHandleMapping()
            
            (chats, handles) = try await (chatsTask, handlesTask)
            
            // Load stats for top chats
            await loadChatStatistics()
            
            loadingChats = false
        } catch {
            self.error = error
            loadingChats = false
        }
    }
    
    private func loadChatStatistics() async {
        guard let exporter = exporter else { return }
        
        // Load stats for first 50 chats to avoid overwhelming the database
        let topChats = Array(chats.prefix(50))
        
        await withTaskGroup(of: (Int32, ChatStatistics?).self) { group in
            for chat in topChats {
                group.addTask {
                    do {
                        let stats = try await exporter.getChatStatistics(chatId: chat.rowid)
                        return (chat.rowid, stats)
                    } catch {
                        return (chat.rowid, nil)
                    }
                }
            }
            
            for await (chatId, stats) in group {
                if let stats = stats {
                    await MainActor.run {
                        chatStats[chatId] = stats
                    }
                }
            }
        }
    }
}

struct ConversationRowView: View {
    let chat: Chat
    let handles: [Int32: String]
    let stats: ChatStatistics?
    
    var body: some View {
        HStack(spacing: 12) {
            // Chat icon
            VStack {
                Image(systemName: chat.isGroupChat ? "person.3.fill" : "person.crop.circle")
                    .font(.title2)
                    .foregroundColor(chat.isGroupChat ? .blue : .green)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    ServiceBadge(service: chat.service)
                }
                
                if let displayName = chat.displayName, displayName != chat.name {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(chat.isGroupChat ? "Group Chat" : "Direct Message")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                        )
                    
                    if let stats = stats {
                        Text("\(stats.messageCount) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if stats.attachmentCount > 0 {
                            Text("• \(stats.attachmentCount) attachments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ServiceBadge: View {
    let service: Service
    
    var body: some View {
        Text(service.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(service.color.opacity(0.2))
            )
            .foregroundColor(service.color)
    }
}

struct ErrorView: View {
    let error: any Error
    let retry: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Error Loading Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if error.localizedDescription.contains("database is locked") || 
               error.localizedDescription.contains("permission denied") {
                Text("💡 Tip: Grant Full Disk Access to Xcode in System Preferences > Security & Privacy > Privacy")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                Task { await retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Service {
    var color: Color {
        switch self {
        case .iMessage:
            return .blue

        case .sms:
            return .green

        case .rcs:
            return .orange

        case .satellite:
            return .purple

        case .other:
            return .teal

        case .unknown:
            return .gray
        }
    }
}
