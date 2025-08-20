import Foundation
import SwiftUI

// MARK: - Note Models
struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isClipboardNote: Bool = false // New property to distinguish clipboard notes
    var lastEditTime: Date // Track when the note was last edited for clipboard timer
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }
    
    var displayTitle: String {
        if title.isEmpty {
            return content.isEmpty ? "Untitled Note" : String(content.prefix(30))
        }
        return title
    }
    
    init(title: String, content: String) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastEditTime = Date()
    }
    
    init(title: String, content: String, isClipboardNote: Bool) {
        self.title = title
        self.content = content
        self.isClipboardNote = isClipboardNote
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastEditTime = Date()
    }
}

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNoteId: UUID?
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "SavedNotes"
    private var cleanupTimer: Timer?
    
    var selectedNote: Note? {
        notes.first { $0.id == selectedNoteId }
    }
    
    init() {
        loadNotes()
        startCleanupTimer()
        if notes.isEmpty {
            addNote(title: "Welcome Note", content: "Welcome to your Notes App! Start writing your thoughts here.")
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    private func startCleanupTimer() {
        // Clean up expired clipboard notes every hour
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupExpiredClipboardNotes()
        }
    }
    
    func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let savedNotes = try? JSONDecoder().decode([Note].self, from: data) {
            notes = savedNotes
            if selectedNoteId == nil && !notes.isEmpty {
                selectedNoteId = notes.first?.id
            }
        }
    }
    
    func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: notesKey)
        }
    }
    
    func addNote(title: String, content: String) -> UUID {
        let newNote = Note(title: title, content: content)
        notes.append(newNote)
        selectedNoteId = newNote.id
        saveNotes()
        return newNote.id
    }
    
    func updateNoteContent(_ note: Note, content: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].content = content
            notes[index].updatedAt = Date()
            notes[index].lastEditTime = Date() // Update last edit time
            saveNotes()
        }
    }
    
    func updateNoteTitle(_ note: Note, title: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].title = title
            notes[index].updatedAt = Date()
            notes[index].lastEditTime = Date() // Update last edit time
            saveNotes()
        }
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        if selectedNoteId == note.id {
            selectedNoteId = notes.first?.id
        }
        saveNotes()
    }
    
    func addClipboardNote(title: String, content: String) -> UUID {
        let newNote = Note(title: title, content: content, isClipboardNote: true)
        notes.append(newNote)
        saveNotes()
        return newNote.id
    }
    
    func cleanupExpiredClipboardNotes() {
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        notes.removeAll { note in
            note.isClipboardNote && note.lastEditTime < cutoffDate
        }
        saveNotes()
    }
    
    func getClipboardNotes() -> [Note] {
        return notes.filter { $0.isClipboardNote }
    }
    
    func getRegularNotes() -> [Note] {
        return notes.filter { !$0.isClipboardNote }
    }
}

// MARK: - Task Models
struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var subtasks: [Subtask]
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    var completionPercentage: Double {
        guard !subtasks.isEmpty else { return isCompleted ? 100.0 : 0.0 }
        let completedSubtasks = subtasks.filter { $0.isCompleted }.count
        return Double(completedSubtasks) / Double(subtasks.count) * 100.0
    }
    
    var isFullyCompleted: Bool {
        return isCompleted && subtasks.allSatisfy { $0.isFullyCompleted }
    }
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
        self.subtasks = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct Subtask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var subSubtasks: [SubSubtask]
    var createdAt: Date
    var updatedAt: Date
    
    var isFullyCompleted: Bool {
        return isCompleted && subSubtasks.allSatisfy { $0.isCompleted }
    }
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
        self.subSubtasks = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct SubSubtask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct DailyTaskList: Codable {
    var date: Date
    var tasks: [Task]
    
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var completedTasksCount: Int {
        return tasks.filter { $0.isCompleted }.count
    }
    
    var totalTasksCount: Int {
        return tasks.count
    }
    
    var overallCompletionPercentage: Double {
        guard totalTasksCount > 0 else { return 0.0 }
        let totalSubtasks = tasks.reduce(0) { $0 + $1.subtasks.count }
        let totalSubSubtasks = tasks.reduce(0) { $0 + $1.subtasks.reduce(0) { $0 + $1.subSubtasks.count } }
        
        let totalItems = totalTasksCount + totalSubtasks + totalSubSubtasks
        let completedItems = completedTasksCount + tasks.reduce(0) { $0 + $1.subtasks.filter { $0.isCompleted }.count } + tasks.reduce(0) { $0 + $1.subtasks.reduce(0) { $0 + $1.subSubtasks.filter { $0.isCompleted }.count } }
        
        return totalItems > 0 ? Double(completedItems) / Double(totalItems) * 100.0 : 0.0
    }
}

