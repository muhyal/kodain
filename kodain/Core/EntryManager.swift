// EntryManager.swift
import Foundation
import SwiftUI // For UUID etc.
import GoogleGenerativeAI // For GenerationResult

@MainActor // UI ile ilgili @Published değişkenleri değiştireceği için
class EntryManager {
    // DataManager'a referans
    private var dataManager: DataManager

    init(dataManager: DataManager) {
        self.dataManager = dataManager
        print("EntryManager initialized.")
    }

    // --- DataManager'dan Taşınan Metotlar --- 

    /// Adds a new entry (question/answer/metadata) to the currently active session.
    func addEntryToActiveSession(question: String, imageData: Data? = nil, generationResult: GenerationResult) {
        guard let index = dataManager.activeSessionIndex else {
            print("EntryManager Error: Cannot add entry, no active session selected.")
            return
        }

        let newEntry = ChatEntry(
            question: question, 
            answer: generationResult.text, 
            screenshotData: imageData,
            wordCount: generationResult.wordCount,
            promptTokenCount: generationResult.promptTokenCount,
            candidatesTokenCount: generationResult.candidatesTokenCount,
            totalTokenCount: generationResult.totalTokenCount,
            responseTimeMs: generationResult.responseTimeMs,
            modelName: generationResult.modelName
        )
        
        // Modify copy and replace
        var sessionToUpdate = dataManager.chatSessions[index]
        sessionToUpdate.entries.append(newEntry)
        dataManager.chatSessions[index] = sessionToUpdate

        // Update session title if it's the first entry and using default title
        if dataManager.chatSessions[index].entries.count == 1 && dataManager.chatSessions[index].title.starts(with: "New Chat") {
            // Use SessionManager to update title
            dataManager.sessionManager.updateTitle(withId: dataManager.chatSessions[index].id, newTitle: ChatSession.generateTitle(from: question))
        }

        print("EntryManager: Added entry to session: \(dataManager.activeSessionId?.uuidString ?? "None")")
        dataManager.saveSessions() 
        // Update display messages using the updated entry list
        dataManager.updateActiveSessionDisplayMessages(using: sessionToUpdate.entries)
    }

    /// Clears all entries from a specific session.
    func clearEntries(sessionId: UUID) {
        guard let index = dataManager.chatSessions.firstIndex(where: { $0.id == sessionId }) else {
            print("EntryManager Error: Cannot clear entries, session ID \(sessionId) not found.")
            return
        }
        
        guard !dataManager.chatSessions[index].entries.isEmpty else {
            print("EntryManager: No entries to clear in session \(sessionId).")
            return
        }
        
        // Modify copy and replace
        var sessionToUpdate = dataManager.chatSessions[index]
        sessionToUpdate.entries.removeAll() 
        dataManager.chatSessions[index] = sessionToUpdate 

        print("EntryManager: Cleared all entries for session \(sessionId).")
        
        dataManager.saveSessions()
        // Update display messages using the (now empty) updated entry list
        dataManager.updateActiveSessionDisplayMessages(using: sessionToUpdate.entries)
    }

    /// Deletes a specific entry from the active session.
    func deleteEntry(entryId: UUID) {
        guard let sessionIndex = dataManager.activeSessionIndex else {
            print("EntryManager Error: Cannot delete entry, no active session selected.")
            return
        }
        
        guard let entryIndex = dataManager.chatSessions[sessionIndex].entries.firstIndex(where: { $0.id == entryId }) else {
             print("EntryManager Error: Cannot find entry with ID \(entryId) in session \(dataManager.activeSessionId?.uuidString ?? "None")")
             return
        }
        
        // Modify copy and replace
        var sessionToUpdate = dataManager.chatSessions[sessionIndex]
        let deletedEntry = sessionToUpdate.entries.remove(at: entryIndex) 
        dataManager.chatSessions[sessionIndex] = sessionToUpdate

        print("EntryManager: Deleted entry \(deletedEntry.id) from session \(dataManager.activeSessionId?.uuidString ?? "None")")
        
        dataManager.saveSessions()
        // Update display messages using the updated entry list
        dataManager.updateActiveSessionDisplayMessages(using: sessionToUpdate.entries)
    }
} 