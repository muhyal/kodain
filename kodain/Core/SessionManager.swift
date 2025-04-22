// SessionManager.swift
import Foundation
import SwiftUI // For UUID etc.

@MainActor // UI ile ilgili @Published değişkenleri değiştireceği için
class SessionManager {
    // DataManager'a zayıf olmayan bir referans tutuyoruz.
    // SessionManager'ın ömrü DataManager'a bağlı olacak.
    private var dataManager: DataManager

    init(dataManager: DataManager) {
        self.dataManager = dataManager
        print("SessionManager initialized.")
    }

    // --- DataManager'dan Taşınan Metotlar ---

    /// Creates a new, empty chat session.
    func createNewSession(activate: Bool = true) {
        dataManager.saveSessions() // Save before potentially changing active session
        let newSession = ChatSession(title: "New Chat \(dataManager.chatSessions.count + 1)")
        dataManager.chatSessions.append(newSession)
        print("SessionManager: Created new session: \(newSession.id) - \(newSession.title)")
        if activate {
            // Directly call DataManager's method to handle active session logic
            dataManager.setActiveSession(id: newSession.id)
        }
        dataManager.saveSessions() // Save again after adding
    }

    /// Deletes a session by its ID.
    func deleteSession(withId id: UUID) {
        guard let index = dataManager.chatSessions.firstIndex(where: { $0.id == id }) else {
             print("SessionManager Error: Session ID \(id) not found for deletion.")
             return
         }
        let deletedSession = dataManager.chatSessions.remove(at: index)
        print("SessionManager: Deleted session: \(deletedSession.id) - \(deletedSession.title)")

        // If the deleted session was the active one, DataManager needs to handle it.
        if dataManager.activeSessionId == id {
            print("SessionManager: Active session was deleted. Notifying DataManager to select a new one.")
            // Let DataManager decide the new active session
            dataManager.handleActiveSessionDeletion()
        }
        dataManager.saveSessions()
        // No need to call updateActiveSessionDisplayMessages here,
        // DataManager's activeSessionId handling will trigger it.
    }

    /// Toggles the favorite status of a session.
    func toggleFavorite(withId id: UUID) {
        guard let index = dataManager.chatSessions.firstIndex(where: { $0.id == id }) else {
             print("SessionManager Error: Session ID \(id) not found for toggling favorite.")
             return
         }
        // Use copy-modify-replace for struct arrays
        var sessionToUpdate = dataManager.chatSessions[index]
        sessionToUpdate.isFavorite.toggle()
        dataManager.chatSessions[index] = sessionToUpdate
        print("SessionManager: Toggled favorite for session: \(id). New status: \(dataManager.chatSessions[index].isFavorite)")
        dataManager.saveSessions()
    }

    /// Updates the title of a session.
    func updateTitle(withId id: UUID, newTitle: String) {
        guard let index = dataManager.chatSessions.firstIndex(where: { $0.id == id }) else {
             print("SessionManager Error: Session ID \(id) not found for updating title.")
             return
         }
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
             print("SessionManager Error: New title cannot be empty.")
             return
         } // Don't allow empty titles

        // Use copy-modify-replace
        var sessionToUpdate = dataManager.chatSessions[index]
        sessionToUpdate.title = trimmedTitle
        dataManager.chatSessions[index] = sessionToUpdate
        print("SessionManager: Updated title for session: \(id) to '\(trimmedTitle)'")
        dataManager.saveSessions()
    }

    /// Moves a session to a different folder (or root if newParentId is nil).
    func moveSessionToFolder(sessionId: UUID, newParentId: UUID?) {
        guard let sessionIndex = dataManager.chatSessions.firstIndex(where: { $0.id == sessionId }) else {
             print("SessionManager Error: Session ID \(sessionId) not found for moving.")
             return
         }
        // Allow moving to root (nil) or an existing folder
        if let parentId = newParentId, !dataManager.folders.contains(where: { $0.id == parentId }) {
            print("SessionManager Error: Target folder ID \(parentId) not found.")
            return
        }

        // Use copy-modify-replace
        var sessionToUpdate = dataManager.chatSessions[sessionIndex]
        sessionToUpdate.folderId = newParentId
        dataManager.chatSessions[sessionIndex] = sessionToUpdate

        print("SessionManager: Moved session \(sessionId) to folder \(newParentId?.uuidString ?? "Root")")
        dataManager.saveSessions()
    }

    /// Updates the color hex string for a specific session.
    func updateSessionColor(withId id: UUID, colorHex: String?) {
        guard let index = dataManager.chatSessions.firstIndex(where: { $0.id == id }) else {
             print("SessionManager Error: Session ID \(id) not found for updating color.")
             return
         }
        // Use copy-modify-replace
        var sessionToUpdate = dataManager.chatSessions[index]
        sessionToUpdate.colorHex = colorHex
        dataManager.chatSessions[index] = sessionToUpdate
        print("SessionManager: Updated color for session \(id) to \(colorHex ?? "None")")
        dataManager.saveSessions()
    }
} 