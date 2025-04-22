import SwiftUI

// Enum for folder actions (Moved outside the struct)
enum FolderActionType {
    case newRootFolder, newSubfolder, renameFolder
}

// MARK: - Sidebar Component (Refactored)
struct SidebarView: View {
    // MARK: - Bindings from Parent (e.g., ContentView)
    @Binding var selectedFilter: SidebarFilter // Passed down
    @Binding var showingEditAlert: Bool // Used by ListView, managed here
    @Binding var sessionToEdit: ChatSession? // Used by ListView, managed here
    @Binding var newSessionTitle: String // Used by ListView, managed here

    // MARK: - Environment
    @EnvironmentObject var dataManager: DataManager

    // MARK: - State Variables (Managed by SidebarView)
    @State private var selectedColorHexFilter: String? = nil // Passed down
    @State private var hoverId: String? = nil // Passed down to ListView
    @State private var swipeResetTrigger: Bool = false // Passed down
    @State private var showingSearchSheet = false // Passed down, sheet managed here

    // Folder Alert State (Managed here, triggered by ControlsView/ListView)
    @State private var showingFolderAlert: Bool = false
    @State private var folderAlertTitle: String = ""
    @State private var folderAlertMessage: String = ""
    @State private var folderAlertTextFieldLabel: String = ""
    @State private var folderNameInput: String = ""
    @State private var targetFolderIdForAction: UUID? = nil
    @State private var folderActionType: FolderActionType = .newRootFolder

    // Delete Folder Confirmation State (Managed here, triggered by ListView)
    @State private var showingDeleteFolderConfirm: Bool = false
    @State private var folderToDelete: Folder? = nil

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // --- Header --- (Using extracted view)
            SidebarHeaderView()

            Divider()

            // --- Filter Area --- (Using extracted view)
            SidebarFilterControlsView(
                selectedFilter: $selectedFilter,
                selectedColorHexFilter: $selectedColorHexFilter,
                showingSearchSheet: $showingSearchSheet,
                swipeResetTrigger: $swipeResetTrigger,
                onNewRootFolder: { setupFolderAlert(action: .newRootFolder) }, // Pass action closure
                onNewChat: { dataManager.sessionManager.createNewSession(activate: true) } // Pass action closure
            )
            // Note: EnvironmentObject for DataManager is implicitly available here

            // --- Content List --- (Using extracted view)
            SidebarListView(
                selectedFilter: $selectedFilter,
                selectedColorHexFilter: $selectedColorHexFilter,
                showingEditAlert: $showingEditAlert,
                sessionToEdit: $sessionToEdit,
                newSessionTitle: $newSessionTitle,
                hoverId: $hoverId,
                swipeResetTrigger: $swipeResetTrigger,
                showingDeleteFolderConfirm: $showingDeleteFolderConfirm,
                folderToDelete: $folderToDelete,
                setupFolderAlert: setupFolderAlert // Pass setup function directly
            )

            // --- Footer --- (Using extracted view)
            Divider()
            SidebarFooterView()
        }
        // --- Alerts and Dialogs (Managed by the container view) ---
        .alert(folderAlertTitle, isPresented: $showingFolderAlert) {
             TextField(folderAlertTextFieldLabel, text: $folderNameInput)
             Button("Save") {
                 Task { await handleFolderAction() }
             }
             Button("Cancel", role: .cancel) { }
        } message: { Text(folderAlertMessage) }
        .confirmationDialog(
            "Delete Folder '\(folderToDelete?.name ?? "")'",
            isPresented: $showingDeleteFolderConfirm,
            presenting: folderToDelete
        ) { folder in folderDeleteConfirmationActions(folder: folder) }
        message: { _ in Text("Deleting the folder cannot be undone. Choose how to handle its contents.") }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        // Sheet for the Search View
        .sheet(isPresented: $showingSearchSheet) {
            SearchView()
                .environmentObject(dataManager) // Pass DataManager to the sheet
        }
    }

    // MARK: - Helper Functions (Kept in SidebarView)

    // Helper to setup folder alert state (Called via closures/direct pass)
    private func setupFolderAlert(action: FolderActionType, folder: Folder? = nil) {
        folderActionType = action
        targetFolderIdForAction = nil // Reset target ID initially
        switch action {
        case .newRootFolder:
            folderAlertTitle = "New Folder"
            folderAlertMessage = "Enter a name for the new root folder."
            folderAlertTextFieldLabel = "Folder Name"
            folderNameInput = ""
        case .newSubfolder:
            guard let parentFolder = folder else { return }
            folderAlertTitle = "New Subfolder"
            folderAlertMessage = "Enter a name for the new subfolder inside '\(parentFolder.name)'."
            folderAlertTextFieldLabel = "Subfolder Name"
            folderNameInput = ""
            targetFolderIdForAction = parentFolder.id // Set parent
        case .renameFolder:
            guard let folderToRename = folder else { return }
            folderAlertTitle = "Rename Folder"
            folderAlertMessage = "Enter a new name for the folder '\(folderToRename.name)'."
            folderAlertTextFieldLabel = "New Name"
            folderNameInput = folderToRename.name // Pre-fill
            targetFolderIdForAction = folderToRename.id // Set target
        }
        showingFolderAlert = true
    }

    // Helper to handle folder alert save action
    private func handleFolderAction() async {
         switch folderActionType {
         case .newRootFolder:
             await MainActor.run { dataManager.folderManager.createFolder(name: folderNameInput, parentId: nil) }
         case .newSubfolder:
             await MainActor.run { dataManager.folderManager.createFolder(name: folderNameInput, parentId: targetFolderIdForAction) }
         case .renameFolder:
             if let folderId = targetFolderIdForAction {
                 await MainActor.run { dataManager.folderManager.renameFolder(withId: folderId, newName: folderNameInput) }
             }
         }
    }

    // Extracted Folder Delete Confirmation Actions (Used by confirmationDialog)
    @ViewBuilder
    private func folderDeleteConfirmationActions(folder: Folder) -> some View {
        Button("Delete Folder and All Contents", role: .destructive) {
             Task { await MainActor.run { dataManager.folderManager.deleteFolder(withId: folder.id, recursive: true) } }
        }
        Button("Delete Folder Only (Move Contents to Root)") {
             Task { await MainActor.run { dataManager.folderManager.deleteFolder(withId: folder.id, recursive: false) } }
        }
        Button("Cancel", role: .cancel) { }
    }
}

// MARK: - Previews (Update if necessary)
#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    @State static var filter: SidebarFilter = .all
    @State static var showingEdit = false
    @State static var sessionToEdit: ChatSession? = nil
    @State static var newTitle = ""

    static var previews: some View {
        SidebarView(
            selectedFilter: $filter,
            showingEditAlert: $showingEdit,
            sessionToEdit: $sessionToEdit,
            newSessionTitle: $newTitle
        )
        .environmentObject(DataManager.preview) // Use preview DataManager
        .frame(width: 280) // Set typical sidebar width
    }
}
#endif

