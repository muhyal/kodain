import Foundation
import Combine // Needed for ObservableObject
import SwiftUI // Needed for Binding
import GoogleGenerativeAI

// MARK: - Data Structures

// Folder Structure
struct Folder: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var parentId: UUID? // nil for root level folders
    var createdAt: Date
    var colorHex: String? // Folders can also have colors
    
    // Basic initializer
    init(id: UUID = UUID(), name: String, parentId: UUID? = nil, createdAt: Date = Date(), colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
        self.colorHex = colorHex
    }
}

// Represents a message ready for display in the UI
struct DisplayMessage: Identifiable, Equatable {
    let id: String // Stable ID for List updates (e.g., entryUUID + role)
    let entryId: UUID // Original ChatEntry ID for actions like delete
    let role: ChatEntry.Role // User or Model
    let content: String
    let screenshotData: Data? // Optional screenshot data for user messages
    let timestamp: Date
    let metadata: ChatEntryMetadata? // Optional metadata for model messages
}

// Define the ChatEntry.Role enum if it's not already globally accessible
extension ChatEntry {
    enum Role: String, Codable { // Assuming Codable conformance if needed
        case user
        case model
    }
}

// Simple struct to hold metadata, assuming it might be defined elsewhere or inline
struct ChatEntryMetadata: Equatable { // Assuming ChatEntryMetadata definition
    let wordCount: Int?
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
    let responseTimeMs: Int?
    let modelName: String?
}

// MARK: - Search Result Structure

/// Represents a unified search result item.
struct SearchResult: Identifiable, Hashable {
    let id: UUID // Use the original item's ID
    let type: ResultType
    let name: String // Title for sessions, name for folders
    let relevanceDate: Date // createdAt for both, used for sorting
    let colorHex: String? // Optional color

    // Add original object references if needed for navigation, but keep struct simple
    // let folder: Folder?
    // let session: ChatSession?

    enum ResultType: Hashable {
        case folder
        case chatSession
        // case chatEntry // Future enhancement for content search
    }
}

// MARK: - Data Manager Class

// Manages multiple chat sessions and folders
@MainActor // Ensure all updates to @Published properties happen on the main thread
class DataManager: ObservableObject {
    private let sessionsKey = "chatSessions_v1" // Use a new key if format changes
    private let foldersKey = "chatFolders_v1" // Key for saving folders

    // Array of all chat sessions, sorted by creation date (newest first)
    @Published var chatSessions: [ChatSession] = []
    @Published var folders: [Folder] = [] // Add published array for folders
    // ID of the currently selected/active session
    @Published var activeSessionId: UUID? = nil {
        didSet {
            // Update active entries and display messages when session changes
            updateActiveSessionDisplayMessages()
        }
    }

    // Computed property to get the index of the active session
    var activeSessionIndex: Int? {
        chatSessions.firstIndex { $0.id == activeSessionId }
    }

    // Computed property to get the entries of the currently active session
    var activeSessionEntries: [ChatEntry] {
        guard let index = activeSessionIndex else { return [] }
        return chatSessions[index].entries
    }

    // Pre-processed and sorted messages for the active session view
    @Published var activeSessionDisplayMessages: [DisplayMessage] = []

