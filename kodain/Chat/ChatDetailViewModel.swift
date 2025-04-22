import SwiftUI
import Combine
import GoogleGenerativeAI // For ModelContent

@MainActor // Ensures UI updates happen on the main thread
class ChatDetailViewModel: ObservableObject {
    // MARK: - Dependencies
    let dataManager: DataManager
    private let geminiService: GeminiService
    private let screenshotService = ScreenshotService() // Internal service

    // MARK: - Published Properties (State)
    @Published var userInput: String = ""
    @Published var isLoading: Bool = false
    @Published var statusText: String = ""
    @Published var capturedImageData: Data? = nil
    // NEW: Internal published array synchronized with DataManager
    @Published var messagesForList: [DisplayMessage] = []
    
    // Published property to trigger input refocus from the View
    @Published var shouldRefocusInput = false
    
    // MARK: - Private Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    init(dataManager: DataManager, geminiService: GeminiService) {
        self.dataManager = dataManager
        self.geminiService = geminiService
        
        // Setup Combine subscription to synchronize messages
        dataManager.$activeSessionDisplayMessages
            .receive(on: DispatchQueue.main) // Ensure updates are on the main thread
            .assign(to: \.messagesForList, on: self) // Assign directly to messagesForList
            .store(in: &cancellables)
        
        print("ChatDetailViewModel initialized and subscribed to activeSessionDisplayMessages.")
        
        // Observe changes in DataManager's relevant properties if needed
        // For example, if statusText should react to DataManager changes
        // dataManager.$someProperty
        //    .sink { [weak self] newValue in
        //        // Update statusText or other properties
        //    }
        //    .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    // Active session title
    var activeSessionTitle: String {
        guard let activeID = dataManager.activeSessionId,
              let session = dataManager.chatSessions.first(where: { $0.id == activeID }) else {
            return "No Chat Selected"
        }
        return session.title
    }
    
    var canSubmit: Bool {
        (!userInput.isEmpty || capturedImageData != nil) && dataManager.activeSessionId != nil && !isLoading
    }

    // MARK: - Actions (Moved from View)

    func submitQuery() async {
        // Ensure an active session exists, but we don't need the ID variable itself here.
        guard dataManager.activeSessionId != nil else {
            statusText = "Error: No active chat session."
            return
        }
        // Ensure there's either text input OR an image to send
        guard !userInput.isEmpty || capturedImageData != nil else { return } 
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            statusText = "Error: API Key is missing. Please add it via Settings (⚙️)."
            return
        }

        isLoading = true
        let currentInput = userInput
        let currentImageData = capturedImageData // Copy image data
        userInput = "" // Clear input immediately
        // Clear image state immediately
        capturedImageData = nil 
        statusText = "Generating response..."

        // History generation can stay here or be moved deeper if complex
        let history: [ModelContent] = dataManager.activeSessionEntries.flatMap { entry -> [ModelContent] in
             var turn: [ModelContent] = []
             // Assuming image data is not part of history for now, add if needed
             if !entry.question.isEmpty { turn.append(ModelContent(role: "user", parts: [.text(entry.question)])) }
             if !entry.answer.isEmpty { turn.append(ModelContent(role: "model", parts: [.text(entry.answer)])) }
             return turn
        }

        var promptParts: [ModelContent.Part] = []
        if !currentInput.isEmpty {
             promptParts.append(.text(currentInput))
        }
        if let imageData = currentImageData {
             // Ensure correct mimetype if supporting other types
             promptParts.append(.data(mimetype: "image/png", imageData)) 
        }

        let result = await geminiService.generateResponse(history: history, latestPromptParts: promptParts, apiKey: apiKey)

        isLoading = false // Stop loading indicator regardless of outcome

        switch result {
        case .success(let generationResult):
            // Call EntryManager on the main thread to add the entry
            dataManager.entryManager.addEntryToActiveSession(question: currentInput, imageData: currentImageData, generationResult: generationResult)
            // Trigger refocus after successful submission
            shouldRefocusInput = true
            statusText = "" // Clear status on success
        case .failure(let error):
            statusText = "Error: \(error.localizedDescription)"
            // Restore input only on failure? Or clear always? Current: clear always.
            // userInput = currentInput 
        }
    }
    
    func captureScreenshot() async {
        isLoading = true // Start loading state
        statusText = "Starting screen capture..."
        capturedImageData = nil // Clear previous image immediately
        
        do {
            let imageData = try await screenshotService.captureInteractiveScreenshotToClipboard()
            // State updates are already on MainActor
            self.capturedImageData = imageData
            statusText = imageData != nil ? "Screenshot captured. Ready to send or add text." : "Screenshot cancelled."
            isLoading = false // End loading state
        } catch let error as ScreenshotError {
            self.capturedImageData = nil
            var errorMessage = "Screenshot Error: \(error.localizedDescription)"
            if case .captureFailed = error {
                errorMessage += "\nPlease check System Settings > Privacy & Security > Screen Recording and grant permission."                                   
            }
            statusText = errorMessage
            isLoading = false
        } catch {
            self.capturedImageData = nil
            statusText = "Error capturing screenshot: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func clearScreenshot() {
        capturedImageData = nil
        if statusText == "Screenshot captured. Ready to send or add text." {
            statusText = "" // Clear status message only if it was the success message
        }
    }
} 