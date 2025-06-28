import iMessageExport
import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    let exporter: iMessageExport
    @ObservedObject var contactManager: ContactManager
    
    @State private var messages: [Message] = []
    @State private var handles: [Int32: String] = [:]
    @State private var isLoading = true
    @State private var error: (any Error)?
    @State private var reactions: [String: [Message]] = [:]
    @State private var showingExportPanel = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Failed to load messages")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task {
                            await loadMessages()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messagesWithoutReactions) { message in
                                MessageRowView(
                                    message: message, 
                                    handles: handles,
                                    reactions: reactions[message.guid] ?? [],
                                    contactManager: contactManager
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .onChange(of: messages) { _, _ in
                        // Scroll to bottom when messages change
                        if let lastMessage = messagesWithoutReactions.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to bottom when view appears
                        if let lastMessage = messagesWithoutReactions.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle(chatTitle)
        .navigationSubtitle("\(messages.count) messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export") {
                    showingExportPanel = true
                }
                .disabled(isLoading || messages.isEmpty)
            }
        }
        .task(id: chat.id) {
            await loadMessages()
        }
        .refreshable {
            await loadMessages()
        }
        .sheet(isPresented: $showingExportPanel) {
            ExportSavePanel(chat: chat, exporter: exporter) {
                // Export completed callback
            }
        }
    }
    
    private var chatTitle: String {
        if let displayName = chat.displayName, !displayName.isEmpty {
            return displayName
        } else if let contactName = contactManager.lookupContactName(for: chat.chatIdentifier) {
            return contactName
        } else if chat.isDirectMessage {
            return chat.chatIdentifier
        } else {
            return "Untitled"
        }
    }
    
    private var messagesWithoutReactions: [Message] {
        messages.filter { message in
            // Don't filter out reactions that have text content - they should be displayed as messages
            if message.isReaction && (message.text?.isEmpty ?? true) {
                return false // Filter out pure reactions without text
            }
            return true // Keep all other messages, including reactions with text
        }
    }
    
    private func loadMessages() async {
        do {
            isLoading = true
            error = nil
            
            async let messagesTask = exporter.getMessages(forChatId: chat.id)
            async let handlesTask = exporter.createHandleMapping()
            
            let (allMessages, handlesResult) = try await (messagesTask, handlesTask)
            messages = allMessages
            handles = handlesResult
            
            // Group pure reactions (without text content) by their associated message GUID
            reactions = Dictionary(grouping: allMessages.filter { message in
                message.isReaction && (message.text?.isEmpty ?? true)
            }) { message in
                message.associatedMessageGuid ?? ""
            }.filter { !$0.key.isEmpty }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}
