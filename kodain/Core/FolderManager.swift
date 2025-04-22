// FolderManager.swift
import Foundation
import SwiftUI // For UUID etc.

@MainActor // UI ile ilgili @Published değişkenleri değiştireceği için
class FolderManager {
    // DataManager'a referans
    private var dataManager: DataManager

    init(dataManager: DataManager) {
        self.dataManager = dataManager
        print("FolderManager initialized.")
    }

    // --- DataManager'dan Taşınan Metotlar --- 

    func createFolder(name: String, parentId: UUID? = nil, colorHex: String? = nil) {
        print("FolderManager.createFolder called with name: '\(name)', parentId: \(parentId?.uuidString ?? "nil")")
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { 
            print("FolderManager.createFolder: Error - Folder name cannot be empty.")
            return 
        }
        
        let newFolder = Folder(name: trimmedName, parentId: parentId, colorHex: colorHex)
        print("FolderManager.createFolder: Created Folder object: \(newFolder.id)")
        dataManager.folders.append(newFolder)
        print("FolderManager.createFolder: Appended to folders array. New count: \(dataManager.folders.count)")
        dataManager.saveFolders()
    }

    func renameFolder(withId id: UUID, newName: String) {
        guard let index = dataManager.folders.firstIndex(where: { $0.id == id }) else { 
            print("FolderManager Error: Folder ID \(id) not found for renaming.")
            return
        }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { 
            print("FolderManager Error: New folder name cannot be empty.")
            return
        }
        dataManager.folders[index].name = trimmedName
        print("FolderManager: Renamed folder \(id) to '\(trimmedName)'")
        dataManager.saveFolders()
    }

    func deleteFolder(withId id: UUID, recursive: Bool) {
        guard let index = dataManager.folders.firstIndex(where: { $0.id == id }) else { 
            print("FolderManager Error: Folder ID \(id) not found for deletion.")
            return
        }
        
        let deletedFolder = dataManager.folders.remove(at: index)
        print("FolderManager: Deleted folder '\(deletedFolder.name)' (ID: \(id))")
        
        // Find all direct child sessions and folders using DataManager's access
        let childSessionIds = dataManager.chatSessions.filter { $0.folderId == id }.map { $0.id }
        // Need to be careful here - use the list BEFORE removal for finding children
        let childFolderIds = dataManager.folders.filter { $0.parentId == id }.map { $0.id } 

        if recursive {
            print("FolderManager: Recursively deleting contents of folder \(id)")
            // Recursively delete child folders (Call self)
            for childFolderId in childFolderIds {
                deleteFolder(withId: childFolderId, recursive: true) // Recursive call to self
            }
            // Delete child sessions using SessionManager
            for childSessionId in childSessionIds {
                dataManager.sessionManager.deleteSession(withId: childSessionId)
            }
        } else {
            print("FolderManager: Moving contents of folder \(id) to root")
            // Move child folders to root (Call self)
            for childFolderId in childFolderIds {
                moveFolder(folderId: childFolderId, newParentId: nil)
            }
            // Move child sessions to root using SessionManager
            for childSessionId in childSessionIds {
                dataManager.sessionManager.moveSessionToFolder(sessionId: childSessionId, newParentId: nil)
            }
        }
        
        dataManager.saveFolders() // Save folder list changes itself
        // Note: Child operations (deleteSession, moveFolder, moveSessionToFolder) should handle their own saves.
    }

    func moveFolder(folderId: UUID, newParentId: UUID?) {
        guard let folderIndex = dataManager.folders.firstIndex(where: { $0.id == folderId }) else { 
            print("FolderManager Error: Folder ID \(folderId) not found for moving.")
            return
        }
        // Prevent moving a folder into itself 
        if folderId == newParentId { 
            print("FolderManager Error: Cannot move a folder into itself.")
            return
        } 
        // Prevent moving a folder into one of its own descendants
        if let parentId = newParentId, dataManager.isDescendant(folderId: parentId, of: folderId) {
             print("FolderManager Error: Cannot move a folder into one of its descendants.")
             return
        }
        
        // Allow moving to root (nil) or an existing folder
        if let targetParentId = newParentId, !dataManager.folders.contains(where: { $0.id == targetParentId }) {
            print("FolderManager Error: Target parent folder ID \(targetParentId) not found.")
            return
        }
        dataManager.folders[folderIndex].parentId = newParentId
        print("FolderManager: Moved folder \(folderId) to parent \(newParentId?.uuidString ?? "Root")")
        dataManager.saveFolders()
    }

    func updateFolderColor(withId id: UUID, colorHex: String?) {
        guard let index = dataManager.folders.firstIndex(where: { $0.id == id }) else { 
            print("FolderManager Error: Folder ID \(id) not found for updating color.")
            return
        }
        // Use copy-modify-replace for struct arrays if needed, but direct assignment works for class properties
        // Since folders array holds Folder structs, direct modification is fine.
        dataManager.folders[index].colorHex = colorHex
        print("FolderManager: Updated color for folder \(id) to \(colorHex ?? "None")")
        dataManager.saveFolders()
    }
} 