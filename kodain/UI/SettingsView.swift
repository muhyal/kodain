import SwiftUI

struct SettingsView: View {
    // Inject DataManager from the environment (even if not used yet)
    @EnvironmentObject var dataManager: DataManager
    
    // Environment variable to dismiss the view
    @Environment(\.dismiss) var dismiss

    // State variable to hold the API key entered by the user
    @State private var apiKeyInput: String = ""
    // State variable to show feedback to the user (e.g., "Saved!")
    @State private var feedbackMessage: String = ""

    // State for Data Management
    @State private var dataStoreSize: String = "Calculating..."
    @State private var showingDeleteConfirmation = false
    @State private var showingDemoDataConfirm = false

    var body: some View {
        // Use a TabView for better organization
        TabView {
            // API Key Tab
            apiSettingsTab()
                .tabItem {
                    Label("API Key", systemImage: "key.fill")
                }

            // Data Management Tab
            dataManagementTab()
                .tabItem {
                    Label("Data", systemImage: "cylinder.split.1x2.fill")
                }
        }
        .frame(width: 400, height: 200) // Adjust frame for TabView
    }

    // MARK: - Tab Views

    @ViewBuilder
    private func apiSettingsTab() -> some View {
        VStack(alignment: .leading, spacing: 15) { // Adjusted spacing
            Text("Gemini API Key")
                .font(.title3) // Slightly larger title

            TextField("Enter your API Key", text: $apiKeyInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onAppear {
                    apiKeyInput = KeychainHelper.loadAPIKey() ?? ""
                }

            Text("Get your key from Google AI Studio.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer() // Pushes button and feedback down

            HStack {
                Button("Save API Key") { // Renamed button
                    saveApiKey()
                }
                .disabled(apiKeyInput.isEmpty)

                Spacer()

                Text(feedbackMessage)
                    .font(.caption)
                    .foregroundColor(feedbackMessage.starts(with: "Error") ? .red : .green)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func dataManagementTab() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Data Management")
                .font(.title3)

            HStack {
                Text("Approximate Data Size:")
                Spacer()
                Text(dataStoreSize)
                    .foregroundColor(.secondary)
            }

            Text("This is the size of the preferences file containing chats, folders, and other settings.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Spacer() // Push button to the right
                Button("Load Demo Data...", role: .none) {
                    showingDemoDataConfirm = true
                }
                Button("Delete All Chat & Folder Data...", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .padding()
        .onAppear(perform: updateDataStoreSize) // Calculate size when tab appears
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Chats and Folders", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your chat sessions and folders will be permanently deleted.")
        }
        .confirmationDialog(
            "Load Demo Data?",
            isPresented: $showingDemoDataConfirm,
            titleVisibility: .visible
        ) {
            Button("Load Demo Data", role: .destructive) {
                loadDemoData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Loading demo data will replace all your current chats and folders. This action cannot be undone.")
        }
    }

    // MARK: - Helper Functions

    // Renamed function, no longer dismisses
    private func saveApiKey() {
        if KeychainHelper.saveAPIKey(apiKeyInput) {
            feedbackMessage = "API Key Saved!"
            // Clear message after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                feedbackMessage = ""
            }
        } else {
            feedbackMessage = "Error Saving Key"
        }
    }

    // Function to update the displayed data store size
    private func updateDataStoreSize() {
        if let sizeBytes = dataManager.getDataStoreSize() {
            // Format the size into KB or MB for readability
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB] // Allow up to GB
            formatter.countStyle = .file
            dataStoreSize = formatter.string(fromByteCount: sizeBytes)
        } else {
            dataStoreSize = "N/A" // Indicate if size couldn't be determined (e.g., file not found)
        }
    }

    // Function to delete all data and update the size display
    private func deleteAllData() {
        dataManager.deleteAllUserData()
        // Refresh the displayed size after deletion
        updateDataStoreSize()
        // Consider providing feedback or closing settings after deletion
    }

    // Add function to call DataManager for loading demo data
    private func loadDemoData() {
        dataManager.loadDemoData() // Assuming this function exists in DataManager
        updateDataStoreSize() // Refresh size display after loading new data
        // Provide feedback?
        feedbackMessage = "Demo Data Loaded!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            feedbackMessage = ""
        }
    }
}

// Preview Provider
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
