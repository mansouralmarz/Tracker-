import SwiftUI

@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Indent") {
                    NotificationCenter.default.post(name: .indentCommand, object: nil)
                }
                .keyboardShortcut(.tab, modifiers: [])

                Button("Outdent") {
                    NotificationCenter.default.post(name: .outdentCommand, object: nil)
                }
                .keyboardShortcut(.tab, modifiers: [.shift])
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
    }
}

extension Notification.Name {
    static let indentCommand = Notification.Name("IndentCommandNotification")
    static let outdentCommand = Notification.Name("OutdentCommandNotification")
}
