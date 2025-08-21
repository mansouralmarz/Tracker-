import Foundation
import SwiftUI

// MARK: - Note Models
struct Attachment: Identifiable, Codable {
    var id = UUID()
    var type: String // "image" | "pdf" | "file"
    var filename: String // stored filename on disk
    var originalFilename: String?
    var createdAt: Date = Date()
}

struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isClipboardNote: Bool = false // New property to distinguish clipboard notes
    var lastEditTime: Date // Track when the note was last edited for clipboard timer
    var attachments: [Attachment]? = []
    var chat: [ChatMessage]? = []
    
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

// MARK: - Chat
struct ChatMessage: Identifiable, Codable {
    enum Role: String, Codable { case user, assistant }
    var id = UUID()
    var role: Role
    var content: String
    var createdAt: Date = Date()
}

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNoteId: UUID?
    @Published var useAdvancedEditor: Bool = UserDefaults.standard.bool(forKey: "UseAdvancedEditor")
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "SavedNotes"
    private var cleanupTimer: Timer?
    private let attachmentsFolderName = "Attachments"
    private let apiKeyKey = "OpenAI_API_Key"
    
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

    func setUseAdvancedEditor(_ value: Bool) {
        useAdvancedEditor = value
        UserDefaults.standard.set(value, forKey: "UseAdvancedEditor")
        objectWillChange.send()
    }

    // MARK: - Chat storage
    func appendChatMessage(noteId: UUID, role: ChatMessage.Role, content: String) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        let msg = ChatMessage(role: role, content: content)
        if notes[index].chat == nil { notes[index].chat = [] }
        notes[index].chat?.append(msg)
        notes[index].updatedAt = Date()
        objectWillChange.send()
        saveNotes()
    }
    
    func clearChat(noteId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[index].chat = []
        objectWillChange.send()
        saveNotes()
    }
    
    // MARK: - Optional OpenAI API
    func setOpenAIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: apiKeyKey)
    }
    
    func getOpenAIKey() -> String? { UserDefaults.standard.string(forKey: apiKeyKey) }
    
    func generateAIReply(noteId: UUID, prompt: String, noteContext: String) async -> String {
        if let apiKey = getOpenAIKey(), !apiKey.isEmpty {
            // Minimal call; fails gracefully
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let system = "You are a helpful writing assistant inside a notes app. Be concise."
            let user = "Context:\n\(noteContext)\n\nUser:\n\(prompt)"
            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ],
                "temperature": 0.4
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let msg = choices.first?["message"] as? [String: Any],
                       let content = msg["content"] as? String {
                        return content
                    }
                }
            } catch { }
        }
        // Local fallback
        return "(offline) I received: \(prompt)."
    }

    // Completion-based variant to avoid Swift concurrency Task name conflicts
    func generateAIReply(noteId: UUID, prompt: String, noteContext: String, completion: @escaping (String) -> Void) {
        if let apiKey = getOpenAIKey(), !apiKey.isEmpty {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let system = "You are a helpful writing assistant inside a notes app. Be concise."
            let user = "Context:\n\(noteContext)\n\nUser:\n\(prompt)"
            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ],
                "temperature": 0.4
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: request) { data, response, error in
                var reply = "(offline) I received: \(prompt)."
                if let data = data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let msg = choices.first?["message"] as? [String: Any],
                       let content = msg["content"] as? String {
                        reply = content
                    }
                }
                DispatchQueue.main.async { completion(reply) }
            }.resume()
        } else {
            DispatchQueue.main.async { completion("(offline) I received: \(prompt).") }
        }
    }
    
    func addNote(title: String, content: String) -> UUID {
        let newNote = Note(title: title, content: "")
        objectWillChange.send()
        notes.append(newNote)
        selectedNoteId = newNote.id
        saveNotes()
        return newNote.id
    }
    
    func updateNoteContent(_ note: Note, content: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            objectWillChange.send()
            notes[index].content = content
            notes[index].updatedAt = Date()
            notes[index].lastEditTime = Date() // Update last edit time
            saveNotes()
        }
    }
    
    func updateNoteTitle(_ note: Note, title: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            objectWillChange.send()
            notes[index].title = title
            notes[index].updatedAt = Date()
            notes[index].lastEditTime = Date() // Update last edit time
            saveNotes()
        }
    }
    
    func deleteNote(_ note: Note) {
        // Remove files on disk for this note's attachments
        if let atts = note.attachments, !atts.isEmpty {
            for att in atts {
                if let url = attachmentURL(for: att) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        notes.removeAll { $0.id == note.id }
        if selectedNoteId == note.id {
            selectedNoteId = notes.first?.id
        }
        saveNotes()
    }
    
    func addClipboardNote(title: String, content: String) -> UUID {
        let newNote = Note(title: title, content: "", isClipboardNote: true)
        objectWillChange.send()
        notes.append(newNote)
        selectedNoteId = newNote.id
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

    // MARK: - Attachments
    private func attachmentsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MansoursNotes", isDirectory: true).appendingPathComponent(attachmentsFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func attachmentURL(for att: Attachment) -> URL? {
        let dir = attachmentsDirectory()
        return dir.appendingPathComponent(att.filename, isDirectory: false)
    }

    func addAttachment(to noteId: UUID, data: Data, fileExtension: String, originalFilename: String?) -> Attachment? {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return nil }
        let attId = UUID()
        let sanitizedExt = fileExtension.replacingOccurrences(of: ".", with: "")
        let filename = "\(attId).\(sanitizedExt)"
        let url = attachmentsDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            var type = "file"
            if ["png","jpg","jpeg","gif","heic","tiff"].contains(sanitizedExt.lowercased()) { type = "image" }
            if ["pdf"].contains(sanitizedExt.lowercased()) { type = "pdf" }
            let att = Attachment(type: type, filename: filename, originalFilename: originalFilename, createdAt: Date())
            if notes[index].attachments == nil { notes[index].attachments = [] }
            notes[index].attachments?.append(att)
            notes[index].updatedAt = Date()
            notes[index].lastEditTime = Date()
            objectWillChange.send()
            saveNotes()
            return att
        } catch {
            return nil
        }
    }
}

