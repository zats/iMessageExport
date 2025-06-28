import SwiftUI
import UniformTypeIdentifiers

struct MarkdownExportSheet: View {
    let markdown: String
    let chatTitle: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with title and close button
            HStack {
                VStack(alignment: .leading) {
                    Text("Export Markdown")
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
                .help("Close")
            }
            .padding(.horizontal)
            .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.headline)
                    .padding(.horizontal)
                
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
                .padding(.horizontal)
                
                HStack {
                    Text("\(markdown.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(markdown.components(separatedBy: "\n").count) lines")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
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
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
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