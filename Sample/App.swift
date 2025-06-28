import SwiftUI
import iMessageExport

@main
struct iMessageDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified)
        .commands {
            // Add macOS-specific menu commands
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .windowArrangement) {
                Button("Refresh Data") {
                    // This would need to be implemented with a notification or similar
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}