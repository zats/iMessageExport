import iMessageExport
import SwiftUI

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
