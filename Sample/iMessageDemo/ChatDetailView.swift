import SwiftUI
import iMessageExport

struct ChatDetailView: View {
    let chat: Chat
    let exporter: iMessageExport
    
    @State private var messages: [Message] = []
    @State private var handles: [Int32: String] = [:]
    @State private var isLoading = true
    @State private var error: (any Error)?
    @State private var reactions: [String: [Message]] = [:]
    @State private var exportedMarkdown: String?
    @State private var showingExportSheet = false
    
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
                                    reactions: reactions[message.guid] ?? []
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
                Menu {
                    Button("Export All Messages") {
                        Task {
                            await exportToMarkdown(type: .all)
                        }
                    }
                    
                    Button("Export Last 50 Messages") {
                        Task {
                            await exportToMarkdown(type: .recent(50))
                        }
                    }
                    
                    Button("Export Last 7 Days") {
                        Task {
                            await exportToMarkdown(type: .lastDays(7))
                        }
                    }
                    
                    Button("Export Threads Only") {
                        Task {
                            await exportToMarkdown(type: .threadsOnly)
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
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
        .sheet(isPresented: $showingExportSheet) {
            if let markdown = exportedMarkdown {
                MarkdownExportSheet(markdown: markdown, chatTitle: chatTitle)
            }
        }
    }
    
    private var chatTitle: String {
        if let displayName = chat.displayName, !displayName.isEmpty {
            return displayName
        }
        
        if chat.isDirectMessage {
            return chat.chatIdentifier
        } else {
            return "Group Chat"
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
    
    private func exportToMarkdown(type: ExportType) async {
        do {
            let markdownExporter = exporter.createMarkdownExporter()
            let markdown: String
            
            switch type {
            case .all:
                markdown = try await markdownExporter.exportChat(chatId: chat.id)
            case .recent(let limit):
                markdown = try await markdownExporter.exportChatWithLimit(chatId: chat.id, messageLimit: limit)
            case .lastDays(let days):
                let dateRange = DateRange.lastDays(days)
                markdown = try await markdownExporter.exportChatInDateRange(chatId: chat.id, dateRange: dateRange)
            case .threadsOnly:
                markdown = try await markdownExporter.exportThreadsOnly(chatId: chat.id)
            }
            
            await MainActor.run {
                exportedMarkdown = markdown
                showingExportSheet = true
            }
        } catch {
            // Handle export error - could show an alert
            print("Export failed: \(error)")
        }
    }
}

enum ExportType {
    case all
    case recent(Int)
    case lastDays(Int)
    case threadsOnly
}