    // Add managers for different responsibilities
    lazy var sessionManager: SessionManager = SessionManager(dataManager: self)
    // Add FolderManager instance
    lazy var folderManager: FolderManager = FolderManager(dataManager: self)
    // Add EntryManager instance
    lazy var entryManager: EntryManager = EntryManager(dataManager: self)

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadFolders()
        loadSessions()
        // Ensure active session is valid on init
        if let firstSessionId = chatSessions.first?.id {
            setActiveSession(id: firstSessionId)
        } else {
            sessionManager.createNewSession(activate: true)
        }
        updateActiveSessionDisplayMessages()
        print("DataManager initialized. Session, Folder & Entry Managers ready.") // Updated log
    }

    // MARK: - SwiftUI Preview Helper
    #if DEBUG
    static var preview: DataManager = {
        let manager = DataManager()
        // Optionally populate with sample data for previews
        let folder1 = Folder(name: "Sample Folder")
        manager.folders = [folder1]
        manager.chatSessions = [
            ChatSession(title: "Preview Session 1", folderId: nil),
            ChatSession(title: "Preview Session 2 (Favorite)", createdAt: Date(), isFavorite: true, folderId: folder1.id),
            ChatSession(title: "Old Session", createdAt: Date(timeIntervalSinceNow: -86400), folderId: nil)
        ]
        if let firstId = manager.chatSessions.first?.id {
            manager.activeSessionId = firstId
        }
        // Add sample entries if needed for ChatDetailView previews
        if let firstSessionIndex = manager.chatSessions.firstIndex(where: { $0.id == manager.activeSessionId }) {
            // Create a single entry with both question and answer
            let previewEntry = ChatEntry(question: "Hello, preview!", 
                                       answer: "Hi there! This is a preview response.")
            // Assign the single entry to the session
            manager.chatSessions[firstSessionIndex].entries = [previewEntry]
            manager.updateActiveSessionDisplayMessages() // Update display messages for preview
        }

        print("DataManager: Created PREVIEW instance.")
        return manager
    }()
    #endif

    // MARK: - Persistence
    func saveSessions() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(chatSessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
            print("DataManager: Sessions saved successfully.")
        } catch {
            print("DataManager Error: Failed to save sessions: \(error.localizedDescription)")
        }
    }

    // Loads sessions from UserDefaults
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else {
            print("DataManager: No session data found in UserDefaults.")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            chatSessions = try decoder.decode([ChatSession].self, from: data)
            // Ensure sessions are sorted by date, newest first, upon loading
            chatSessions.sort { $0.createdAt > $1.createdAt }
            print("DataManager: Sessions loaded successfully (\(chatSessions.count) sessions).")
        } catch {
            print("DataManager Error: Failed to load sessions: \(error.localizedDescription)")
            // Consider clearing invalid data
            // UserDefaults.standard.removeObject(forKey: sessionsKey)
            // chatSessions = []
        }

        // After loading, ensure active session data is consistent
        if let currentActiveId = activeSessionId, !chatSessions.contains(where: { $0.id == currentActiveId }) {
            // If the previously active session ID no longer exists, reset it
            activeSessionId = chatSessions.first?.id
        }
        // Initial population of active entries and display messages
        updateActiveSessionDisplayMessages()
    }

    /// Updates the color hex string for a specific session.
    func updateSessionColor(withId id: UUID, colorHex: String?) {
        guard let index = chatSessions.firstIndex(where: { $0.id == id }) else { return }
        // Create a mutable copy of the struct
        var sessionToUpdate = chatSessions[index]
        // Update the property on the copy
        sessionToUpdate.colorHex = colorHex
        // Replace the item in the array with the updated copy
        chatSessions[index] = sessionToUpdate
        // No need for objectWillChange.send() as the array itself is modified
        saveSessions()
        print("DataManager: Updated color for session \(id) to \(colorHex ?? "None")")
    }

    // MARK: - Folder Management
    // ... deleteFolder, renameFolder, moveFolder, updateFolderColor ...

    // MARK: - Persistence
    func saveFolders() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(folders)
            UserDefaults.standard.set(data, forKey: foldersKey)
            print("DataManager: Folders saved successfully.")
        } catch {
            print("DataManager Error: Failed to save folders: \(error.localizedDescription)")
        }
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: foldersKey) else {
            print("DataManager: No folder data found in UserDefaults.")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            folders = try decoder.decode([Folder].self, from: data)
            // Optional: Sort folders?
            print("DataManager: Folders loaded successfully (\(folders.count) folders).")
        } catch {
            print("DataManager Error: Failed to load folders: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Properties & Helpers for UI
    
    /// Returns folders that are at the root level (no parent).
    var rootFolders: [Folder] {
        folders.filter { $0.parentId == nil }.sorted { $0.name < $1.name } // Sort alphabetically
    }
    
    /// Returns sessions that are at the root level (not in any folder).
    var rootSessions: [ChatSession] {
        chatSessions.filter { $0.folderId == nil }.sorted { $0.createdAt > $1.createdAt } // Sort by date
    }
    
    /// Returns sessions belonging to a specific folder ID.
    func sessions(in folderId: UUID) -> [ChatSession] {
        chatSessions.filter { $0.folderId == folderId }.sorted { $0.createdAt > $1.createdAt } // Keep sorted by date
    }
    
    // Add the subfolders function back
    /// Returns subfolders belonging to a specific folder ID.
    func subfolders(in parentFolderId: UUID) -> [Folder] {
        folders.filter { $0.parentId == parentFolderId }.sorted { $0.name < $1.name } // Sort alphabetically
    }
    
    /// Checks if a folder or any of its descendants contain at least one favorite session.
    func folderContainsFavorites(folderId: UUID) -> Bool {
        // Check direct sessions in the folder
        if sessions(in: folderId).contains(where: { $0.isFavorite }) {
            return true
        }
        
        // Recursively check subfolders
        for subfolder in subfolders(in: folderId) {
            if folderContainsFavorites(folderId: subfolder.id) { // Recursive call
                return true
            }
        }
        
        // No favorites found in this branch
        return false
    }

    // MARK: - Filtered Data for UI (Performance Optimization)

    @MainActor // Ensure filtering runs on the main thread for UI updates
    func filteredFolders(parentId: UUID?, currentFilter: SidebarFilter, colorHexFilter: String?) -> [Folder] {
        // Start with the correct base list of folders
        let baseFolders = parentId == nil ? rootFolders : subfolders(in: parentId!)
        
        // Apply filters sequentially
        return baseFolders.filter { folder in
            // 1. Color Filter (Apply first if present)
            if let colorFilter = colorHexFilter, folder.colorHex != colorFilter {
                return false // Exclude if color doesn't match the filter
            }
            
            // 2. Favorites Filter (Apply if .favorites is selected)
            if currentFilter == .favorites && !folderContainsFavorites(folderId: folder.id) {
                return false // Exclude if filter is .favorites and folder doesn't contain any
            }
            
            // If all checks pass, include the folder
            return true
        }
        // Note: Sorting is already handled by rootFolders/subfolders properties
    }

    @MainActor // Ensure filtering runs on the main thread for UI updates
    func filteredSessions(parentId: UUID?, currentFilter: SidebarFilter, colorHexFilter: String?) -> [ChatSession] {
        // Determine the base list of sessions based on context
        let baseSessions: [ChatSession]
        if parentId == nil && colorHexFilter != nil {
            // If filtering by color at the root, start with ALL sessions
            baseSessions = chatSessions.sorted { $0.createdAt > $1.createdAt } // Keep consistent sorting
        } else {
            // Otherwise, use only sessions in the current folder (or root if no folder selected)
            baseSessions = parentId == nil ? rootSessions : sessions(in: parentId!)
        }
        
        // Apply filters sequentially
        return baseSessions.filter { session in
            // 1. Color Filter (Apply first if present)
            if let colorFilter = colorHexFilter, session.colorHex != colorFilter {
                return false // Exclude if color doesn't match the filter
            }
            
            // 2. Favorites Filter (Apply if .favorites is selected)
            if currentFilter == .favorites && !session.isFavorite {
                return false // Exclude if filter is .favorites and session is not a favorite
            }
            
            // If all checks pass, include the session
            return true
        }
        // Note: Sorting is already handled by rootSessions/sessions(in:) methods
    }

    /// Checks if a folder (`folderId`) is a descendant of another folder (`ancestorId`).
    func isDescendant(folderId: UUID, of ancestorId: UUID) -> Bool {
        guard let folder = folders.first(where: { $0.id == folderId }), let parentId = folder.parentId else {
            // If the folder doesn't exist or has no parent, it cannot be a descendant
            return false
        }
        
        // If the direct parent is the ancestor, it's a descendant
        if parentId == ancestorId {
            return true
        }
        
        // Recursively check the parent
        return isDescendant(folderId: parentId, of: ancestorId)
    }

    // MARK: - Search Functionality

    /// Searches across all chat sessions for a matching query string in the title.
    /// Returns a sorted array of matching sessions (newest first).
    func searchChatSessions(query: String) -> [ChatSession] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [] // Return empty if query is empty or just whitespace
        }
        let lowercasedQuery = query.lowercased()
        return chatSessions.filter {
            $0.title.lowercased().contains(lowercasedQuery)
            // || ($0.entries.contains { entry in // Example: Add content search later
            //     entry.question.lowercased().contains(lowercasedQuery) ||
            //     entry.answer.lowercased().contains(lowercasedQuery)
            // })
        }.sorted { $0.createdAt > $1.createdAt } // Keep consistent sorting
    }

    /// Searches across folders and chat sessions based on their names/titles.
    /// Returns a combined and sorted list of SearchResult objects.
    func searchEverything(query: String) -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let lowercasedQuery = query.lowercased()

        // Search Folders
        let folderResults = folders.compactMap { folder -> SearchResult? in
            if folder.name.lowercased().contains(lowercasedQuery) {
                return SearchResult(
                    id: folder.id,
                    type: .folder,
                    name: folder.name,
                    relevanceDate: folder.createdAt,
                    colorHex: folder.colorHex
                )
            } else {
                return nil
            }
        }

        // Search Chat Sessions
        let sessionResults = chatSessions.compactMap { session -> SearchResult? in
            if session.title.lowercased().contains(lowercasedQuery) {
                return SearchResult(
                    id: session.id,
                    type: .chatSession,
                    name: session.title,
                    relevanceDate: session.createdAt,
                    colorHex: session.colorHex
                )
            } else {
                return nil
            }
        }

        // TODO: Add content search within chatSessions.entries later, mapping to SearchResult

        // Combine and sort results (e.g., newest first)
        let combinedResults = folderResults + sessionResults
        return combinedResults.sorted { $0.relevanceDate > $1.relevanceDate }
    }

    // MARK: - Folder Management - NEW METHODS ADDED

    // ... deleteFolder, renameFolder, moveFolder, updateFolderColor ...

    // MARK: - Session Management
    func setActiveSession(id: UUID?) {
        guard activeSessionId != id else { return } // No change if same ID
        activeSessionId = id
        // updateActiveSessionDisplayMessages() is called by didSet
    }

    // MARK: - Private Helpers
    // Update the pre-processed display messages for the active session
    // Accepts an optional list of entries to use directly (for immediate updates after modification)
    func updateActiveSessionDisplayMessages(using updatedEntries: [ChatEntry]? = nil) {
        let entriesToProcess: [ChatEntry]
        if let providedEntries = updatedEntries {
            // Use the entries passed directly (e.g., after deletion)
            entriesToProcess = providedEntries
            // print("updateActiveSessionDisplayMessages using provided entries: \(entriesToProcess.count)")
        } else {
            // Fallback to fetching from chatSessions (e.g., on session change)
            guard let fetchedEntries = chatSessions.first(where: { $0.id == activeSessionId })?.entries else {
                activeSessionDisplayMessages = []
                return
            }
            entriesToProcess = fetchedEntries
            // print("updateActiveSessionDisplayMessages fetching entries: \(entriesToProcess.count)")
        }

        // 1. Flatten Chat Entries into DisplayMessages with stable IDs
        let flattenedMessages = entriesToProcess.flatMap { entry -> [DisplayMessage] in
            var messages: [DisplayMessage] = []
            // Add user message
            if !entry.question.isEmpty {
                messages.append(DisplayMessage(
                    id: entry.id.uuidString + "-user", // Stable ID
                    entryId: entry.id,
                    role: .user,
                    content: entry.question,
                    screenshotData: entry.screenshotData,
                    timestamp: entry.timestamp,
                    metadata: nil
                ))
            }
            // Add model message
            if !entry.answer.isEmpty {
                // Construct metadata (assuming ChatEntryMetadata exists and is equatable)
                let metadata = ChatEntryMetadata(
                    wordCount: entry.wordCount,
                    promptTokenCount: entry.promptTokenCount,
                    candidatesTokenCount: entry.candidatesTokenCount,
                    totalTokenCount: entry.totalTokenCount,
                    responseTimeMs: entry.responseTimeMs,
                    modelName: entry.modelName
                )
                messages.append(DisplayMessage(
                    id: entry.id.uuidString + "-model", // Stable ID
                    entryId: entry.id,
                    role: .model,
                    content: entry.answer,
                    screenshotData: nil,
                    // Use a slightly later timestamp for model to ensure order within the same entry
                    timestamp: entry.timestamp.addingTimeInterval(0.001),
                    metadata: metadata
                ))
            }
            return messages
        }

        // 2. Sort all messages by timestamp
        let sortedMessages = flattenedMessages.sorted { $0.timestamp < $1.timestamp }

        // 3. Update the published property
        // Avoid redundant updates if the array hasn't actually changed content
        if activeSessionDisplayMessages != sortedMessages {
             activeSessionDisplayMessages = sortedMessages
             print("Updated activeSessionDisplayMessages for session \(activeSessionId?.uuidString ?? "nil"): \(activeSessionDisplayMessages.count) messages")
        }
    }

    // NEW: Handles selecting a new session when the active one is deleted.
    func handleActiveSessionDeletion() {
        print("DataManager: Handling active session deletion.")
        if let firstSessionId = chatSessions.first?.id {
            setActiveSession(id: firstSessionId)
            print("DataManager: Set new active session to first available: \(firstSessionId)")
        } else {
            // If no sessions left, create a new one via SessionManager
            print("DataManager: No sessions left, creating a new one.")
            sessionManager.createNewSession(activate: true)
        }
        // The setActiveSession call (or createNewSession) will trigger updateActiveSessionDisplayMessages via didSet.
    }

    // MARK: - Data Management Helpers

    /// Gets the path to the application's preferences file.
    private var preferencesFilePath: String? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        return libraryDirectory?.appendingPathComponent("Preferences/\(bundleId).plist").path
    }

    /// Calculates the size of the preferences file where data is stored.
    /// Returns the size in bytes, or nil if the file doesn't exist or size cannot be read.
    func getDataStoreSize() -> Int64? {
        guard let path = preferencesFilePath else { return nil }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64
        } catch {
            print("DataManager Error: Could not get size of preferences file at \(path): \(error)")
            return nil // File might not exist yet
        }
    }

    /// Deletes all chat session and folder data from UserDefaults.
    func deleteAllUserData() {
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: foldersKey)
        UserDefaults.standard.synchronize() // Ensure changes are written

        // Clear the in-memory data
        chatSessions = []
        folders = []
        activeSessionId = nil
        activeSessionDisplayMessages = []

        print("DataManager: Deleted all user sessions and folders from UserDefaults.")

        // Optionally, create a new initial session after deleting everything
        // sessionManager.createNewSession(activate: true)
    }
    
    // MARK: - Demo Data
    
    /// Loads pre-defined demo data, replacing any existing data.
    @MainActor // Ensure UI updates happen on the main thread
    func loadDemoData() {
        print("DataManager: Loading demo data...")

        // 1. Clear existing in-memory data
        folders = []
        chatSessions = []
        activeSessionId = nil
        activeSessionDisplayMessages = []

        // 2. Define Demo Folders
        let devFolderId = UUID()
        let generalFolderId = UUID()
        let demoFolders = [
            Folder(id: devFolderId, name: "Software Development", colorHex: "#34C759"), // Green
            Folder(id: generalFolderId, name: "General Knowledge", colorHex: "#007AFF") // Blue
        ]

        // 3. Define Demo Chat Sessions and Entries
        let demoSessions = [
            // --- Software Development Folder ---
            ChatSession(
                id: UUID(),
                title: "SwiftUI State Management",
                createdAt: Date().addingTimeInterval(-3600 * 24), // 1 day ago
                entries: [
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 24 + 10), question: "What are the main ways to manage state in SwiftUI?", answer: "SwiftUI offers several property wrappers for state management, including `@State` for local view state, `@Binding` for two-way connections, `@StateObject` and `@ObservedObject` for managing external reference type objects (like view models), and `@EnvironmentObject` for sharing data across the view hierarchy."),
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 24 + 20), question: "When should I use @StateObject vs @ObservedObject?", answer: "Use `@StateObject` when the view *owns* the object and is responsible for its creation and lifetime. Use `@ObservedObject` when the view *receives* an object that is owned and managed elsewhere (e.g., passed in the initializer or from an `@StateObject` in a parent view). `@StateObject` ensures the object persists across view updates, while `@ObservedObject` doesn't guarantee persistence if the owning view redraws."),
                ],
                folderId: devFolderId
            ),
            ChatSession(
                id: UUID(),
                title: "Async/Await in Swift",
                createdAt: Date().addingTimeInterval(-3600 * 12), // 12 hours ago
                entries: [
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 12 + 10), question: "Explain async/await in Swift.", answer: "Async/await is Swift's modern concurrency model introduced in Swift 5.5. It allows you to write asynchronous code that looks sequential, making it easier to read and reason about compared to traditional completion handlers or Combine. Functions marked with `async` can suspend execution without blocking the thread, and you use `await` to call them."),
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 12 + 20), question: "What is a Task?", answer: "A `Task` represents a unit of asynchronous work. You can create tasks to run asynchronous functions, manage their priority, check for cancellation, and group related operations. Structured concurrency uses tasks implicitly within async functions, but you can also create detached tasks or task groups explicitly."),
                ],
                isFavorite: true,
                folderId: devFolderId
            ),
            // --- General Knowledge Folder ---
            ChatSession(
                id: UUID(),
                title: "The Roman Empire",
                createdAt: Date().addingTimeInterval(-3600 * 48), // 2 days ago
                entries: [
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 48 + 10), question: "When did the Western Roman Empire fall?", answer: "The traditional date given for the fall of the Western Roman Empire is 476 AD, when the last Western Roman Emperor, Romulus Augustulus, was deposed by the Germanic chieftain Odoacer."),
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 48 + 20), question: "What was the Colosseum used for?", answer: "The Colosseum in Rome was primarily used for gladiatorial contests, mock sea battles, animal hunts, executions, re-enactments of famous battles, and dramas based on Classical mythology. It was a major public entertainment venue."),
                ],
                folderId: generalFolderId
            ),
            ChatSession(
                id: UUID(),
                title: "Basics of Quantum Physics",
                createdAt: Date().addingTimeInterval(-3600 * 6), // 6 hours ago
                entries: [
                    ChatEntry(timestamp: Date().addingTimeInterval(-3600 * 6 + 10), question: "What is quantum superposition?", answer: "Superposition is a fundamental principle of quantum mechanics stating that, much like waves in classical physics, any two (or more) quantum states can be added together ('superposed') and the result will be another valid quantum state. An object in superposition can be thought of as being in multiple states at once until it is measured."),
                ],
                colorHex: "#AF52DE", // Purple
                folderId: generalFolderId
            )
        ]

        // 4. Assign demo data to published properties
        self.folders = demoFolders
        self.chatSessions = demoSessions.sorted { $0.createdAt > $1.createdAt } // Keep sorted

        // 5. Persist the demo data
        saveFolders()
        saveSessions()

        // 6. Set active session (e.g., the first one)
        if let firstDemoSessionId = self.chatSessions.first?.id {
            setActiveSession(id: firstDemoSessionId)
            print("DataManager: Set active session to first demo session: \(firstDemoSessionId)")
        } else {
            print("DataManager Warning: No demo sessions created, cannot set active session.")
            // Optionally create a blank session if demo data failed somehow
            // sessionManager.createNewSession(activate: true)
        }
        // Note: updateActiveSessionDisplayMessages is called by setActiveSession's didSet

        print("DataManager: Demo data loaded and saved successfully. (\(self.folders.count) folders, \(self.chatSessions.count) sessions)")
    }
}