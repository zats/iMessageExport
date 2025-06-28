import SwiftUI
import UniformTypeIdentifiers

struct MarkdownExportSheet: View {
    let markdown: String
    let chatTitle: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Preview")
                        .font(.headline)
                    
                    ScrollView {
                        Text(markdown)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 400)
                    
                    HStack {
                        Text("\(markdown.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(markdown.components(separatedBy: "\n").count) lines")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Copy to Clipboard") {
                        copyToClipboard()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save to File") {
                        saveToFile()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Export Markdown")
            .navigationSubtitle(chatTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }
    
    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Markdown Export"
        savePanel.nameFieldStringValue = "\(sanitizeFilename(chatTitle)).md"
        savePanel.allowedContentTypes = [UTType.plainText]
        savePanel.canCreateDirectories = true
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    // Could show an error alert here
                    print("Failed to save file: \(error)")
                }
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

#Preview {
    MarkdownExportSheet(
        markdown: """
        ### @alice [2025-06-28 14:32]
        
        Hey everyone, what do you think about the new project?
        
        [Reactions: @bob 👍, @charlie ❤️]
        
        ---
        
        ### @bob [2025-06-28 14:35]
        
        > @alice [2025-06-28 14:32]:  
        > Hey everyone, what do you think about the new project?
        
        I think it looks great! When do we start?
        
        ---
        """,
        chatTitle: "Team Chat"
    )
}