// MARK: - Analytics Manager (tracks app active time per day)
class AnalyticsManager: ObservableObject {
    @Published var dailySeconds: [String: TimeInterval] = [:] // key: yyyy-MM-dd
    private var currentStart: Date?
    private let storageKey = "DailyActiveSeconds"
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            dailySeconds = decoded
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willTerminate), name: NSApplication.willTerminateNotification, object: nil)
    }

    @objc private func didBecomeActive() { startSession() }
    @objc private func willResignActive() { endSession() }
    @objc private func willTerminate() { endSession() }

    func startSession() { if currentStart == nil { currentStart = Date() } }

    func endSession() {
        guard let start = currentStart else { return }
        let seconds = max(0, Date().timeIntervalSince(start))
        currentStart = nil
        let key = dateKey(Date())
        dailySeconds[key, default: 0] += seconds
        save()
        objectWillChange.send()
    }

    func hoursLast7Days() -> [(date: Date, hours: Double)] {
        var results: [(Date, Double)] = []
        let cal = Calendar.current
        for offset in stride(from: 6, through: 0, by: -1) {
            if let day = cal.date(byAdding: .day, value: -offset, to: Date()) {
                let key = dateKey(day)
                let h = (dailySeconds[key] ?? 0) / 3600.0
                results.append((day, h))
            }
        }
        return results
    }

    private func dateKey(_ date: Date) -> String { formatter.string(from: date) }
    private func save() {
        if let data = try? JSONEncoder().encode(dailySeconds) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
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

    // Create a task on a specific calendar day regardless of current selection
    func addTask(on date: Date, title: String) -> UUID? {
        let newTask = Task(title: title)
        let taskId = newTask.id
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: date)
        if let listIndex = dailyTaskLists.firstIndex(where: { cal.isDate($0.date, inSameDayAs: targetDay) }) {
            objectWillChange.send()
            dailyTaskLists[listIndex].tasks.append(newTask)
            dailyTaskLists = dailyTaskLists
        } else {
            let newList = DailyTaskList(date: targetDay, tasks: [newTask])
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
                    // Toggle the subtask state
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted.toggle()
                    dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].updatedAt = Date()
                    dailyTaskLists[listIndex].tasks[taskIndex].updatedAt = Date()

                    // Cascade only when checking; do not auto-recheck on uncheck
                    if dailyTaskLists[listIndex].tasks[taskIndex].subtasks[subtaskIndex].isCompleted {
                        markAllSubSubtasksComplete(subtaskId: subtaskId, listIndex: listIndex, taskIndex: taskIndex, subtaskIndex: subtaskIndex)
                    }

                    // Recompute parent completion from children without overriding explicit subtask toggle
                    checkParentCompletion(taskId: dailyTaskLists[listIndex].tasks[taskIndex].id, listIndex: listIndex, taskIndex: taskIndex)
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