// MARK: - Task Manager
class TaskManager: ObservableObject {
    @Published var dailyTaskLists: [DailyTaskList] = []
    @Published var selectedDate: Date
    
    private let tasksKey = "SavedTasks"
    private let defaultDueTimeKey = "DefaultDueTime"
    
    init() {
        self.selectedDate = Date()
        loadTasks()
        if dailyTaskLists.isEmpty {
            createDefaultTaskList()
        }
    }
    
    // MARK: - Task Management
    func addTask(title: String) -> UUID? {
        let newTask = Task(title: title)
        let taskId = newTask.id
        let cal = Calendar.current
        
        if let listIndex = dailyTaskLists.enumerated().first(where: { _, list in
            cal.isDate(list.date, inSameDayAs: selectedDate)
        })?.offset {
            objectWillChange.send()
            dailyTaskLists[listIndex].tasks.append(newTask)
            // Force-publish nested mutation
            dailyTaskLists = dailyTaskLists
        } else {
            let normalizedDate = cal.startOfDay(for: selectedDate)
            let newList = DailyTaskList(date: normalizedDate, tasks: [newTask])
            objectWillChange.send()
            dailyTaskLists.append(newList)
            dailyTaskLists = dailyTaskLists
        }
        
        saveTasks()
        return taskId
    }

    // Insert a new task after a given task id
    func insertTask(after taskId: UUID, title: String) -> UUID? {
        guard let listIndex = dailyTaskLists.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else { return nil }
        guard let idx = dailyTaskLists[listIndex].tasks.firstIndex(where: { $0.id == taskId }) else { return addTask(title: title) }
        let new = Task(title: title)
        dailyTaskLists[listIndex].tasks.insert(new, at: idx + 1)
        saveTasks()
        return new.id
    }
    
