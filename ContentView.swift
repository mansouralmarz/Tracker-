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
                                notesManager.addNote(title: "New Note", content: "")
                            } else {
                                notesManager.addClipboardNote(title: "New Clipboard Note", content: "")
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
                    if selectedSection == .clipboard {
                        notesManager.cleanupExpiredClipboardNotes()
                    }
                }
                .onChange(of: selectedSection) { _ in
                    if selectedSection == .clipboard {
                        notesManager.cleanupExpiredClipboardNotes()
                    }
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
            NoteEditorView(notesManager: notesManager)
        }
    }
}

struct NotesView: View {
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        // Show note editor for notes section
        NoteEditorView(notesManager: notesManager)
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
    
    @State private var isHovered = false
    
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
                
                Text(note.formattedDate)
                    .font(.custom("PT Sans", size: 11))
                    .foregroundColor(.gray.opacity(0.5))
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct NoteEditorView: View {
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        if let selectedNote = notesManager.selectedNote {
            SimpleTextEditor(note: selectedNote, notesManager: notesManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "note.text")
                    .font(.system(size: 72))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("Select a note to start writing")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.04, blue: 0.06))
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