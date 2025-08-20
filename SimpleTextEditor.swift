import SwiftUI
import AppKit

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
            
            // Main Rich Text Editor with inline paste
            VStack(spacing: 0) {
                RichTextHost(note: note, initialText: note.content, notesManager: notesManager)
                    .padding(.horizontal, 30)
                    .id(note.id)
                    .onChange(of: note.id) { _ in }
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
}

// MARK: - RichTextHost: NSTextView with inline paste of images/PDFs
private struct RichTextHost: NSViewRepresentable {
    let note: Note
    let initialText: String
    @ObservedObject var notesManager: NotesManager
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = PastingTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 16)
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.backgroundColor = .clear
        textView.string = initialText
        textView.pasteDelegate = context.coordinator
        
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Ensure the text view is the first responder so Cmd+V targets it
        if let tv = nsView.documentView as? NSTextView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(tv)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, NSTextViewDelegate, PastingTextViewDelegate {
        let parent: RichTextHost
        init(_ parent: RichTextHost) { self.parent = parent }
        
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.notesManager.updateNoteContent(parent.note, content: tv.string)
        }
        
        // Handle image/PDF paste inline and save attachment
        func handlePastedImage(_ image: NSImage, in textView: NSTextView) {
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return }
            _ = parent.notesManager.addAttachment(to: parent.note.id, data: png, fileExtension: "png", originalFilename: "pasted-image.png")
            let att = NSTextAttachment()
            att.image = image
            let attr = NSAttributedString(attachment: att)
            textView.textStorage?.insert(attr, at: textView.selectedRange().location)
        }
        
        func handlePastedPDF(_ data: Data, in textView: NSTextView) {
            _ = parent.notesManager.addAttachment(to: parent.note.id, data: data, fileExtension: "pdf", originalFilename: "pasted.pdf")
            let placeholder = NSAttributedString(string: "[PDF attached]", attributes: [.foregroundColor: NSColor.systemBlue])
            textView.textStorage?.insert(placeholder, at: textView.selectedRange().location)
        }
    }
}

// Custom NSTextView that intercepts paste
private protocol PastingTextViewDelegate: AnyObject {
    func handlePastedImage(_ image: NSImage, in textView: NSTextView)
    func handlePastedPDF(_ data: Data, in textView: NSTextView)
}

private final class PastingTextView: NSTextView {
    weak var pasteDelegate: PastingTextViewDelegate?
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [ .urlReadingFileURLsOnly: true ]) as? [URL], let url = urls.first {
            let ext = url.pathExtension.lowercased()
            if ["png","jpg","jpeg","gif","heic","tiff","bmp"].contains(ext), let image = NSImage(contentsOf: url) {
                pasteDelegate?.handlePastedImage(image, in: self)
                return true
            }
            if ext == "pdf", let pdfData = try? Data(contentsOf: url) {
                pasteDelegate?.handlePastedPDF(pdfData, in: self)
                return true
            }
        }
        return super.performDragOperation(sender)
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let types = pb.types {
            // Prefer robust object-based reading first (works for Finder file copies)
            if let urls = pb.readObjects(forClasses: [NSURL.self], options: [ .urlReadingFileURLsOnly: true ]) as? [URL], let url = urls.first {
                let ext = url.pathExtension.lowercased()
                if ["png","jpg","jpeg","gif","heic","tiff","bmp"].contains(ext), let image = NSImage(contentsOf: url) {
                    pasteDelegate?.handlePastedImage(image, in: self)
                    return
                }
                if ext == "pdf", let pdfData = try? Data(contentsOf: url) {
                    pasteDelegate?.handlePastedPDF(pdfData, in: self)
                    return
                }
            }
            if types.contains(.tiff), let data = pb.data(forType: .tiff), let image = NSImage(data: data) {
                pasteDelegate?.handlePastedImage(image, in: self)
                return
            }
            if types.contains(.png), let data = pb.data(forType: .png), let image = NSImage(data: data) {
                pasteDelegate?.handlePastedImage(image, in: self)
                return
            }
            if types.contains(.string), let path = pb.string(forType: .string), path.lowercased().hasSuffix(".png"), FileManager.default.fileExists(atPath: path), let image = NSImage(contentsOfFile: path) {
                pasteDelegate?.handlePastedImage(image, in: self)
                return
            }
            if types.contains(.fileURL), let data = pb.data(forType: .fileURL), let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) {
                let ext = url.pathExtension.lowercased()
                if ["png","jpg","jpeg","gif","heic","tiff","bmp"].contains(ext), let image = NSImage(contentsOf: url) {
                    pasteDelegate?.handlePastedImage(image, in: self)
                    return
                }
                if ext == "pdf", let pdfData = try? Data(contentsOf: url) {
                    pasteDelegate?.handlePastedPDF(pdfData, in: self)
                    return
                }
            }
            if let pdfData = pb.data(forType: .pdf) {
                pasteDelegate?.handlePastedPDF(pdfData, in: self)
                return
            }
        }
        super.paste(sender)
    }
}

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
