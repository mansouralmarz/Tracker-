import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    let placeholder: String
    var onChange: ((NSAttributedString) -> Void)? = nil
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // Set up the text view
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.white
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.attributedString() != text {
            textView.textStorage?.setAttributedString(text)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let value = textView.attributedString()
            parent.text = value
            parent.onChange?(value)
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle keyboard shortcuts for formatting
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                // Handle Enter key for new lines
                return false
            case #selector(NSResponder.insertTab(_:)):
                // Handle Tab key for indentation
                return false
            default:
                return false
            }
        }
    }
}

// Extension to add formatting methods
extension NSTextView {
    func insertBulletPoint() {
        let bulletString = NSAttributedString(string: "• ", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white
        ])
        
        let currentRange = selectedRange()
        textStorage?.insert(bulletString, at: currentRange.location)
        selectedRange = NSRange(location: currentRange.location + 2, length: 0)
    }
    
    func insertNumberedList() {
        let lineRange = (string as NSString).lineRange(for: selectedRange())
        let lineNumber = 1 // Simplified - you can enhance this later
        let numberString = NSAttributedString(string: "\(lineNumber). ", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white
        ])
        
        textStorage?.insert(numberString, at: lineRange.location)
        selectedRange = NSRange(location: lineRange.location + numberString.length, length: 0)
    }
}

