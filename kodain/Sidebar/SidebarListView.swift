import SwiftUI
import AppKit // Needed for NSPasteboard

// Typealias for the setupFolderAlert action closure to improve readability
typealias SetupFolderAlertAction = (FolderActionType, Folder?) -> Void // Updated to use top-level enum


// MARK: - Sidebar List View Component
struct SidebarListView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.colorScheme) var colorScheme

    // Bindings passed from SidebarView
    @Binding var selectedFilter: SidebarFilter
    @Binding var selectedColorHexFilter: String?
    @Binding var showingEditAlert: Bool
    @Binding var sessionToEdit: ChatSession?
    @Binding var newSessionTitle: String
    @Binding var hoverId: String?
    @Binding var swipeResetTrigger: Bool
    @Binding var showingDeleteFolderConfirm: Bool
    @Binding var folderToDelete: Folder?

    // Action passed from SidebarView
    var setupFolderAlert: SetupFolderAlertAction

    // Internal state for row height
    @State private var currentRowHeight: CGFloat = 44 // Default height

    // Constants needed within this view
    private let availableColors: [String?] = [
        nil, "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE", "#8E8E93"
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                outlineGroupContent(parentId: nil, level: 0)
            }
            .padding(.horizontal, 5)
        }
        .background(.clear)
        .scrollContentBackground(.hidden)
        .padding(.top, 0) // Keep padding consistent if needed
    }

    // Recursive View Builder for Outline Content
    @ViewBuilder
    private func outlineGroupContent(parentId: UUID?, level: Int) -> some View {
        // Note: VStack removed here as it's handled by LazyVStack in body
        // and the section helpers return ForEach directly. If spacing/alignment
        // is needed *between* sections, reintroduce VStack.
        folderSectionContent(parentId: parentId, level: level)
        sessionSectionContent(parentId: parentId, level: level)
    }

    // MARK: - Section Content Helpers

    @ViewBuilder
    private func folderSectionContent(parentId: UUID?, level: Int) -> some View {
        let indent = CGFloat(level * 15)
        let foldersToShow = dataManager.filteredFolders(parentId: parentId, currentFilter: selectedFilter, colorHexFilter: selectedColorHexFilter)

        // Return ForEach directly for LazyVStack
        ForEach(foldersToShow) { folder in
            FolderRowView(
                folder: folder,
                hoverId: $hoverId,
                indent: indent,
                currentRowHeight: $currentRowHeight,
                swipeResetTrigger: $swipeResetTrigger,
                folderContextMenu: { folderContextMenu(for: folder) },
                folderLeadingSwipeActions: { folderLeadingSwipeActions(for: folder) },
                folderTrailingSwipeActions: { folderTrailingSwipeActions(for: folder) },
                // Pass recursive content correctly, needs AnyView for type erasure in DisclosureGroup
                outlineGroupContent: { AnyView(outlineGroupContent(parentId: folder.id, level: level + 1)) }
            )
        }
    }

    @ViewBuilder
    private func sessionSectionContent(parentId: UUID?, level: Int) -> some View {
        let indent = CGFloat(level * 15)
        let sessionsToShow = dataManager.filteredSessions(parentId: parentId, currentFilter: selectedFilter, colorHexFilter: selectedColorHexFilter)

        // Return ForEach directly for LazyVStack
        ForEach(sessionsToShow) { session in
             SessionRowView(
                 session: session,
                 isSelected: dataManager.activeSessionId == session.id,
                 hoverId: $hoverId,
                 indent: indent,
                 currentRowHeight: $currentRowHeight,
                 swipeResetTrigger: $swipeResetTrigger,
                 dataManager: dataManager,
                 sessionContextMenu: { sessionContextMenu(for: session) }, // Pass context menu content
                 sessionLeadingSwipeActions: { sessionLeadingSwipeActions(for: session) }, // Pass swipe actions
                 sessionTrailingSwipeActions: { sessionTrailingSwipeActions(for: session) } // Pass swipe actions
             )
        }
    }

    // MARK: - Session Row View

    private struct SessionRowView<ContextMenu: View>: View {
        let session: ChatSession
        let isSelected: Bool
        @Binding var hoverId: String?
        let indent: CGFloat
        @Binding var currentRowHeight: CGFloat
        @Binding var swipeResetTrigger: Bool
        @ObservedObject var dataManager: DataManager

        @ViewBuilder var sessionContextMenu: () -> ContextMenu
        var sessionLeadingSwipeActions: () -> [SwipeAction]
        var sessionTrailingSwipeActions: () -> [SwipeAction]

        private var sessionIdString: String { "session-\(session.id.uuidString)" }
        private var isHovering: Bool { hoverId == sessionIdString }

        var body: some View {
            SessionRow(
                session: session,
                isSelected: isSelected,
                isHovering: isHovering
            )
                .padding(.leading, indent + 5) // Indent sessions slightly more
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.blue.opacity(0.2) : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
                )
                .contentShape(Rectangle())
                .background( // Background for preference key reading
                    GeometryReader { proxy in
                        Color.clear.preference(key: RowHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
               .onPreferenceChange(RowHeightPreferenceKey.self) { height in
                   if height > 0 && self.currentRowHeight != height {
                        self.currentRowHeight = height
                   }
                }
                .contextMenu { sessionContextMenu() } // Call closure directly
                .onTapGesture {
                     dataManager.activeSessionId = session.id
                     swipeResetTrigger.toggle() // Reset other swipes when selecting a new row
                }
                .onHover { hovering in hoverId = hovering ? sessionIdString : nil }
                .swipeActions(
                    leading: sessionLeadingSwipeActions(), // Call closure directly
                    trailing: sessionTrailingSwipeActions(), // Call closure directly
                    allowsFullSwipe: true,
                    rowHeight: currentRowHeight,
                    resetTrigger: $swipeResetTrigger
                )
        }
    }

    // MARK: - Folder Row View

    // ContextMenu and Content need to conform to View
    private struct FolderRowView<ContextMenu: View, Content: View>: View {
        let folder: Folder
        @Binding var hoverId: String?
        let indent: CGFloat
        @Binding var currentRowHeight: CGFloat
        @Binding var swipeResetTrigger: Bool

        @ViewBuilder var folderContextMenu: () -> ContextMenu
        var folderLeadingSwipeActions: () -> [SwipeAction]
        var folderTrailingSwipeActions: () -> [SwipeAction]
        @ViewBuilder var outlineGroupContent: () -> Content // This is the DisclosureGroup content

        private var folderIdString: String { "folder-\(folder.id.uuidString)" }
        private var isHovering: Bool { hoverId == folderIdString }

        var body: some View {
            DisclosureGroup {
                outlineGroupContent() // The recursive part goes here
            } label: {
                // The FolderRow itself is the label
                FolderRow(folder: folder, isHovering: isHovering)
                    .padding(.leading, indent)
                    .contentShape(Rectangle()) // Make the whole row tappable for disclosure
                    .background( // Background for preference key reading
                        GeometryReader { proxy in
                            Color.clear.preference(key: RowHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
            }
            .accentColor(.secondary) // Style disclosure indicator
            .onPreferenceChange(RowHeightPreferenceKey.self) { height in
                if height > 0 && self.currentRowHeight != height {
                     self.currentRowHeight = height
                }
            }
            .contextMenu { folderContextMenu() } // Call closure directly
            .onHover { hovering in hoverId = hovering ? folderIdString : nil }
            .swipeActions(
                leading: folderLeadingSwipeActions(), // Call closure directly
                trailing: folderTrailingSwipeActions(), // Call closure directly
                allowsFullSwipe: true,
                rowHeight: currentRowHeight,
                resetTrigger: $swipeResetTrigger
            )
        }
    }


    // MARK: - Context Menus

    @ViewBuilder
    private func sessionContextMenu(for session: ChatSession) -> some View {
        Button { // Edit Title
            sessionToEdit = session
            newSessionTitle = session.title
            showingEditAlert = true // Trigger alert in parent view
        } label: { Label("Edit Title", systemImage: "pencil") }

        Menu { // Move To Folder
            sessionMoveToFolderMenuContent(for: session)
        } label: { Label("Move To...", systemImage: "folder") }

        Menu { // Set Color
             colorSubMenuContent(for: session)
         } label: { Label("Set Color", systemImage: "paintpalette") }

        Button { // Toggle Favorite
            Task { await MainActor.run { dataManager.sessionManager.toggleFavorite(withId: session.id) } }
        } label: { Label(session.isFavorite ? "Unfavorite" : "Favorite", systemImage: session.isFavorite ? "star.slash.fill" : "star.fill") }

        Button { // Copy Title
             let pasteboard = NSPasteboard.general
             pasteboard.clearContents()
             pasteboard.setString(session.title, forType: .string)
        } label: { Label("Copy Title", systemImage: "doc.on.doc") }

        Divider()
        Button(role: .destructive) { // Delete Chat
            Task { await MainActor.run { dataManager.sessionManager.deleteSession(withId: session.id) } }
        } label: { Label("Delete Chat", systemImage: "trash.fill") }
    }

    @ViewBuilder
    private func folderContextMenu(for folder: Folder) -> some View {
        Button { // Rename Folder
            setupFolderAlert(.renameFolder, folder) // Use passed-in closure
        } label: { Label("Rename", systemImage: "pencil") }

        Button { // New Subfolder
            setupFolderAlert(.newSubfolder, folder) // Use passed-in closure
        } label: { Label("New Subfolder", systemImage: "folder.badge.plus") }

        Menu { // Move Folder
            folderMoveToFolderMenuContent(for: folder)
        } label: { Label("Move To...", systemImage: "folder") }

        Menu { // Set Color
            colorSubMenuContent(for: folder)
        } label: { Label("Set Color", systemImage: "paintpalette") }

        Divider()
        Button(role: .destructive) { // Delete Folder
            folderToDelete = folder // Set state in parent
            showingDeleteFolderConfirm = true // Trigger dialog in parent
        } label: { Label("Delete Folder...", systemImage: "trash.fill") }
    }

    @ViewBuilder
    private func colorSubMenuContent(for item: any Identifiable & HasColor) -> some View {
        // Assume colorFromHex and colorName are globally available or defined here/imported
        let colorsForMenu = availableColors
        Button { // Set color to None
             Task {
                 await MainActor.run {
                     if let s = item as? ChatSession { dataManager.sessionManager.updateSessionColor(withId: s.id, colorHex: nil) }
                     else if let f = item as? Folder { dataManager.folderManager.updateFolderColor(withId: f.id, colorHex: nil) }
                 }
                 swipeResetTrigger.toggle()
             }
        } label: { HStack { Image(systemName: "circle.slash"); Text("None"); Spacer(); if item.colorHex == nil { Image(systemName: "checkmark") } } }
        Divider()
        ForEach(colorsForMenu.compactMap { $0 }, id: \.self) { colorHexValue in
            Button {
                 Task {
                     await MainActor.run {
                         if let s = item as? ChatSession { dataManager.sessionManager.updateSessionColor(withId: s.id, colorHex: colorHexValue) }
                         else if let f = item as? Folder { dataManager.folderManager.updateFolderColor(withId: f.id, colorHex: colorHexValue) }
                     }
                     swipeResetTrigger.toggle()
                 }
            } label: {
                HStack {
                    // Ensure colorFromHex and colorName are accessible
                    Circle().fill(colorFromHex(colorHexValue)).frame(width: 12, height: 12)
                    Text(colorName(from: colorHexValue))
                    Spacer()
                    if item.colorHex == colorHexValue { Image(systemName: "checkmark") }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionMoveToFolderMenuContent(for session: ChatSession) -> some View {
        Button { // Move to Root
            Task {
                 await MainActor.run { dataManager.sessionManager.moveSessionToFolder(sessionId: session.id, newParentId: nil) }
                 swipeResetTrigger.toggle()
            }
        } label: {
            Label("Root Level", systemImage: session.folderId == nil ? "checkmark.circle.fill" : "circle")
        }
        Divider()
        ForEach(dataManager.folders.sorted { $0.name < $1.name }) { folder in
            Button { // Move to specific folder
                Task {
                     await MainActor.run { dataManager.sessionManager.moveSessionToFolder(sessionId: session.id, newParentId: folder.id) }
                     swipeResetTrigger.toggle()
                }
            } label: {
                Label { Text(folder.name).lineLimit(1) }
                icon: { Image(systemName: session.folderId == folder.id ? "checkmark" : "folder") }
            }
        }
    }

    @ViewBuilder
    private func folderMoveToFolderMenuContent(for folder: Folder) -> some View {
        // Option to move to Root
        Button {
            Task {
                await MainActor.run { dataManager.folderManager.moveFolder(folderId: folder.id, newParentId: nil) }
                swipeResetTrigger.toggle()
            }
        } label: {
            Label("Root Level", systemImage: folder.parentId == nil ? "checkmark.circle.fill" : "circle")
        }

        Divider()

        // List available folders (excluding self and descendants)
        ForEach(dataManager.folders.filter { $0.id != folder.id && !dataManager.isDescendant(folderId: $0.id, of: folder.id) }.sorted { $0.name < $1.name }) { potentialParent in
            Button {
                Task {
                    await MainActor.run { dataManager.folderManager.moveFolder(folderId: folder.id, newParentId: potentialParent.id) }
                    swipeResetTrigger.toggle()
                }
            } label: {
                Label { Text(potentialParent.name) }
                icon: { Image(systemName: folder.parentId == potentialParent.id ? "checkmark" : "folder") }
            }
        }
    }


    // MARK: - Swipe Actions

    // Leading (Right Swipe) Actions for Sessions
    private func sessionLeadingSwipeActions(for session: ChatSession) -> [SwipeAction] {
        // Remove the favorite action from here
        return [] // Return an empty array, or other actions if needed later
    }

    // Trailing (Left Swipe) Actions for Sessions
    private func sessionTrailingSwipeActions(for session: ChatSession) -> [SwipeAction] {
        return [
            SwipeAction(
                tint: Color.red,
                icon: "trash.fill", // Use icon
                action: {
                    Task { await MainActor.run { dataManager.sessionManager.deleteSession(withId: session.id) } }
                    // Consider adding swipeResetTrigger.toggle() if needed after action
                }
            ),
            SwipeAction(
                tint: Color.yellow,
                icon: session.isFavorite ? "star.slash.fill" : "star.fill", // Use icon
                action: {
                    Task { await MainActor.run { dataManager.sessionManager.toggleFavorite(withId: session.id) } }
                    // Consider adding swipeResetTrigger.toggle() if needed after action
                }
            )
        ]
    }

    // Leading (Right Swipe) Actions for Folders
    private func folderLeadingSwipeActions(for folder: Folder) -> [SwipeAction] {
        // Example: Add folder-specific leading actions if needed
        return []
    }

    // Trailing (Left Swipe) Actions for Folders
    private func folderTrailingSwipeActions(for folder: Folder) -> [SwipeAction] {
        return [
            SwipeAction(
                tint: Color.red,
                icon: "trash.fill", // Use icon
                action: {
                    folderToDelete = folder
                    showingDeleteFolderConfirm = true // Trigger confirmation
                    // Consider adding swipeResetTrigger.toggle() here or after confirmation
                }
            ),
             SwipeAction(
                 tint: Color.blue,
                 icon: "pencil", // Use icon
                 action: {
                     setupFolderAlert(.renameFolder, folder)
                     // Consider adding swipeResetTrigger.toggle() if needed after action
                 }
             )
        ]
    }

    // MARK: - Utility Functions

    private func colorForHex(_ hex: String?) -> Color {
        guard let hex = hex else { return .clear } // Or a default color
        return Color(hex) ?? .gray // Remove 'hex:' label
    }
}

// MARK: - Previews (Ensure DataManager.preview and helpers are set up)

#if DEBUG
struct SidebarListView_Previews: PreviewProvider {
    // Make sure DataManager.preview provides sample data including folders and sessions
    // with and without parentIds for testing the hierarchy.
    static let previewDataManager = DataManager.preview

    @State static var selectedFilter: SidebarFilter = .all
    @State static var selectedColor: String? = nil
    @State static var showingEdit = false
    @State static var sessionToEdit: ChatSession? = previewDataManager.chatSessions.first
    @State static var newTitle = ""
    @State static var hover: String? = nil
    @State static var swipe = false
    @State static var showingDeleteConfirm = false
    @State static var folderToDelete: Folder? = nil

    static func dummySetupFolderAlert(action: FolderActionType, folder: Folder?) {
        print("Preview: Setup Folder Alert: \(action), Folder: \(folder?.name ?? "nil")")
    }

    static var previews: some View {
        // Embed in a NavigationView or similar if Sidebar relies on it
        NavigationView {
            SidebarListView(
                selectedFilter: $selectedFilter,
                selectedColorHexFilter: $selectedColor,
                showingEditAlert: $showingEdit,
                sessionToEdit: $sessionToEdit,
                newSessionTitle: $newTitle,
                hoverId: $hover,
                swipeResetTrigger: $swipe,
                showingDeleteFolderConfirm: $showingDeleteConfirm,
                folderToDelete: $folderToDelete,
                setupFolderAlert: dummySetupFolderAlert
            )
            .environmentObject(previewDataManager) // Use the static preview manager
            .frame(width: 250, height: 600) // Example frame
            .listStyle(.sidebar) // Apply sidebar list style if appropriate
        }
        // Add previews for different states (e.g., dark mode, specific filter)
        NavigationView {
            SidebarListView(
                selectedFilter: .constant(.favorites), // Example: Show only favorites
                selectedColorHexFilter: $selectedColor,
                showingEditAlert: $showingEdit,
                sessionToEdit: $sessionToEdit,
                newSessionTitle: $newTitle,
                hoverId: $hover,
                swipeResetTrigger: $swipe,
                showingDeleteFolderConfirm: $showingDeleteConfirm,
                folderToDelete: $folderToDelete,
                setupFolderAlert: dummySetupFolderAlert
            )
            .environmentObject(previewDataManager)
            .frame(width: 250, height: 600)
            .preferredColorScheme(.dark) // Dark mode preview
            .previewDisplayName("Favorites (Dark)")
        }
    }
}

#endif // DEBUG
