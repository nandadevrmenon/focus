import SwiftUI

@main
struct FocusApp: App {
    @State private var api = APIClient()
    @State private var server = ServerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(api)
                .environment(server)
                .onAppear {
                    server.start()
                }
                .onDisappear {
                    server.stop()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Restart Server") {
                    server.stop()
                    server.start()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
