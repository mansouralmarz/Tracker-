// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteSphere",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NoteSphere",
            targets: ["NoteSphere"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NoteSphere",
            path: ".",
            sources: ["NotesApp.swift", "ContentView.swift", "Models.swift", "RichTextEditor.swift"]
        )
    ]
)
