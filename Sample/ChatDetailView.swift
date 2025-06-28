import SwiftUI
import iMessageExport

struct ChatDetailView: View {
    let chat: Chat
    let exporter: iMessageExport
    
    @State private var messages: [Message] = []
    @State private var handles: [Int32: String] = [:]
    @State private var isLoading = true
    @State private var error: (any Error)?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                ErrorView(error: error) {
                    await loadMessages()
                }
            } else if messages.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No messages in this conversation")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageRowView(message: message, handles: handles)
                                    .id(message.rowid)
                            }
                        }
                        .padding()
                    }
                    .defaultScrollAnchor(.bottom)
                    .background(Color(NSColor.textBackgroundColor))
                    .onAppear {
                        // Scroll to bottom when messages first load
                        if let lastMessage = messages.last {
                            proxy.scrollTo(lastMessage.rowid, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle(chat.name)
        .navigationSubtitle(chatSubtitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await loadMessages() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadMessages()
        }
    }
    
    private var chatSubtitle: String {
        var parts: [String] = []
        
        if chat.isGroupChat {
            parts.append("Group Chat")
        } else {
            parts.append("Direct Message")
        }
        
        parts.append(chat.service.displayName)
        
        if !messages.isEmpty {
            parts.append("\(messages.count) messages")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func loadMessages() async {
        do {
            isLoading = true
            error = nil
            
            // Load messages and handles concurrently
            async let messagesTask = exporter.getMessages(forChatId: chat.rowid)
            async let handlesTask = exporter.createHandleMapping()
            
            (messages, handles) = try await (messagesTask, handlesTask)
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}