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
    }
}
