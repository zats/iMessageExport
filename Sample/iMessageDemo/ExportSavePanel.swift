import SwiftUI
import iMessageExport
import UniformTypeIdentifiers

struct ExportSavePanel: View {
    let chat: Chat
    let exporter: iMessageExport
    let onExportComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .markdown
    @State private var exportDepth: ExportDepth = .entireChat
    @State private var customMessageCount: Int = 50
    @State private var customDayCount: Int = 7
    @State private var filename: String = ""
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Export Chat")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(chatTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Export Options
            VStack(alignment: .leading, spacing: 16) {
                // Format Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format")
                        .font(.headline)
                    
                    Picker("Format", selection: $exportFormat) {
                        Text("Markdown (.md)").tag(ExportFormat.markdown)
                        Text("iMessage Bundle (.imessage)").tag(ExportFormat.bundle)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Depth Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RadioButton(
                            isSelected: exportDepth == .entireChat,
                            title: "Entire chat",
                            action: { exportDepth = .entireChat }
                        )
                        
                        HStack {
                            RadioButton(
                                isSelected: exportDepth == .recentMessages,
                                title: "Recent",
                                action: { exportDepth = .recentMessages }
                            )
                            
                            TextField("Count", value: $customMessageCount, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .disabled(exportDepth != .recentMessages)
                            
                            Text("messages")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            RadioButton(
                                isSelected: exportDepth == .recentDays,
                                title: "Last",
                                action: { exportDepth = .recentDays }
                            )
                            
                            TextField("Days", value: $customDayCount, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .disabled(exportDepth != .recentDays)
                            
                            Text("days")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Filename
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save As")
                        .font(.headline)
                    
                    HStack {
                        TextField("Filename", text: $filename)
                            .textFieldStyle(.roundedBorder)
                        
                        Text(exportFormat.fileExtension)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
            
            // Progress
            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress)
                        .frame(maxWidth: .infinity)
                    Text("Exporting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isExporting)
                
                Button("Export") {
                    Task {
                        await performExport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(filename.isEmpty || isExporting)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            filename = sanitizeFilename(chatTitle)
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
    
    private func performExport() async {
        isExporting = true
        exportProgress = 0
        
        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Chat"
        savePanel.nameFieldStringValue = filename + exportFormat.fileExtension
        savePanel.canCreateDirectories = true
        
        if exportFormat == .bundle {
            savePanel.allowedContentTypes = [.directory, .bundle]
        } else {
            savePanel.allowedContentTypes = [.plainText]
        }
        
        await MainActor.run {
            savePanel.begin { result in
                if result == .OK, let selectedURL = savePanel.url {
                    Task {
                        await exportToURL(selectedURL)
                    }
                } else {
                    isExporting = false
                }
            }
        }
    }
    
    private func exportToURL(_ url: URL) async {
        do {
            let markdownExporter = await exporter.createMarkdownExporter()
            
            await MainActor.run { exportProgress = 0.3 }
            
            switch exportFormat {
            case .markdown:
                let markdown: String
                
                switch exportDepth {
                case .entireChat:
                    markdown = try await markdownExporter.exportChat(chatId: chat.rowid)
                case .recentMessages:
                    markdown = try await markdownExporter.exportChatWithLimit(chatId: chat.rowid, messageLimit: customMessageCount)
                case .recentDays:
                    let dateRange = DateRange.lastDays(customDayCount)
                    markdown = try await markdownExporter.exportChatInDateRange(chatId: chat.rowid, dateRange: dateRange)
                }
                
                await MainActor.run { exportProgress = 0.8 }
                
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                
            case .bundle:
                // For bundle export, we need to adjust the exporter options based on depth
                let options: MarkdownExportOptions
                
                switch exportDepth {
                case .entireChat:
                    options = MarkdownExportOptions()
                case .recentMessages:
                    options = MarkdownExportOptions(messageLimit: customMessageCount)
                case .recentDays:
                    options = MarkdownExportOptions(dateRange: DateRange.lastDays(customDayCount))
                }
                
                let customExporter = await MarkdownExporter(exporter: exporter, options: options)
                try await customExporter.exportChatBundle(chatId: chat.rowid, to: url)
            }
            
            await MainActor.run {
                exportProgress = 1.0
                isExporting = false
                onExportComplete()
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isExporting = false
                print("Export failed: \(error)")
            }
        }
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        return filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .filter { !$0.isWhitespace || $0 == " " }
    }
}

struct RadioButton: View {
    let isSelected: Bool
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

enum ExportFormat: CaseIterable {
    case markdown
    case bundle
    
    var fileExtension: String {
        switch self {
        case .markdown: return ".md"
        case .bundle: return ".imessage"
        }
    }
}

enum ExportDepth: CaseIterable {
    case entireChat
    case recentMessages
    case recentDays
}
