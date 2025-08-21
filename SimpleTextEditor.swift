import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SimpleTextEditor: View {
    let note: Note
    @ObservedObject var notesManager: NotesManager
    
    @State private var text: String = ""
    @State private var isProgrammaticChange = false
    @State private var hoveredLink: URL?
    @State private var isLinkPreviewVisible = false
    @State private var detectedLinks: [URL] = []
    
    @FocusState private var isBodyFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Note Title
            HStack {
                ZStack(alignment: .leading) {
                    if note.title.isEmpty {
                        Text("Title")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                    TextField("", text: Binding(
                        get: { note.title },
                        set: { newValue in
                            notesManager.updateNoteTitle(note, title: newValue)
                        }
                    ))
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            notesManager.deleteNote(note)
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    }
                    .onSubmit {
                        isBodyFocused = true
                    }
                }
                
                Spacer()
                
                // Link Preview Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isLinkPreviewVisible.toggle()
                    }
                }) {
                    Image(systemName: "link")
                        .foregroundColor(isLinkPreviewVisible ? .blue : .gray)
                        .font(.system(size: 18, weight: .medium))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isLinkPreviewVisible ? Color.blue.opacity(0.2) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            // Main Text Editor (SwiftUI)
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 30)
                    .id(note.id)
                    .focused($isBodyFocused)
                    .textSelection(.enabled)
                    .onChange(of: text) { newValue in
                        if !isProgrammaticChange {
                            handleTextChange(newValue)
                        }
                    }
                    // Capture Command+V to ensure image/file paste becomes attachment
                    .onReceive(NotificationCenter.default.publisher(for: .pasteAttachment)) { _ in
                        handlePasteFromClipboard()
                    }
                    .onAppear {
                        isProgrammaticChange = true
                        text = note.content
                        detectLinks()
                        DispatchQueue.main.async { isProgrammaticChange = false }
                    }
                    .onDisappear {
                        notesManager.updateNoteContent(note, content: text)
                    }
                    .onDrop(of: [UTType.fileURL.identifier, UTType.tiff.identifier, UTType.png.identifier, UTType.jpeg.identifier, "public.heic", "com.adobe.pdf"], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                    }
                Spacer()
            }
            
            // Link Preview Section
            if isLinkPreviewVisible && !detectedLinks.isEmpty {
                VStack(spacing: 16) {
                    // Section Header
                    HStack {
                        Text("Detected Links")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Hide") {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isLinkPreviewVisible = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.gray)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .cornerRadius(8)
                    }
                    
                    // Links Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                        ForEach(detectedLinks, id: \.self) { url in
                            LinkPreviewCard(url: url)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .background(Color.black)
        .onAppear { detectLinks() }
        .onChange(of: note.id) { _ in
            // When switching notes, reset editor state without writing back
            isProgrammaticChange = true
            text = note.content
            detectLinks()
            DispatchQueue.main.async { isProgrammaticChange = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            notesManager.updateNoteContent(note, content: text)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pasteAttachment)) { _ in
            handlePasteFromClipboard()
        }
    }
    
    private func handleTextChange(_ newValue: String) {
        notesManager.updateNoteContent(note, content: newValue)
        detectLinks()
    }
    
    private func addNewLine() {
        isProgrammaticChange = true
        text += "\n"
        isProgrammaticChange = false
        notesManager.updateNoteContent(note, content: text)
    }
    
    private func detectLinks() {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        var links: [URL] = []
        detector?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, let url = match.url {
                links.append(url)
            }
        }
        
        detectedLinks = links
    }

    // MARK: - Drops / Paste
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        let group = DispatchGroup()
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    defer { group.leave() }
                    if let urlData = item as? Data, let str = String(data: urlData, encoding: .utf8), let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        self.importFile(url: url)
                        handled = true
                    } else if let url = item as? URL {
                        self.importFile(url: url)
                        handled = true
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                group.enter()
                provider.loadObject(ofClass: NSImage.self) { object, _ in
                    defer { group.leave() }
                    if let image = object as? NSImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                        _ = self.notesManager.addAttachment(to: self.note.id, data: png, fileExtension: "png", originalFilename: "pasted-image.png")
                        handled = true
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.text") {
                // Treat text drops that are file paths as attachments and suppress default insertion
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.text", options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let url = URL(string: trimmed), url.isFileURL {
                            self.importFile(url: url)
                            handled = true
                        } else if FileManager.default.fileExists(atPath: trimmed) {
                            let url = URL(fileURLWithPath: trimmed)
                            self.importFile(url: url)
                            handled = true
                        } else {
                            // suppress plain text insertion for drops
                            handled = true
                        }
                    }
                }
            }
        }
        group.wait()
        return handled
    }
    
    private func importFile(url: URL) {
        let ext = url.pathExtension
        if let data = try? Data(contentsOf: url) {
            _ = notesManager.addAttachment(to: note.id, data: data, fileExtension: ext.isEmpty ? "dat" : ext, originalFilename: url.lastPathComponent)
        }
    }

    private func handlePasteFromClipboard() {
        let pb = NSPasteboard.general
        // Prefer NSImage objects
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let image = images.first,
           let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            _ = notesManager.addAttachment(to: note.id, data: png, fileExtension: "png", originalFilename: "pasted-image.png")
            return
        }
        if let data = pb.data(forType: .tiff), let image = NSImage(data: data),
           let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            _ = notesManager.addAttachment(to: note.id, data: png, fileExtension: "png", originalFilename: "pasted-image.png")
            return
        }
        if let data = pb.data(forType: .png) {
            _ = notesManager.addAttachment(to: note.id, data: data, fileExtension: "png", originalFilename: "pasted-image.png")
            return
        }
        if let fileURLData = pb.data(forType: .fileURL),
           let urlString = String(data: fileURLData, encoding: .utf8),
           let url = URL(string: urlString) {
            importFile(url: url)
            return
        }
        // Sometimes pasteboard only has a plain string path
        if let str = pb.string(forType: .string) ?? pb.string(forType: NSPasteboard.PasteboardType("public.utf8-plain-text")) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.isFileURL {
                importFile(url: url)
                return
            }
            if FileManager.default.fileExists(atPath: trimmed) {
                importFile(url: URL(fileURLWithPath: trimmed))
                return
            }
        }
    }
}

// Removed NS-based rich text host to revert to plain TextEditor

private struct AttachmentRow: View {
    let att: Attachment
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if att.type == "image", let url = fileURL() {
                Image(nsImage: NSImage(contentsOf: url) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else if att.type == "pdf" {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                    .frame(width: 80, height: 80)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .frame(width: 80, height: 80)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(att.originalFilename ?? att.filename)
                    .foregroundColor(.white)
                    .font(.system(size: 13, weight: .medium))
                Text(att.type.uppercased())
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
            }
            Spacer()
            Button(action: { if let url = fileURL() { NSWorkspace.shared.open(url) } }) {
                Image(systemName: "arrow.up.right.square")
            }.buttonStyle(.plain).foregroundColor(.blue)
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }
    
    private func fileURL() -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MansoursNotes/Attachments/\(att.filename)")
    }
}

struct LinkPreviewCard: View {
    let url: URL
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(url)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .medium))
                    Text(url.host ?? "Unknown")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                }
                
                Text(url.absoluteString)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

enum TextFormat {
    case bold
    case italic
    case underline
}

