import SwiftUI

struct SearchView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss // To close the sheet

    @State private var searchText = ""
    // State to hold combined search results (Folders, Sessions, potentially Entries later)
    // Define a simple SearchResult struct or enum to hold different types if needed
    // For now, let's just store sessions as a placeholder
    @State private var searchResults: [SearchResult] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header with Search Field and Done Button
            HStack {
                TextField("Search Folders, Chats, Content...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading)
                    .onChange(of: searchText) { oldValue, newValue in
                        performSearch(query: newValue)
                    }

                Button("Done") {
                    dismiss() // Close the sheet
                }
                .padding(.trailing)
                .keyboardShortcut(.defaultAction) // Allows Enter key to dismiss
            }
            .padding(.top)
            .padding(.bottom, 8)

            Divider()

            // Results List
            if !searchText.isEmpty && searchResults.isEmpty {
                 // Show 'No results' message if search text exists but results are empty
                 ContentUnavailableView.search(text: searchText)
            } else if !searchResults.isEmpty {
                 // Show results if available
                List(searchResults) { result in
                    // Determine row content based on result type
                    Button {
                        handleResultSelection(result)
                    } label: {
                        searchResultRow(result: result)
                    }
                    .buttonStyle(.plain) // Use plain button style for List rows
                }
                .listStyle(.plain)
            } else {
                 // Show a generic prompt or recent searches when search text is empty
                 ContentUnavailableView(
                     "Search Everything",
                     systemImage: "magnifyingglass",
                     description: Text("Find folders, chat titles, or content across all your conversations.")
                 )
            }
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 300, idealHeight: 450) // Set sheet size
        .onAppear {
            // Optional: Perform an initial search or load recents when sheet appears
            // performSearch(query: searchText)
        }
    }

    // Placeholder search function - Needs actual DataManager integration
    private func performSearch(query: String) {
        // TODO: Replace with call to DataManager.searchEverything(query: query)
        //       This function needs to be created in DataManager and should return
        //       a unified list of results (e.g., an enum or protocol).
        print("Performing search for: \\(query)") // Debug print

        if query.isEmpty {
             searchResults = []
             return
        }

        // Use the new DataManager function
        searchResults = dataManager.searchEverything(query: query)
        // Sorting is now handled within searchEverything

        print("Found \\(searchResults.count) results")
    }

    // MARK: - Helper Views and Functions

    /// Creates the appropriate row view for a given search result.
    @ViewBuilder
    private func searchResultRow(result: SearchResult) -> some View {
        HStack {
            // Icon based on type
            Image(systemName: result.type == .folder ? "folder.fill" : "message.fill")
                .foregroundColor(result.colorHex != nil ? colorFromHex(result.colorHex!) : .secondary)

            VStack(alignment: .leading) {
                Text(result.name).lineLimit(1)
                // Type indicator
                Text(result.type == .folder ? "Folder" : "Chat Session")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    /// Handles the action when a search result row is tapped.
    private func handleResultSelection(_ result: SearchResult) {
        switch result.type {
        case .chatSession:
            dataManager.setActiveSession(id: result.id)
            dismiss() // Close the sheet after selection
        case .folder:
            // Action for folder selection:
            // Option 1: Activate the *first* chat within that folder?
             if let firstSessionId = dataManager.sessions(in: result.id).first?.id {
                 dataManager.setActiveSession(id: firstSessionId)
                 dismiss()
             } else {
                 print("Selected folder is empty or doesn't exist: \(result.name)")
                 // Maybe just dismiss, or show an alert?
                 dismiss()
             }
            // Option 2: Expand the folder in the main sidebar? (More complex)
            // Option 3: Just dismiss the sheet?
            // dismiss()
        }
    }
}

// Helper function (ensure it's accessible or move if needed)
func colorFromHex(_ hex: String) -> Color {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
        (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
        (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
        (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
        (a, r, g, b) = (255, 0, 0, 0) // Default color (black) for invalid hex
    }
    return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
}


struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        // Setup preview data *before* creating the view
        let previewDataManager: DataManager = {
            let manager = DataManager()
            let session1 = ChatSession(title: "SwiftUI Basics", createdAt: Date(), entries: [], folderId: nil)
            let session2 = ChatSession(title: "CoreData Integration", createdAt: Date().addingTimeInterval(-3600), entries: [], folderId: nil)
            manager.chatSessions = [session1, session2]
            return manager
        }()
        
        SearchView()
            .environmentObject(previewDataManager)
    }
} 