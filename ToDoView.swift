import SwiftUI
import AppKit

struct ToDoView: View {
    @ObservedObject var taskManager: TaskManager
    @State private var newTaskTitle = ""
    @State private var newSubtaskTitles: [UUID: String] = [:]
    @State private var newSubSubtaskTitles: [UUID: String] = [:]
    @State private var isEditing: [UUID: Bool] = [:]
    @FocusState private var isNewTaskFieldFocused: Bool
    @FocusState private var focusedEditingId: UUID?
    @State private var hasProcessedTab: [UUID: Bool] = [:]
    @State private var isMergedView = false
    @State private var subtaskInputFields: Set<UUID> = []
    @State private var subtaskInputTitles: [UUID: String] = [:]
    @State private var subSubtaskInputFields: Set<UUID> = []
    @State private var subSubtaskInputTitles: [UUID: String] = [:]
    @State private var selectedMonth = Date()
    @State private var isExpanded = false
    @State private var showingDueDatePicker = false
    @State private var selectedDateForDueDate = Date()
    @State private var showingSuggestions = false
    @State private var selectedTime = Date()
    @State private var keyMonitor: Any?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 16) {
                HStack {
                    Text("To-Do List")
                        .font(.custom("PT Sans", size: 28).weight(.bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Calendar Widget
                    CompactCalendarWidget(taskManager: taskManager)
                }
                
                // Date Navigation
                HStack(spacing: 8) {
                    // Segmented Control: Yesterday / Today / Tomorrow
                    Button("Yesterday") {
                        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: taskManager.selectedDate) ?? taskManager.selectedDate
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            taskManager.updateSelectedDate(yesterday)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                    .cornerRadius(8)
                    .font(.custom("PT Sans", size: 13).weight(.semibold))
                    .foregroundColor(.white)
                    
                    Button("Today") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            taskManager.updateSelectedDate(Date())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .font(.custom("PT Sans", size: 13).weight(.semibold))
                    .foregroundColor(.white)
                    
                    Button("Tomorrow") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: taskManager.selectedDate) ?? taskManager.selectedDate
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            taskManager.updateSelectedDate(tomorrow)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                    .cornerRadius(8)
                    .font(.custom("PT Sans", size: 13).weight(.semibold))
                    .foregroundColor(.white)
                }
                
                // Current Date Display
                if let currentList = taskManager.getCurrentDayTaskList() {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(currentList.shortFormattedDate)
                                .font(.custom("PT Sans", size: 18).weight(.medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(currentList.overallCompletionPercentage))%")
                                .font(.custom("PT Sans", size: 14).weight(.semibold))
                                .foregroundColor(.blue)
                        }
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                                    .frame(width: geo.size.width, height: 8)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                                    .frame(width: max(0, CGFloat(currentList.overallCompletionPercentage/100.0)) * geo.size.width, height: 8)
                                    .animation(.easeInOut(duration: 0.25), value: currentList.overallCompletionPercentage)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            // List + Input with autoscroll
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Tasks List Section
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if let currentList = taskManager.getCurrentDayTaskList() {
                                ForEach(Array(currentList.tasks.enumerated()), id: \.element.id) { taskIndex, task in
                                    TaskRowView(
                                        task: task,
                                        taskIndex: taskIndex,
                                        taskManager: taskManager,
                                        isEditing: $isEditing,
                                        hasProcessedTab: $hasProcessedTab,
                                        isMergedView: $isMergedView,
                                        subtaskInputFields: $subtaskInputFields,
                                        subtaskInputTitles: $subtaskInputTitles,
                                        subSubtaskInputFields: $subSubtaskInputFields,
                                        subSubtaskInputTitles: $subSubtaskInputTitles,
                                        focusedEditing: $focusedEditingId,
                                        setFocusedId: { id in
                                            // Defer focus a tick so SwiftUI attaches the new field first
                                            DispatchQueue.main.async {
                                                focusedEditingId = id
                                            }
                                        }
                                    )
                                    .id(task.id)
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 12)
                    }
                    .frame(maxHeight: .infinity)
                    // Auto-scroll to the most recently focused/edited row
                    .onChange(of: focusedEditingId) { newId in
                        guard let targetId = newId else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                    
                    // New Task Input Section (pinned below)
                    VStack(spacing: 12) {
                        HStack {
                            TextField("New task...", text: $newTaskTitle)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.custom("PT Sans", size: 16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .focused($isNewTaskFieldFocused)
                                .onSubmit {
                                    let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !title.isEmpty else { return }
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        if let newId = taskManager.addTask(title: title) {
                                            isEditing[newId] = true
                                            focusedEditingId = newId
                                            proxy.scrollTo(newId, anchor: .bottom)
                                        }
                                        newTaskTitle = ""
                                    }
                                }
                                .submitLabel(.return)
                        }
                        // Invisible default button to ensure Return triggers add on macOS
                        Button(action: {
                            guard isNewTaskFieldFocused else { return }
                            let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if let newId = taskManager.addTask(title: title) {
                                    isEditing[newId] = true
                                    focusedEditingId = newId
                                    proxy.scrollTo(newId, anchor: .bottom)
                                }
                                newTaskTitle = ""
                            }
                        }) {
                            EmptyView()
                        }
                        .keyboardShortcut(.return)
                        .frame(width: 0, height: 0)
                        .opacity(0.001)
                        .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.black)
        .onReceive(NotificationCenter.default.publisher(for: .indentCommand)) { _ in
            handleIndent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .outdentCommand)) { _ in
            handleOutdent()
        }
        .onTapGesture {
            // Toggle merged view when clicking background
            isMergedView.toggle()
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                // 48 is Tab
                if event.keyCode == 48 {
                    if event.modifierFlags.contains(.shift) {
                        handleOutdent()
                    } else {
                        handleIndent()
                    }
                    // consume event to avoid focus traversal
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }
    private func handleIndent() {
        // Determine current caret line by edit state or by last empty input row
        if let activeId = isEditing.first(where: { $0.value })?.key {
            // Try as Task first
            if let newId = taskManager.indentTaskToSubtask(activeId) {
                // Task → Subtask
                isEditing[activeId] = false
                isEditing[newId] = true
                DispatchQueue.main.async {
                    focusedEditingId = newId
                }
                return
            }
            // Try as Subtask
            if let newId = taskManager.indentSubtaskToSubSubtask(activeId) {
                // Subtask → SubSubtask
                isEditing[activeId] = false
                isEditing[newId] = true
                DispatchQueue.main.async {
                    focusedEditingId = newId
                }
                return
            }
        }
        // If nothing marked editing, allow Tab on an empty cell to indent relative to nearest valid parent above
        if let currentList = taskManager.getCurrentDayTaskList() {
            // Empty task -> make subtask under nearest task above (enforced in manager)
            if let idx = currentList.tasks.lastIndex(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), idx > 0 {
                let taskId = currentList.tasks[idx].id
                if let newId = taskManager.indentTaskToSubtask(taskId) {
                    isEditing[newId] = true
                    DispatchQueue.main.async {
                        focusedEditingId = newId
                    }
                    return
                }
            }
            // Empty subtask -> make sub-subtask under nearest subtask above
            for task in currentList.tasks {
                if let subIdx = task.subtasks.lastIndex(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), subIdx > 0 {
                    let subtaskId = task.subtasks[subIdx].id
                    if let newId = taskManager.indentSubtaskToSubSubtask(subtaskId) {
                        isEditing[newId] = true
                        DispatchQueue.main.async {
                            focusedEditingId = newId
                        }
                        return
                    }
                }
            }
        }
    }

    private func handleOutdent() {
        // Always unindent one level from the current caret line
        if let activeId = isEditing.first(where: { $0.value })?.key {
            // Try sub-subtask → subtask
            if let newId = taskManager.outdentSubSubtaskToSubtask(activeId) {
                isEditing[activeId] = false
                isEditing[newId] = true
                DispatchQueue.main.async {
                    focusedEditingId = newId
                }
                return
            }
            // Try subtask → task
            if let newId = taskManager.outdentSubtaskToTask(activeId) {
                isEditing[activeId] = false
                isEditing[newId] = true
                DispatchQueue.main.async {
                    focusedEditingId = newId
                }
                return
            }
            // Task → Task (no-op)
            return
        }
        // If nothing active, attempt to outdent last empty lower-level line
        if let currentList = taskManager.getCurrentDayTaskList() {
            for task in currentList.tasks {
                for subtask in task.subtasks {
                    if let idx = subtask.subSubtasks.lastIndex(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        let id = subtask.subSubtasks[idx].id
                        if let newId = taskManager.outdentSubSubtaskToSubtask(id) {
                            isEditing[newId] = true
                            DispatchQueue.main.async {
                                focusedEditingId = newId
                            }
                            return
                        }
                    }
                }
                if let subIdx = task.subtasks.lastIndex(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    let id = task.subtasks[subIdx].id
                    if let newId = taskManager.outdentSubtaskToTask(id) {
                        isEditing[newId] = true
                        DispatchQueue.main.async {
                            focusedEditingId = newId
                        }
                        return
                    }
                }
            }
        }
    }
}

struct TaskRowView: View {
    let task: Task
    let taskIndex: Int
    @ObservedObject var taskManager: TaskManager
    @Binding var isEditing: [UUID: Bool]
    @Binding var hasProcessedTab: [UUID: Bool]
    @Binding var isMergedView: Bool
    @Binding var subtaskInputFields: Set<UUID>
    @Binding var subtaskInputTitles: [UUID: String]
    @Binding var subSubtaskInputFields: Set<UUID>
    @Binding var subSubtaskInputTitles: [UUID: String]
    let focusedEditing: FocusState<UUID?>.Binding
    let setFocusedId: (UUID?) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Task Row
            HStack(spacing: 16) {
                // Checkbox
                Button(action: {
                    taskManager.toggleTask(task.id)
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? Color.green : Color.white)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                
                // Task Content
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing[task.id] == true {
                        TextField("Task title", text: Binding(
                            get: { task.title },
                            set: { newValue in
                                taskManager.updateTaskTitle(task.id, title: newValue)
                            }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.custom("PT Sans", size: 16).weight(.medium))
                        .foregroundColor(.white)
                        .focused(focusedEditing, equals: task.id)

                        .onSubmit {
                            if let newId = taskManager.insertTask(after: task.id, title: "") {
                                isEditing[task.id] = false
                                isEditing[newId] = true
                                setFocusedId(newId)
                            }
                        }
                        .onExitCommand {
                            // Shift+Tab unindent
                            if let newId = taskManager.outdentSubtaskToTask(task.id) {
                                isEditing[task.id] = false
                                isEditing[newId] = true
                                setFocusedId(newId)
                            }
                        }
                        
                    } else {
                        Text(task.title)
                            .font(.custom("PT Sans", size: 16).weight(.medium))
                            .foregroundColor(.white)
                            .strikethrough(task.isCompleted)
                            .onTapGesture(count: 2) {
                                isEditing[task.id] = true
                            }
                    }
                    
                    // Due Date Display
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            
                            Text(dueDate, style: .time)
                                .font(.custom("PT Sans", size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    // Edit Button
                    Button(action: {
                        if isEditing[task.id] == true {
                            isEditing[task.id] = false
                        } else {
                            isEditing[task.id] = true
                        }
                    }) {
                        Image(systemName: isEditing[task.id] == true ? "checkmark" : "pencil")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    
                    // Add Subtask Button
                    Button(action: {
                        subtaskInputFields.insert(task.id)
                        subtaskInputTitles[task.id] = ""
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    // Delete Button
                    Button(action: {
                        taskManager.deleteTask(task.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // Subtasks Section
            if !task.subtasks.isEmpty || subtaskInputFields.contains(task.id) {
                VStack(spacing: 8) {
                    ForEach(task.subtasks.indices, id: \.self) { subtaskIndex in
                        let subtask = task.subtasks[subtaskIndex]
                        SubtaskRowView(
                            subtask: subtask,
                            subtaskIndex: subtaskIndex,
                            taskId: task.id,
                            taskManager: taskManager,
                            isEditing: $isEditing,
                            hasProcessedTab: $hasProcessedTab,
                            isMergedView: $isMergedView,
                            subSubtaskInputFields: $subSubtaskInputFields,
                            subSubtaskInputTitles: $subSubtaskInputTitles,
                            focusedEditing: focusedEditing,
                            setFocusedId: setFocusedId
                        )
                    }
                    
                    // New Subtask Input
                    if subtaskInputFields.contains(task.id) {
                        HStack(spacing: 12) {
                            Text("•")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                            
                            TextField("New subtask...", text: Binding(
                                get: { subtaskInputTitles[task.id] ?? "" },
                                set: { subtaskInputTitles[task.id] = $0 }
                            ))
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.custom("PT Sans", size: 14))
                            .foregroundColor(.white)
                            .onSubmit {
                                if let title = subtaskInputTitles[task.id], !title.isEmpty {
                                    taskManager.addSubtask(to: task.id, title: title)
                                    subtaskInputTitles[task.id] = ""
                                    subtaskInputFields.remove(task.id)
                                }
                                else {
                                    // Empty -> unindent: convert last subtask back to task
                                    if let last = task.subtasks.last {
                                        if let newTaskId = taskManager.outdentSubtaskToTask(last.id) {
                                            isEditing[newTaskId] = true
                                        }
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                        .cornerRadius(8)
                    }
                }
                .padding(.leading, 40)
                .padding(.top, 8)
            }
        }
    }
}

struct SubtaskRowView: View {
    let subtask: Subtask
    let subtaskIndex: Int
    let taskId: UUID
    @ObservedObject var taskManager: TaskManager
    @Binding var isEditing: [UUID: Bool]
    @Binding var hasProcessedTab: [UUID: Bool]
    @Binding var isMergedView: Bool
    @Binding var subSubtaskInputFields: Set<UUID>
    @Binding var subSubtaskInputTitles: [UUID: String]
    let focusedEditing: FocusState<UUID?>.Binding
    let setFocusedId: (UUID?) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Subtask Row
            HStack(spacing: 12) {
                // Checkbox
                Button(action: {
                    taskManager.toggleSubtask(subtask.id)
                }) {
                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(subtask.isCompleted ? .green : .white)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                
                // Subtask Content
                VStack(alignment: .leading, spacing: 6) {
                    if isEditing[subtask.id] == true {
                        TextField("Subtask title", text: Binding(
                            get: { subtask.title },
                            set: { newValue in
                                taskManager.updateSubtaskTitle(subtask.id, title: newValue)
                            }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.custom("PT Sans", size: 14))
                        .foregroundColor(.white)
                        .focused(focusedEditing, equals: subtask.id)

                        .onSubmit {
                            let trimmed = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                if let newTaskId = taskManager.outdentSubtaskToTask(subtask.id) {
                                    isEditing[subtask.id] = false
                                    isEditing[newTaskId] = true
                                    setFocusedId(newTaskId)
                                }
                            } else {
                                if let newId = taskManager.insertSubtask(after: subtask.id, title: "") {
                                    isEditing[subtask.id] = false
                                    isEditing[newId] = true
                                    setFocusedId(newId)
                                }
                            }
                        }
                        .onExitCommand {
                            if let newId = taskManager.outdentSubtaskToTask(subtask.id) {
                                isEditing[subtask.id] = false
                                isEditing[newId] = true
                                setFocusedId(newId)
                            }
                        }
                        
                    } else {
                        Text(subtask.title)
                            .font(.custom("PT Sans", size: 14))
                            .foregroundColor(.white)
                            .strikethrough(subtask.isCompleted)
                            .onTapGesture(count: 2) {
                                isEditing[subtask.id] = true
                            }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    // Edit Button
                    Button(action: {
                        if isEditing[subtask.id] == true {
                            isEditing[subtask.id] = false
                        } else {
                            isEditing[subtask.id] = true
                        }
                    }) {
                        Image(systemName: isEditing[subtask.id] == true ? "checkmark" : "pencil")
                            .foregroundColor(.blue)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    
                    // Delete Button
                    Button(action: {
                        taskManager.deleteSubtask(subtask.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // Sub-subtasks Section
            if !subtask.subSubtasks.isEmpty || subSubtaskInputFields.contains(subtask.id) {
                VStack(spacing: 6) {
                    ForEach(subtask.subSubtasks.indices, id: \.self) { subSubtaskIndex in
                        let subSubtask = subtask.subSubtasks[subSubtaskIndex]
                        SubSubtaskRowView(
                            subSubtask: subSubtask,
                            subSubtaskIndex: subSubtaskIndex,
                            subtaskId: subtask.id,
                            taskId: taskId,
                            taskManager: taskManager,
                            isEditing: $isEditing,
                            focusedEditing: focusedEditing,
                            setFocusedId: setFocusedId
                        )
                    }
                    
                    // New Sub-subtask Input
                    if subSubtaskInputFields.contains(subtask.id) {
                        HStack(spacing: 12) {
                            Text("◦")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                            
                            TextField("New sub-subtask...", text: Binding(
                                get: { subSubtaskInputTitles[subtask.id] ?? "" },
                                set: { subSubtaskInputTitles[subtask.id] = $0 }
                            ))
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .onSubmit {
                                if let title = subSubtaskInputTitles[subtask.id], !title.isEmpty {
                                    taskManager.addSubSubtask(to: subtask.id, title: title)
                                    subSubtaskInputTitles[subtask.id] = ""
                                    subSubtaskInputFields.remove(subtask.id)
                                }
                                else {
                                    // Empty -> unindent sub-subtask to subtask (use last if exists)
                                    if let last = subtask.subSubtasks.last {
                                        if let newSubtaskId = taskManager.outdentSubSubtaskToSubtask(last.id) {
                                            isEditing[newSubtaskId] = true
                                        }
                                    }
                                }
                            }
                            
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.06, green: 0.06, blue: 0.06))
                        .cornerRadius(6)
                    }
                }
                .padding(.leading, 30)
                .padding(.top, 6)
            }
        }
    }
}

struct SubSubtaskRowView: View {
    let subSubtask: SubSubtask
    let subSubtaskIndex: Int
    let subtaskId: UUID
    let taskId: UUID
    @ObservedObject var taskManager: TaskManager
    @Binding var isEditing: [UUID: Bool]
    let focusedEditing: FocusState<UUID?>.Binding
    let setFocusedId: (UUID?) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                taskManager.toggleSubSubtask(subSubtask.id)
            }) {
                Image(systemName: subSubtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subSubtask.isCompleted ? .green : .white)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            // Sub-subtask Content
            VStack(alignment: .leading, spacing: 4) {
                if isEditing[subSubtask.id] == true {
                    TextField("Sub-subtask title", text: Binding(
                        get: { subSubtask.title },
                        set: { newValue in
                            taskManager.updateSubSubtaskTitle(subSubtask.id, title: newValue)
                        }
                    ))
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("PT Sans", size: 12))
                    .foregroundColor(.white)
                    .focused(focusedEditing, equals: subSubtask.id)

                    .onSubmit {
                        if subSubtask.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // If empty, transition to subtask
                            if let newId = taskManager.outdentSubSubtaskToSubtask(subSubtask.id) {
                                isEditing[subSubtask.id] = false
                                isEditing[newId] = true
                                setFocusedId(newId)
                            }
                        } else {
                            // If has content, create new sibling subsubtask
                            if let newId = taskManager.insertSubSubtask(after: subSubtask.id, title: "") {
                                isEditing[subSubtask.id] = false
                                isEditing[newId] = true
                                setFocusedId(newId)
                            }
                        }
                    }
                    .onExitCommand {
                        if let newId = taskManager.outdentSubSubtaskToSubtask(subSubtask.id) {
                            isEditing[subSubtask.id] = false
                            isEditing[newId] = true
                            setFocusedId(newId)
                        }
                    }
                    
                } else {
                    Text(subSubtask.title)
                        .font(.custom("PT Sans", size: 12))
                        .foregroundColor(.white)
                        .strikethrough(subSubtask.isCompleted)
                        .onTapGesture(count: 2) {
                            isEditing[subSubtask.id] = true
                        }
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                // Edit Button
                Button(action: {
                                            if isEditing[subSubtask.id] == true {
                            isEditing[subSubtask.id] = false
                        } else {
                            isEditing[subSubtask.id] = true
                        }
                }) {
                    Image(systemName: isEditing[subSubtask.id] == true ? "checkmark" : "pencil")
                        .foregroundColor(.blue)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                
                // Delete Button
                Button(action: {
                    taskManager.deleteSubSubtask(subSubtask.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct CompactCalendarWidget: View {
    @ObservedObject var taskManager: TaskManager
    @State private var isExpanded = false
    @State private var selectedMonth = Date()
    @State private var showingDefaultTime = false
    @State private var defaultHour = 9
    @State private var defaultMinute = 0
    @State private var defaultPeriod = 0 // 0 AM, 1 PM
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 8) {
            // Calendar Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(selectedMonth, style: .date)
                    .font(.custom("PT Sans", size: 14).weight(.medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(8)
            
            // Calendar Grid
            if isExpanded {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    // Day headers
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.custom("PT Sans", size: 10).weight(.medium))
                            .foregroundColor(.gray)
                            .frame(height: 20)
                    }
                    
                    // Calendar days
                    ForEach(daysInMonth, id: \.self) { date in
                        CompactCalendarDayView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: taskManager.selectedDate),
                            hasDueTasks: !taskManager.getTasksWithDueDate(date).isEmpty,
                            onTap: {
                                taskManager.updateSelectedDate(date)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                .cornerRadius(8)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Footer controls
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)

                Button(action: { showingDefaultTime.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text("Default Due Time")
                    }
                    .font(.custom("PT Sans", size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingDefaultTime) {
                    VStack(spacing: 12) {
                        Text("Default Due Time")
                            .font(.custom("PT Sans", size: 14).weight(.semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 10) {
                            Picker("Hour", selection: $defaultHour) {
                                ForEach(1...12, id: \.self) { Text("\($0)").tag($0) }
                            }.labelsHidden().frame(width: 60)
                            Text(":").foregroundColor(.white)
                            Picker("Minute", selection: $defaultMinute) {
                                ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                            }.labelsHidden().frame(width: 60)
                            Picker("Period", selection: $defaultPeriod) {
                                Text("AM").tag(0)
                                Text("PM").tag(1)
                            }.labelsHidden().frame(width: 60)
                        }
                        .font(.custom("PT Sans", size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .cornerRadius(10)

                        Button("Save") {
                            let hour24: Int = (defaultPeriod == 1 ? (defaultHour % 12) + 12 : (defaultHour == 12 ? 0 : defaultHour))
                            var components = DateComponents()
                            components.hour = hour24
                            components.minute = defaultMinute
                            if let date = Calendar.current.date(from: components) {
                                taskManager.setDefaultDueTime(date)
                            }
                            showingDefaultTime = false
                        }
                        .font(.custom("PT Sans", size: 14).weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .frame(width: 320)
                    .background(Color.black)
                }
            }
        }
        .onAppear {
            selectedMonth = taskManager.selectedDate
            // Load initial default time from manager
            let date = taskManager.getDefaultDueTime()
            let cal = Calendar.current
            let hour = cal.component(.hour, from: date)
            defaultMinute = cal.component(.minute, from: date)
            if hour == 0 { defaultHour = 12; defaultPeriod = 0 }
            else if hour == 12 { defaultHour = 12; defaultPeriod = 1 }
            else if hour > 12 { defaultHour = hour - 12; defaultPeriod = 1 }
            else { defaultHour = hour; defaultPeriod = 0 }
        }
        .onChange(of: taskManager.selectedDate) {
            selectedMonth = taskManager.selectedDate
        }
    }
    
    private var daysInMonth: [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let offsetDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        let startDate = calendar.date(byAdding: .day, value: -offsetDays, to: startOfMonth) ?? startOfMonth
        
        var days: [Date] = []
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        return days
    }
}

struct CompactCalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasDueTasks: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 24, height: 24)
                
                if hasDueTasks {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -8)
                }
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
}
