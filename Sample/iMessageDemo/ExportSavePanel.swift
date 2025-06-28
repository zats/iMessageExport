import SwiftUI
import iMessageExport
import UniformTypeIdentifiers
import Contacts

struct ExportSavePanel: View {
    let chat: Chat
    let exporter: iMessageExport
    let onExportComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .markdown
    @State private var exportDepth: ExportDepth = .entireChat
    @State private var customMessageCount: Int = 50
    @State private var customDayCount: Int = 7
    @State private var exportAssets: Bool = true
    @State private var useContactNames: Bool = true
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
                
                // Export Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Options")
                        .font(.headline)
                    
                    Toggle("Export attachments", isOn: $exportAssets)
                        .help(exportFormat == .bundle ? 
                              "Creates attachments/ folder in bundle" : 
                              "Creates [filename]_attachments/ folder next to .md file")
                    
                    Toggle("Use contact names", isOn: $useContactNames)
                        .help("Uses display names from Contacts app instead of phone numbers/emails")
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
    
    private func createContactLookup() -> ContactLookupFunction? {
        guard useContactNames else { return nil }
        return { @Sendable (identifier: String) async -> String? in
            return await lookupContactInternal(identifier)
        }
    }
    
    private func lookupContactInternal(_ identifier: String) async -> String? {
        return await withCheckedContinuation { continuation in
            let store = CNContactStore()
            
            // First check authorization status
            let status = CNContactStore.authorizationStatus(for: .contacts)
            
            if status == .authorized {
                let result = performContactLookup(identifier, store: store)
                continuation.resume(returning: result)
            } else {
                // Request authorization if needed
                store.requestAccess(for: .contacts) { granted, error in
                    if granted {
                        let result = self.performContactLookup(identifier, store: store)
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    private func performContactLookup(_ identifier: String, store: CNContactStore) -> String? {
        findContactByPhoneNumber(identifier, store: store) ?? findContactByEmail(identifier, store: store)
    }
    
    private func findContactByPhoneNumber(_ phoneNumber: String, store: CNContactStore) -> String? {
        do {
            let predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: phoneNumber))
            return try findContactWithPredicate(predicate, store: store)
        } catch {
            return nil
        }
    }
    
    private func findContactByEmail(_ email: String, store: CNContactStore) -> String? {
        do {
            let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
            return try findContactWithPredicate(predicate, store: store)
        } catch {
            return nil
        }
    }
    
    private func findContactWithPredicate(_ predicate: NSPredicate, store: CNContactStore) throws -> String? {
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactMiddleNameKey,
            CNContactNicknameKey,
            CNContactNamePrefixKey,
            CNContactNameSuffixKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
        ] as [CNKeyDescriptor]
        
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        
        guard let contact = contacts.first else { return nil }
        
        // Use nickname if available
        if !contact.nickname.isEmpty {
            return contact.nickname
        }
        
        // Use CNContactFormatter for proper display name formatting
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        
        if let displayName = formatter.string(from: contact), !displayName.isEmpty {
            return displayName
        }
        
        return nil
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
            _ = await exporter.createMarkdownExporter()
            
            await MainActor.run { exportProgress = 0.3 }
            
            switch exportFormat {
            case .markdown:
                let markdown: String
                
                // For markdown exports with assets, create a custom exporter with appropriate attachments directory
                if exportAssets {
                    let attachmentsDirName = url.deletingPathExtension().lastPathComponent + "_attachments"
                    let attachmentsDir = url.deletingLastPathComponent().appendingPathComponent(attachmentsDirName)
                    
                    let contactLookup: ContactLookupFunction? = createContactLookup()
                    
                    let options: MarkdownExportOptions
                    switch exportDepth {
                    case .entireChat:
                        options = MarkdownExportOptions(attachmentsDirectory: "./\(attachmentsDirName)", contactLookup: contactLookup)
                    case .recentMessages:
                        options = MarkdownExportOptions(attachmentsDirectory: "./\(attachmentsDirName)", messageLimit: customMessageCount, contactLookup: contactLookup)
                    case .recentDays:
                        options = MarkdownExportOptions(attachmentsDirectory: "./\(attachmentsDirName)", dateRange: DateRange.lastDays(customDayCount), contactLookup: contactLookup)
                    }
                    
                    let customExporter = await MarkdownExporter(exporter: exporter, options: options)
                    markdown = try await customExporter.exportChat(chatId: chat.rowid)
                    
                    // Create attachments directory and copy files
                    try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
                    let messages = try await exporter.getMessages(forChatId: chat.rowid)
                    for message in messages {
                        if message.hasAttachments {
                            let attachments = try await exporter.getAttachments(forMessageId: message.rowid)
                            for attachment in attachments {
                                try await customExporter.copyAttachmentToBundle(attachment, to: attachmentsDir)
                            }
                        }
                    }
                } else {
                    // Export without assets - use default options but no attachments directory
                    let contactLookup: ContactLookupFunction? = createContactLookup()
                    
                    let options: MarkdownExportOptions
                    switch exportDepth {
                    case .entireChat:
                        options = MarkdownExportOptions(attachmentsDirectory: "", contactLookup: contactLookup)
                    case .recentMessages:
                        options = MarkdownExportOptions(attachmentsDirectory: "", messageLimit: customMessageCount, contactLookup: contactLookup)
                    case .recentDays:
                        options = MarkdownExportOptions(attachmentsDirectory: "", dateRange: DateRange.lastDays(customDayCount), contactLookup: contactLookup)
                    }
                    
                    let customExporter = await MarkdownExporter(exporter: exporter, options: options)
                    markdown = try await customExporter.exportChat(chatId: chat.rowid)
                }
                
                await MainActor.run { exportProgress = 0.8 }
                
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                
            case .bundle:
                // For bundle export, we need to adjust the exporter options based on depth and assets preference
                let contactLookup: ContactLookupFunction? = createContactLookup()
                let options: MarkdownExportOptions
                
                if exportAssets {
                    switch exportDepth {
                    case .entireChat:
                        options = MarkdownExportOptions(contactLookup: contactLookup)
                    case .recentMessages:
                        options = MarkdownExportOptions(messageLimit: customMessageCount, contactLookup: contactLookup)
                    case .recentDays:
                        options = MarkdownExportOptions(dateRange: DateRange.lastDays(customDayCount), contactLookup: contactLookup)
                    }
                    
                    let customExporter = await MarkdownExporter(exporter: exporter, options: options)
                    try await customExporter.exportChatBundle(chatId: chat.rowid, to: url)
                } else {
                    // Export bundle without attachments - create minimal bundle
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    
                    switch exportDepth {
                    case .entireChat:
                        options = MarkdownExportOptions(attachmentsDirectory: "", contactLookup: contactLookup)
                    case .recentMessages:
                        options = MarkdownExportOptions(attachmentsDirectory: "", messageLimit: customMessageCount, contactLookup: contactLookup)
                    case .recentDays:
                        options = MarkdownExportOptions(attachmentsDirectory: "", dateRange: DateRange.lastDays(customDayCount), contactLookup: contactLookup)
                    }
                    
                    let customExporter = await MarkdownExporter(exporter: exporter, options: options)
                    
                    // Export markdown
                    let markdown = try await customExporter.exportChat(chatId: chat.rowid)
                    let indexMarkdownURL = url.appendingPathComponent("index.md")
                    try markdown.write(to: indexMarkdownURL, atomically: true, encoding: .utf8)
                    
                    // Generate HTML version
                    let html = try await customExporter.generateHTML(from: markdown, chatTitle: chatTitle)
                    let indexHTMLURL = url.appendingPathComponent("index.html")
                    try html.write(to: indexHTMLURL, atomically: true, encoding: .utf8)
                }
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
