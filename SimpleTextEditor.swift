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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Note Title
            HStack {
                TextField("Note Title", text: Binding(
                    get: { note.title },
                    set: { newValue in
                        notesManager.updateNoteTitle(note, title: newValue)
                    }
                ))
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                
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
            
            // Main Text Editor
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 30)
                    .onChange(of: text) { newValue in
                        if !isProgrammaticChange {
                            handleTextChange(newValue)
                        }
                    }
                    .onAppear {
                        text = note.content
                    }
                    .onSubmit {
                        // Handle Enter key for new lines
                        addNewLine()
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
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
        .onAppear {
            detectLinks()
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
}

struct LinkPreviewCard: View {
    let url: URL
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(url)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(url.host ?? "Unknown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                Text(url.absoluteString)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
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
