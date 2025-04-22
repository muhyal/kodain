import SwiftUI

// MARK: - Chat Detail Component
struct ChatDetailView: View {
    // Pass colors/gradients
    let userBubbleGradient: LinearGradient
    let aiBubbleGradient: LinearGradient
    let aiRawBackground: Color
    let userGlowColor: Color
    let aiGlowColor: Color
    
    // ViewModel for state and logic
    @StateObject private var viewModel: ChatDetailViewModel
    
    // State for local search within this view
    @State private var searchText: String = ""    
    @State private var showSearch = false // State to control search bar visibility
    
    // Environment
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var inputIsFocused: Bool // Focus state for the input TextField
    
    // Initializer to inject dependencies into the ViewModel
    init(userBubbleGradient: LinearGradient,
         aiBubbleGradient: LinearGradient,
         aiRawBackground: Color,
         userGlowColor: Color,
         aiGlowColor: Color,
         dataManager: DataManager, // Pass DataManager
         geminiService: GeminiService) // Pass GeminiService
    {
        self.userBubbleGradient = userBubbleGradient
        self.aiBubbleGradient = aiBubbleGradient
        self.aiRawBackground = aiRawBackground
        self.userGlowColor = userGlowColor
        self.aiGlowColor = aiGlowColor
        // Create the ViewModel (init no longer takes searchText)
        self._viewModel = StateObject(wrappedValue: ChatDetailViewModel(dataManager: dataManager, 
                                                                         geminiService: geminiService))
    }

