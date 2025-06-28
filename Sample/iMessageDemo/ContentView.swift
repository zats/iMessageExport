import SwiftUI
import iMessageExport

struct ContentView: View {
    @State private var selectedChat: Chat?
    @State private var isLoading = true
    @State private var error: (any Error)?
    @State private var exporter: iMessageExport?
    
    var body: some View {
        NavigationSplitView {
            ConversationListView(
                selectedChat: $selectedChat,
                isLoading: $isLoading,
                error: $error,
                exporter: $exporter
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 500)
        } detail: {
            if let selectedChat = selectedChat, let exporter = exporter {
                ChatDetailView(chat: selectedChat, exporter: exporter)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a conversation to view messages")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        ProgressView("Loading conversations...")
                            .padding(.top)
                    }
                    
                    if error != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.shield")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            Text("Access Denied")
                                .font(.headline)
                            
                            Text("This app needs Full Disk Access to read your iMessage database.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("To grant access:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1. Open System Settings")
                                    Text("2. Go to Privacy & Security")
                                    Text("3. Select Full Disk Access")
                                    Text("4. Add this app and enable it")
                                    Text("5. Restart this app")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button("Open System Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await initializeExporter()
        }
        .onDisappear {
            Task {
                await exporter?.close()
            }
        }
    }
    
    private func initializeExporter() async {
        do {
            isLoading = true
            error = nil
            exporter = try await iMessageExport()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
