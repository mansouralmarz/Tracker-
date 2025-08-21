import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
            CommandGroup(replacing: .pasteboard) {
                Button("Paste") {
                    // If pasteboard has an image or file, route to attachment handler; else forward to default paste
                    let pb = NSPasteboard.general
                    let types = pb.types ?? []
                    let hasImage = pb.canReadObject(forClasses: [NSImage.self], options: nil) || types.contains(.tiff) || types.contains(NSPasteboard.PasteboardType("public.png")) || types.contains(NSPasteboard.PasteboardType("public.jpeg"))
                    let hasFile = types.contains(.fileURL) || types.contains(NSPasteboard.PasteboardType("public.file-url"))
                    if hasImage || hasFile {
                        NotificationCenter.default.post(name: .pasteAttachment, object: nil)
                    } else {
                        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                    }
                }
                .keyboardShortcut("v", modifiers: [.command])
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .defaultSize(width: 1000, height: 700)
    }
}

extension Notification.Name {
    static let indentCommand = Notification.Name("IndentCommandNotification")
    static let outdentCommand = Notification.Name("OutdentCommandNotification")
    static let pasteAttachment = Notification.Name("PasteAttachmentNotification")
}
