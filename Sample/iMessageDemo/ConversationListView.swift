import SwiftUI
import iMessageExport
import UniformTypeIdentifiers

struct ConversationListView: View {
    @Binding var selectedChat: Chat?
    @Binding var isLoading: Bool
    @Binding var error: (any Error)?
    @Binding var exporter: iMessageExport?
    
    @State private var chats: [Chat] = []
    @State private var handles: [Int32: String] = [:]
    @State private var searchText = ""
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var chatToExport: Chat?
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chats
        } else {
            return chats.filter { chat in
                displayName(for: chat).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List(filteredChats, id: \.id, selection: $selectedChat) { chat in
            ConversationRowView(chat: chat, handles: handles)
                .tag(chat)
                .contextMenu {
                    Button("Export Chat...") {
                        chatToExport = chat
                    }
                    .disabled(exporter == nil)
                }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search conversations")
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isExporting {
                    HStack {
                        ProgressView(value: exportProgress)
                            .frame(width: 60)
                        Text("Exporting...")
                            .font(.caption)
                    }
                } else {
                    Button("Export All") {
                        Task {
                            await exportAllChats()
                        }
                    }
                    .disabled(chats.isEmpty || isLoading)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Loading conversations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Failed to load conversations")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await loadData()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else if chats.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No conversations found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Make sure you have granted Full Disk Access to Xcode in System Preferences > Privacy & Security > Full Disk Access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .task(id: exporter != nil) {
            if exporter != nil {
                await loadData()
            }
        }
        .sheet(item: $chatToExport) { chat in
            if let exporter = exporter {
                ExportSavePanel(chat: chat, exporter: exporter) {
                    // Export completed callback
                }
            }
        }
    }
    
    private func loadData() async {
        guard let exporter else { return }
        
        do {
            isLoading = true
            error = nil
            
            async let chatsTask = exporter.getAllChatsSortedByLastMessage()
            async let handlesTask = exporter.createHandleMapping()
            
            (chats, handles) = try await (chatsTask, handlesTask)
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    private func displayName(for chat: Chat) -> String {
        if let displayName = chat.displayName, !displayName.isEmpty {
            return displayName
        }
        
        if chat.isDirectMessage {
            return chat.chatIdentifier
        } else {
            return "Group Chat"
        }
    }
    
    private func exportAllChats() async {
        guard let exporter else { return }
        
        await MainActor.run {
            isExporting = true
            exportProgress = 0
        }
        
        do {
            let markdownExporter = await exporter.createMarkdownExporter()
            let exportResults = try await markdownExporter.exportAllChats()
            
            // Save all exports to a folder
            let savePanel = NSSavePanel()
            savePanel.title = "Export All Conversations"
            savePanel.prompt = "Export"
            savePanel.canCreateDirectories = true
            
            await MainActor.run {
                savePanel.begin { result in
                    if result == .OK, let selectedURL = savePanel.url {
                        Task {
                            await saveExports(exportResults, to: selectedURL)
                        }
                    }
                    isExporting = false
                }
            }
        } catch {
            await MainActor.run {
                isExporting = false
                // Could show error alert here
                print("Export failed: \(error)")
            }
        }
    }
    
    private func saveExports(_ exports: [String: String], to directory: URL) async {
        let total = exports.count
        var completed = 0
        
        for (chatName, markdown) in exports {
            let fileURL = directory.appendingPathComponent(chatName)
            
            do {
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save \(fileURL): \(error)")
            }
            
            completed += 1
            await MainActor.run {
                exportProgress = Double(completed) / Double(total)
            }
        }
        
        await MainActor.run {
            isExporting = false
        }
    }
}

struct ConversationRowView: View {
    let chat: Chat
    let handles: [Int32: String]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(chat.chatIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if chat.isGroupChat {
                    Label("Group", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                ServiceBadgeView(service: chat.serviceName ?? "Unknown")
            }
        }
        .padding(.vertical, 2)
    }
    
    private var displayName: String {
        if let displayName = chat.displayName, !displayName.isEmpty {
            return displayName
        }
        
        if chat.isDirectMessage {
            return chat.chatIdentifier
        } else {
            return "Group Chat"
        }
    }
}

struct ServiceBadgeView: View {
    let service: String
    
    var body: some View {
        Text(service.uppercased())
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(backgroundColor)
            )
            .foregroundColor(.white)
    }
    
    private var backgroundColor: Color {
        switch service.lowercased() {
        case "imessage":
            return .blue
        case "sms":
            return .green
        case "rcs":
            return .orange
        default:
            return .gray
        }
    }
}