    func updateTaskTitle(_ taskId: UUID, title: String) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            if let taskIndex = list.tasks.firstIndex(where: { $0.id == taskId }) {
                dailyTaskLists[listIndex].tasks[taskIndex].title = title
                dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                break
            }
        }
        saveTasks()
    }
    
    func toggleTask(_ taskId: UUID) {
        objectWillChange.send()
        for (listIndex, list) in dailyTaskLists.enumerated() {
            if let taskIndex = list.tasks.firstIndex(where: { $0.id == taskId }) {
                dailyTaskLists[listIndex].tasks[taskIndex].isCompleted.toggle()
                dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                
                // Cascading completion only when marking complete
                if dailyTaskLists[listIndex].tasks[taskIndex].isCompleted {
                    markAllSubtasksComplete(taskId: taskId, listIndex: listIndex, taskIndex: taskIndex)
                }
                break
            }
        }
        // Force publish nested mutation
        dailyTaskLists = dailyTaskLists
        saveTasks()
    }

    // Set or clear due date for a task
    func setTaskDueDate(_ taskId: UUID, date: Date?) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            if let taskIndex = list.tasks.firstIndex(where: { $0.id == taskId }) {
                dailyTaskLists[listIndex].tasks[taskIndex].dueDate = date
                dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                break
            }
        }
        saveTasks()
    }
    
    func deleteTask(_ taskId: UUID) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            dailyTaskLists[listIndex].tasks.removeAll { $0.id == taskId }
        }
        saveTasks()
    }
    
    // MARK: - Subtask Management
    func addSubtask(to taskId: UUID, title: String) -> UUID? {
        let newSubtask = Subtask(title: title)
        let subtaskId = newSubtask.id
        
        for (listIndex, list) in dailyTaskLists.enumerated() {
            if let taskIndex = list.tasks.firstIndex(where: { $0.id == taskId }) {
                dailyTaskLists[listIndex].tasks[taskIndex].subtasks.append(newSubtask)
                dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                break
            }
        }
        
        saveTasks()
        return subtaskId
    }

    // Insert a subtask after a given subtask id
    func insertSubtask(after subtaskId: UUID, title: String) -> UUID? {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                if let idx = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    let new = Subtask(title: title)
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks.insert(new, at: idx + 1)
                    dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                    saveTasks()
                    return new.id
                }
            }
        }
        return nil
    }
    
    func updateSubtaskTitle(_ subtaskId: UUID, title: String) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                if let subtaskIndex = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].title = title
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                    dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                    break
                }
            }
        }
        saveTasks()
    }
    
    func toggleSubtask(_ subtaskId: UUID) {
        objectWillChange.send()
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                if let subtaskIndex = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted.toggle()
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                    dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                    
                    // Cascading completion for sub-subtasks
                    if dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted {
                        markAllSubSubtasksComplete(subtaskId: subtaskId, listIndex: listIndex, taskIndex: taskIndex, subtaskIndex: subtaskIndex)
                    }
                    
                    // Check if all sub-subtasks are complete to auto-complete parent
                    checkSubtaskCompletion(subtaskId: subtaskId, listIndex: listIndex, taskIndex: taskIndex, subtaskIndex: subtaskIndex)
                    break
                }
            }
        }
        dailyTaskLists = dailyTaskLists
        saveTasks()
    }
    
    func deleteSubtask(_ subtaskId: UUID) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                dailyTaskLists[listIndex].tasks[taskIndex].subtasks.removeAll { $0.id == subtaskId }
            }
        }
        saveTasks()
    }
    
    // MARK: - Sub-subtask Management
    func addSubSubtask(to subtaskId: UUID, title: String) -> UUID? {
        let newSubSubtask = SubSubtask(title: title)
        let subSubtaskId = newSubSubtask.id
        
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                if let subtaskIndex = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.append(newSubSubtask)
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                    dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                    break
                }
            }
        }
        
        saveTasks()
        return subSubtaskId
    }

    // Insert sub-subtask after a given sub-subtask id
    func insertSubSubtask(after subSubtaskId: UUID, title: String) -> UUID? {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                for (subtaskIndex, subtask) in task.subtasks.enumerated() {
                    if let idx = subtask.subSubtasks.firstIndex(where: { $0.id == subSubtaskId }) {
                        let new = SubSubtask(title: title)
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.insert(new, at: idx + 1)
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                        dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                        saveTasks()
                        return new.id
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Indent/Outdent Conversions
    func indentTaskToSubtask(_ taskId: UUID) -> UUID? {
        guard let listIndex = dailyTaskLists.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) else { return nil }
        guard let idx = dailyTaskLists[listIndex].tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
        // Needs a valid parent task above
        guard idx > 0 else { return nil }
        objectWillChange.send()
        let task = dailyTaskLists[listIndex].tasks.remove(at: idx)
        let newSub = Subtask(title: task.title, isCompleted: task.isCompleted)
        dailyTaskLists[listIndex].tasks[idx - 1].subtasks.append(newSub)
        dailyTaskLists = dailyTaskLists
        saveTasks()
        return newSub.id
    }

    func outdentSubtaskToTask(_ subtaskId: UUID) -> UUID? {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                if let subtaskIndex = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    let sub = dailyTaskLists[listIndex].tasks[taskIndex].subtasks.remove(at: subtaskIndex)
                    var newTask = Task(title: sub.title, isCompleted: sub.isCompleted)
                    // Promote sub-subtasks as subtasks
                    newTask.subtasks = sub.subSubtasks.map { Subtask(title: $0.title, isCompleted: $0.isCompleted) }
                    dailyTaskLists[listIndex].tasks.insert(newTask, at: taskIndex + 1)
                    saveTasks()
                    return newTask.id
                }
            }
        }
        return nil
    }

    func indentSubtaskToSubSubtask(_ subtaskId: UUID) -> UUID? {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                if let subtaskIndex = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
                    // Needs a valid parent subtask above
                    guard subtaskIndex > 0 else { return nil }
                    objectWillChange.send()
                    let sub = dailyTaskLists[listIndex].tasks[taskIndex].subtasks.remove(at: subtaskIndex)
                    let prevIndex = subtaskIndex - 1
                    let new = SubSubtask(title: sub.title, isCompleted: sub.isCompleted)
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[prevIndex].subSubtasks.append(new)
                    dailyTaskLists = dailyTaskLists
                    saveTasks()
                    return new.id
                }
            }
        }
        return nil
    }

    func outdentSubSubtaskToSubtask(_ subSubtaskId: UUID) -> UUID? {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                for (subtaskIndex, subtask) in task.subtasks.enumerated() {
                    if let idx = subtask.subSubtasks.firstIndex(where: { $0.id == subSubtaskId }) {
                        let subsub = dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.remove(at: idx)
                        let new = Subtask(title: subsub.title, isCompleted: subsub.isCompleted)
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks.insert(new, at: subtaskIndex + 1)
                        saveTasks()
                        return new.id
                    }
                }
            }
        }
        return nil
    }
    
    func updateSubSubtaskTitle(_ subSubtaskId: UUID, title: String) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                for (subtaskIndex, subtask) in task.subtasks.enumerated() {
                    if let subSubtaskIndex = subtask.subSubtasks.firstIndex(where: { $0.id == subSubtaskId }) {
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].title = title
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].updatedAt = Date()
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                        dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                        break
                    }
                }
            }
        }
        saveTasks()
    }
    
    func toggleSubSubtask(_ subSubtaskId: UUID) {
        objectWillChange.send()
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                for (subtaskIndex, subtask) in task.subtasks.enumerated() {
                    if let subSubtaskIndex = subtask.subSubtasks.firstIndex(where: { $0.id == subSubtaskId }) {
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].isCompleted.toggle()
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].updatedAt = Date()
                        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                        dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
                        
                        // Check if all sub-subtasks are complete to auto-complete parent
                        checkSubSubtaskCompletion(subSubtaskId: subSubtaskId, listIndex: listIndex, taskIndex: taskIndex, subtaskIndex: subtaskIndex, subSubtaskIndex: subSubtaskIndex)
                        break
                    }
                }
            }
        }
        dailyTaskLists = dailyTaskLists
        saveTasks()
    }
    
    func deleteSubSubtask(_ subSubtaskId: UUID) {
        for (listIndex, list) in dailyTaskLists.enumerated() {
            for (taskIndex, task) in list.tasks.enumerated() {
                for (subtaskIndex, subtask) in task.subtasks.enumerated() {
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.removeAll { $0.id == subSubtaskId }
                }
            }
        }
        saveTasks()
    }
    
    // MARK: - Helper Methods
    func getCurrentDayTaskList() -> DailyTaskList? {
        return dailyTaskLists.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    func updateSelectedDate(_ date: Date) {
        selectedDate = date
        if getCurrentDayTaskList() == nil {
            createDefaultTaskList()
        }
    }
    
    func getTasksWithDueDate(_ date: Date) -> [Task] {
        var tasks: [Task] = []
        for list in dailyTaskLists {
            for task in list.tasks {
                if let dueDate = task.dueDate, Calendar.current.isDate(dueDate, inSameDayAs: date) {
                    tasks.append(task)
                }
            }
        }
        return tasks
    }
    
    func getAllTasks() -> [Task] {
        return dailyTaskLists.flatMap { $0.tasks }
    }
    
    func setDefaultDueTime(_ time: Date) {
        UserDefaults.standard.set(time, forKey: defaultDueTimeKey)
    }
    
    func getDefaultDueTime() -> Date {
        return UserDefaults.standard.object(forKey: defaultDueTimeKey) as? Date ?? Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    }
    
    // MARK: - Private Methods
    private func createDefaultTaskList() {
        let newList = DailyTaskList(date: selectedDate, tasks: [])
        dailyTaskLists.append(newList)
        saveTasks()
    }
    
    private func markAllSubtasksComplete(taskId: UUID, listIndex: Int, taskIndex: Int) {
        for subtaskIndex in dailyTaskLists[listIndex].tasks[taskIndex].subtasks.indices {
            dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted = true
            dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
            
            // Mark all sub-subtasks complete
            for subSubtaskIndex in dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.indices {
                dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].isCompleted = true
                dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].updatedAt = Date()
            }
        }
    }
    
    private func markAllSubSubtasksComplete(subtaskId: UUID, listIndex: Int, taskIndex: Int, subtaskIndex: Int) {
        for subSubtaskIndex in dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.indices {
            dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].isCompleted = true
            dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks[subSubtaskIndex].updatedAt = Date()
        }
    }
    
    private func checkParentCompletion(taskId: UUID, listIndex: Int, taskIndex: Int) {
        let allSubtasksComplete = dailyTaskLists[listIndex].tasks[taskIndex].subtasks.allSatisfy { $0.isCompleted }
        let allSubSubtasksComplete = dailyTaskLists[listIndex].tasks[taskIndex].subtasks.allSatisfy { subtask in
            subtask.subSubtasks.allSatisfy { $0.isCompleted }
        }
        // Parent reflects aggregate state; unchecking any child will uncheck parent
        dailyTaskLists[listIndex].tasks[taskIndex].isCompleted = (allSubtasksComplete && allSubSubtasksComplete)
        dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
    }
    
    private func checkSubtaskCompletion(subtaskId: UUID, listIndex: Int, taskIndex: Int, subtaskIndex: Int) {
        let allSubSubtasksComplete = dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.allSatisfy { $0.isCompleted }
        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted = allSubSubtasksComplete
        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
        dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
        // Also recompute parent task completion
        checkParentCompletion(taskId: dailyTaskLists[listIndex].tasks[taskIndex].id, listIndex: listIndex, taskIndex: taskIndex)
    }
    
    private func checkSubSubtaskCompletion(subSubtaskId: UUID, listIndex: Int, taskIndex: Int, subtaskIndex: Int, subSubtaskIndex: Int) {
        let allSubSubtasksComplete = dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].subSubtasks.allSatisfy { $0.isCompleted }
        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted = allSubSubtasksComplete
        dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
        dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()
        checkParentCompletion(taskId: dailyTaskLists[listIndex].tasks[taskIndex].id, listIndex: listIndex, taskIndex: taskIndex)
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let savedLists = try? JSONDecoder().decode([DailyTaskList].self, from: data) {
            dailyTaskLists = savedLists
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(dailyTaskLists) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
}