    // Computed property to filter messages based on local searchText
    var filteredMessages: [DisplayMessage] {
        if searchText.isEmpty {
            return viewModel.messagesForList
        } else {
            return viewModel.messagesForList.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat Message List View
            // Conditional Content: Show List or Placeholder
            if viewModel.messagesForList.isEmpty {
                Spacer() // Push content to center
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill") // Placeholder icon
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No messages yet.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Start the conversation by typing below.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                Spacer() // Push content to center
            } else {
                ScrollViewReader { scrollViewProxy in
                    // Use filtered messages from the ViewModel
                    List(filteredMessages) { message in
                        ChatBubble(
                            message: message,
                            userBubbleGradient: userBubbleGradient,
                            aiBubbleGradient: aiBubbleGradient,
                            aiRawBackground: aiRawBackground,
                            userGlowColor: userGlowColor,
                            aiGlowColor: aiGlowColor
                        )
                            .id(message.id)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .environmentObject(viewModel.dataManager) // Pass via ViewModel

                        // Add invisible spacer at the end of the list content
                        // This pushes the last actual message above the input area when scrolled to bottom
                        if message.id == filteredMessages.last?.id {
                            Color.clear.frame(height: 70) // Adjust height approx to input area height
                                .listRowInsets(EdgeInsets()) // Ensure spacer takes full width
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .background(.clear)
                    // Observe changes in the total message count to detect new messages
                    .onChange(of: viewModel.messagesForList.count) { _, newCount in
                        // Use DispatchQueue.main.async to ensure scrolling happens after List update
                        DispatchQueue.main.async {
                            // Attempt to scroll to the *last visible* message in the filtered list
                            if let lastVisibleMessageId = filteredMessages.last?.id {
                                print("New message detected (count: \(newCount)). Scrolling to last visible ID: \(lastVisibleMessageId)")
                                scrollToBottom(proxy: scrollViewProxy, id: lastVisibleMessageId)
                            } else if newCount > 0 {
                                print("New message detected (count: \(newCount)), but last message is filtered out. Not scrolling.")
                            }
                        }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: 10)
                    }
                }
            }
 
            // Status Area using ViewModel's state
            statusArea(statusText: viewModel.statusText)
 
            // --- Screenshot Preview and Clear Area ---
            // Use ViewModel's image data
            if let imageData = viewModel.capturedImageData, let nsImage = NSImage(data: imageData) {
                screenshotPreviewArea(nsImage: nsImage)
            }
 
            // Input Area (Already has ultraThinMaterial background)
            inputArea(userInput: $viewModel.userInput, 
                      isLoading: viewModel.isLoading,
                      canSubmit: viewModel.canSubmit, // Use computed property
                      hasCapturedImage: viewModel.capturedImageData != nil, 
                      submitAction: { Task { await viewModel.submitQuery() } },
                      captureAction: { Task { await viewModel.captureScreenshot() } })
        }
        .frame(minWidth: 450) // Ensure chat detail has a minimum width
        .navigationTitle(viewModel.activeSessionTitle)
        // APPLY searchable HERE directly
        .searchable(text: $searchText, placement: .automatic)
        // Add onChange to handle refocus trigger from ViewModel
        .onChange(of: viewModel.shouldRefocusInput) { _, shouldFocus in // Use _ for unused oldValue
            if shouldFocus {
                inputIsFocused = true
                viewModel.shouldRefocusInput = false // Reset the trigger
            }
        }
        .toolbar { // Add toolbar content
            // REMOVE ToolbarItemGroup related to the manual search button
        }
    }
    
    // Helper function to scroll to the bottom
    private func scrollToBottom(proxy: ScrollViewProxy, id: String, anchor: UnitPoint? = nil) {
        print("ScrollToBottom: Attempting to scroll to ID \(id)")
        // Use withAnimation for smoother scrolling
        withAnimation(.easeOut(duration: 0.2)) { // Adjust duration if needed
             proxy.scrollTo(id, anchor: anchor)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func statusArea(statusText: String) -> some View {
        // Check isLoading state from the ViewModel to decide what to show
        if viewModel.isLoading {
            HStack(spacing: 8) {
                // Image(systemName: "hourglass") // Requested icon - REMOVED
                //     .foregroundColor(.secondary)
                ProgressView() // Loading animation
                    .controlSize(.small) // Make the spinner small
                Text("Generating response...") // Ensure text is present
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        } else if !statusText.isEmpty {
            // Existing logic for non-loading status messages (like errors)
            Text(statusText)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(statusText.starts(with: "Error") ? .red : .secondary)
                .font(.caption)
                .background(.ultraThinMaterial) // Keep this specific background
        }
        // Implicit else: If not loading and statusText is empty, show nothing
    }
    
    @ViewBuilder
    private func screenshotPreviewArea(nsImage: NSImage) -> some View {
        HStack {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40) // Preview height
                .cornerRadius(4)
                .padding(.vertical, 4)
                
            Spacer() // Pushes icon to the right
                
            Button {
                // Clear image and related state
                viewModel.capturedImageData = nil
                if viewModel.statusText == "Screenshot captured." {
                   viewModel.statusText = "" // Clear status message
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Clear Screenshot")
            .onTapGesture { viewModel.clearScreenshot() }
        }
        .padding(.horizontal)
        .padding(.bottom, 5) // Space between input area
        // Maybe a subtle background?
        // .background(Color.secondary.opacity(0.1))
        // .cornerRadius(8)
        .transition(.scale.combined(with: .opacity)) // Nice transition
    }
    
    @ViewBuilder
    private func inputArea(userInput: Binding<String>,
                           isLoading: Bool,
                           canSubmit: Bool, // Use canSubmit from ViewModel
                           hasCapturedImage: Bool,
                           submitAction: @escaping () -> Void,
                           captureAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            // Input TextField using binding
            TextField("Enter your question...", text: userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .focused($inputIsFocused) // Bind focus state
                .onSubmit { if !isLoading { submitAction() } } // Use submitAction
                .disabled(isLoading || viewModel.dataManager.activeSessionId == nil) // Check activeSessionId via viewModel

            // Send Button using ViewModel state and action
            Button(action: submitAction) { // Use submitAction
                Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || viewModel.dataManager.activeSessionId == nil) // Check canSubmit and activeSessionId via viewModel
            .keyboardShortcut(isLoading ? .cancelAction : .defaultAction)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
            .animation(.easeInOut(duration: 0.2), value: !canSubmit)

            // Screenshot Button using ViewModel state and action
            Button(action: captureAction) { // Use captureAction
                // Change button appearance based on ViewModel state
                Image(systemName: hasCapturedImage ? "camera.fill" : "camera") 
                    .foregroundColor(hasCapturedImage ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 5)
            .disabled(isLoading) // Disable button during capture
            .help(hasCapturedImage ? "Replace Screenshot" : "Capture Screenshot")
        }
        .padding()
        .background(.ultraThinMaterial) // Keep this specific background
    }
} 