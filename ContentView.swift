import SwiftUI

struct ContentView: View {
    @StateObject private var notesManager = NotesManager()
    @StateObject private var taskManager = TaskManager()
    @State private var selectedSection: NavigationItem = .notes
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView(selectedSection: $selectedSection, taskManager: taskManager, notesManager: notesManager)
                .frame(width: 280)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.02),
                            Color(red: 0.01, green: 0.01, blue: 0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Main Content
            MainContentView(
                selectedSection: selectedSection,
                notesManager: notesManager,
                taskManager: taskManager
            )
        }
        .background(Color.black)
        .onAppear {
            notesManager.loadNotes()
        }
    }
}



struct SidebarView: View {
    @Binding var selectedSection: NavigationItem
    let taskManager: TaskManager
    @ObservedObject var notesManager: NotesManager
    
    private func syncSelectionToSection() {
        // Ensure selectedNoteId always points to a note in the current section
        if let id = notesManager.selectedNoteId,
           let note = notesManager.notes.first(where: { $0.id == id }) {
            if selectedSection == .notes && note.isClipboardNote {
                notesManager.selectedNoteId = notesManager.getRegularNotes().first?.id
            } else if selectedSection == .clipboard && !note.isClipboardNote {
                notesManager.selectedNoteId = notesManager.getClipboardNotes().first?.id
            }
        } else {
            // Nothing selected; choose first in section if exists
            notesManager.selectedNoteId = (selectedSection == .notes ? notesManager.getRegularNotes().first?.id : notesManager.getClipboardNotes().first?.id)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Dynamic Greeting
            VStack(spacing: 12) {
                Text(greetingMessage())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                Text("Mansour")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Navigation Items
            VStack(spacing: 6) {
                ForEach(NavigationItem.allCases, id: \.self) { item in
                    NavigationItemView(
                        item: item,
                        isSelected: selectedSection == item,
                        taskManager: taskManager,
                        action: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedSection = item
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            // Show notes list when Notes or Clipboard is selected
            if selectedSection == .notes || selectedSection == .clipboard {
                VStack(spacing: 0) {
                    // Notes List Header
                HStack {
                        Text(selectedSection == .notes ? "Your Notes" : "Clipboard Notes")
                            .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                            if selectedSection == .notes {
                                let newId = notesManager.addNote(title: "New Note", content: "")
                                notesManager.selectedNoteId = newId
                            } else {
                                let newId = notesManager.addClipboardNote(title: "New Clipboard Note", content: "")
                                notesManager.selectedNoteId = newId
                            }
                    }) {
                        Image(systemName: "plus")
                                .foregroundColor(.blue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                // Notes List
                ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(selectedSection == .notes ? notesManager.getRegularNotes() : notesManager.getClipboardNotes()) { note in
                                SidebarNoteRowView(
                                note: note,
                                    isSelected: notesManager.selectedNoteId == note.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            notesManager.selectedNoteId = note.id
                                        }
                                    },
                                    onDelete: {
                                        notesManager.deleteNote(note)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .onAppear {
                    notesManager.loadNotes()
                    syncSelectionToSection()
                    if selectedSection == .clipboard { notesManager.cleanupExpiredClipboardNotes() }
                }
                .onChange(of: selectedSection) { _ in
                    if selectedSection == .clipboard { notesManager.cleanupExpiredClipboardNotes() }
                    syncSelectionToSection()
                }
            } else {
                Spacer()
            }
            
            // Time picker removed from sidebar; now embedded inside the calendar popover
        }
    }

    private func greetingMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
}

struct NavigationItemView: View {
    let item: NavigationItem
    let isSelected: Bool
    let taskManager: TaskManager
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: item.iconName)
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.7))
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 22)
                
                Text(item.title)
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.8))
                    .font(.system(size: 15, weight: .medium))
                
                Spacer()
                
                if item == .toDoList {
                    // Show completion percentage for today
                    let todayList = taskManager.getCurrentDayTaskList()
                    if let todayList = todayList, todayList.totalTasksCount > 0 {
                        Text("\(Int(todayList.overallCompletionPercentage))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? 
                          LinearGradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHovered && !isSelected ? Color.gray.opacity(0.4) : Color.clear, lineWidth: 1)
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

struct TimePickerView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var selectedPeriod = 0
    
    private let hours = Array(1...12)
    private let minutes = Array(0...59)
    private let periods = ["AM", "PM"]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Default Due Time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 10) {
                // Hour Picker
                Picker("Hour", selection: $selectedHour) {
                    ForEach(hours, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 55)
                .onChange(of: selectedHour) { newValue in
                    updateDefaultTime()
                }
                
                Text(":")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .medium))
                
                // Minute Picker
                Picker("Minute", selection: $selectedMinute) {
                    ForEach(minutes, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 55)
                .onChange(of: selectedMinute) { newValue in
                    updateDefaultTime()
                }
                
                // AM/PM Picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(periods.indices, id: \.self) { index in
                        Text(periods[index]).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 55)
                .onChange(of: selectedPeriod) { newValue in
                    updateDefaultTime()
                }
            }
            .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            loadDefaultTime()
        }
    }
    
    private func updateDefaultTime() {
        var hour = selectedHour
        if selectedPeriod == 1 && hour != 12 { // PM
            hour += 12
        } else if selectedPeriod == 0 && hour == 12 { // AM
            hour = 0
        }
        
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = selectedMinute
        
        if let defaultTime = calendar.date(from: components) {
            taskManager.setDefaultDueTime(defaultTime)
        }
    }
    
    private func loadDefaultTime() {
        let defaultTime = taskManager.getDefaultDueTime()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: defaultTime)
        let minute = calendar.component(.minute, from: defaultTime)
        
        if hour == 0 {
            selectedHour = 12
            selectedPeriod = 0
        } else if hour == 12 {
            selectedHour = 12
            selectedPeriod = 1
        } else if hour > 12 {
            selectedHour = hour - 12
            selectedPeriod = 1
        } else {
            selectedHour = hour
            selectedPeriod = 0
        }
        
        selectedMinute = minute
    }
}

struct MainContentView: View {
    let selectedSection: NavigationItem
    let notesManager: NotesManager
    let taskManager: TaskManager
    
    var body: some View {
        switch selectedSection {
        case .notes:
            NotesView(notesManager: notesManager)
        case .toDoList:
            ToDoView(taskManager: taskManager)
        case .clipboard:
            // Show note editor for clipboard section
            NoteEditorView(notesManager: notesManager, section: .clipboard)
        }
    }
}

struct NotesView: View {
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        // Show note editor for notes section
        NoteEditorView(notesManager: notesManager, section: .notes)
    }
}

struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                Text(note.displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    
                    Spacer()
                    
                    Text(note.formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? 
                          LinearGradient(colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.15), Color(red: 0.12, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isHovered && !isSelected ? Color.gray.opacity(0.4) : Color.clear, lineWidth: 1)
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

struct SidebarNoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var now = Date()
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var timeRemainingText: String {
        guard note.isClipboardNote else { return "" }
        let expiry = note.lastEditTime.addingTimeInterval(24 * 60 * 60)
        let remaining = max(0, Int(expiry.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var expiryProgress: CGFloat {
        guard note.isClipboardNote else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(note.lastEditTime))
        let progress = min(1.0, elapsed / (24 * 60 * 60))
        return CGFloat(progress)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle)
                    .font(.custom("PT Sans", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.custom("PT Sans", size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Text(note.formattedDate)
                        .font(.custom("PT Sans", size: 11))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    if note.isClipboardNote {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(timeRemainingText)
                                .font(.custom("PT Sans", size: 11).weight(.semibold))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                if note.isClipboardNote {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange)
                                .frame(width: max(0, expiryProgress) * geo.size.width, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? 
                          LinearGradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [isHovered ? Color.gray.opacity(0.1) : Color.clear, isHovered ? Color.gray.opacity(0.1) : Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Note", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onReceive(countdownTimer) { newNow in
            now = newNow
        }
    }
}

struct NoteEditorView: View {
    @ObservedObject var notesManager: NotesManager
    var section: NavigationItem
    
    var body: some View {
        if let selectedNote = notesManager.selectedNote, matchesSection(selectedNote) {
            SimpleTextEditor(note: selectedNote, notesManager: notesManager)
                .id(selectedNote.id) // Force a fresh editor for each note so bodies don't carry over
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "note.text")
                    .font(.system(size: 72))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("No note selected in this section")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        }
    }
    
    private func matchesSection(_ note: Note) -> Bool {
        switch section {
        case .notes: return !note.isClipboardNote
        case .clipboard: return note.isClipboardNote
        case .toDoList: return false
        }
    }
}

enum NavigationItem: CaseIterable {
    case notes
    case toDoList
    case clipboard
    
    var title: String {
        switch self {
        case .notes: return "Notes"
        case .toDoList: return "To-Do List"
        case .clipboard: return "Clipboard"
        }
    }
    
    var iconName: String {
        switch self {
        case .notes: return "note.text"
        case .toDoList: return "checklist"
        case .clipboard: return "clipboard"
        }
    }
}