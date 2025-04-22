import SwiftUI
import MarkdownUI // Needed for Markdown view

// REFACTORED Helper View for Chat Bubbles
struct ChatBubble: View {
    let message: DisplayMessage // <-- Takes DisplayMessage now
    // Add properties to receive colors/gradients
    let userBubbleGradient: LinearGradient
    let aiBubbleGradient: LinearGradient
    let aiRawBackground: Color
    let userGlowColor: Color
    let aiGlowColor: Color
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager
    @State private var showRawMarkdown: Bool = false
    @State private var showingMetadataPopover: Bool = false // State for popover visibility
    @State private var showingDeleteConfirm: Bool = false // <-- State for delete confirmation

    var body: some View {
        HStack(spacing: 0) { // Use 0 spacing, control with padding
            if message.role == .user {
                Spacer() // Push user message right
                
                HStack(alignment: .bottom, spacing: 5) {
                    // VStack to hold image (if exists) and text bubble
                    VStack(alignment: .trailing, spacing: 4) { 
                        // Show screenshot if available
                        if let imageData = message.screenshotData, let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 300, maxHeight: 200) // Limit size
                                .cornerRadius(8)
                                .padding(.bottom, 4) // Space between image and text
                        }
                    
                        // User Bubble Content with Gradient and Glow
                        Text(message.content)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(userBubbleGradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: userGlowColor.opacity(0.4), radius: 5, x: 0, y: 2) // Glow effect
                            .textSelection(.enabled)
                    } // End of VStack for Image and Text

                    // Updated User Avatar with Gradient and Glow (Now sibling to VStack)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30) // Slightly larger
                        .background(userBubbleGradient)
                        .clipShape(Circle())
                        .shadow(color: userGlowColor.opacity(0.5), radius: 3, x: 0, y: 1)
                } // End of HStack
                .padding(.leading, 40) // Ensure bubble doesn't touch left edge
                .padding(.trailing, 10) // Padding on the right
                
            } else { // message.role == .model
                // Wrap the existing HStack in a VStack to place buttons above
                VStack(alignment: .leading, spacing: 4) { // Adjusted spacing slightly
                    
                    // --- Original HStack (Avatar + Content) ---
                    HStack(alignment: .bottom, spacing: 5) { 
                        // Updated AI Avatar with Gradient and Glow
                        Image(systemName: "sparkle")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30) // Slightly larger
                            .background(aiBubbleGradient)
                            .clipShape(Circle())
                            .shadow(color: aiGlowColor.opacity(0.5), radius: 3, x: 0, y: 1)
                            
                        VStack(alignment: .leading, spacing: 4) { // VStack for Bubble/Buttons ZStack and Metadata
                            // AI Bubble Content (Markdown or Raw) with Gradient and Glow
                            VStack(alignment: .leading) {
                                if showRawMarkdown {
                                    ScrollView {
                                        Text(message.content)
                                            .font(.system(.body, design: .monospaced))
                                            .padding(.all, 10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    .background(aiRawBackground) // Use defined raw background
                                    .cornerRadius(16)
                                    .shadow(color: aiGlowColor.opacity(0.4), radius: 5, x: 0, y: 2) // Glow effect
                                } else {
                                    Markdown(message.content)
                                        .textSelection(.enabled)
                                        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                        .background(aiBubbleGradient)
                                        .foregroundColor(.primary) // Use primary for better contrast on gradient
                                        .cornerRadius(16)
                                        .shadow(color: aiGlowColor.opacity(0.4), radius: 5, x: 0, y: 2) // Glow effect
                                }
                            }
                            
                            // Metadata Display (Below the Bubble, inside the VStack)
                            if let metadata = message.metadata {
                                metadataView(metadata: metadata)
                            }
                        } // End VStack for Bubble + Metadata
                         // Ensure content VStack doesn't stretch unnecessarily if bubble is small
                        .layoutPriority(1)
                        
                    } // End HStack for Avatar and Content VStack
                    
                } // End ADDED VStack wrapping buttons and HStack
                .padding(.trailing, 40) // Ensure bubble doesn't touch right edge
                .padding(.leading, 10) // Padding on the left
                
                Spacer() // Push AI message group left
            }
        }
        .padding(.vertical, 8) // INCREASED vertical padding
        // Add context menu to the entire row
        .contextMenu {
            if message.role == .user {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(message.content, forType: .string)
                } label: {
                    Label("Copy Question", systemImage: "doc.on.doc")
                }
                
                Button(role: .destructive) {
                     // Don't delete directly, show confirmation dialog
                     showingDeleteConfirm = true
                 } label: {
                     Label("Delete Entry", systemImage: "trash")
                 }
            } else { // .model
                 Button {
                     let pasteboard = NSPasteboard.general
                     pasteboard.clearContents()
                     pasteboard.setString(message.content, forType: .string)
                 } label: {
                     Label("Copy Answer", systemImage: "doc.on.doc")
                 }
                 
                 Button(role: .destructive) {
                      // Don't delete directly, show confirmation dialog
                      showingDeleteConfirm = true
                  } label: {
                      Label("Delete Entry", systemImage: "trash")
                  }
            }
        }
        // Add confirmation dialog modifier here
        .confirmationDialog(
            "Delete this message?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Message", role: .destructive) {
                // Use EntryManager to delete entry
                dataManager.entryManager.deleteEntry(entryId: message.entryId)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            // Optional message below the title
            Text("This action cannot be undone.")
        }
    }

    // Helper for Metadata View (Restored details)
    @ViewBuilder
    private func metadataView(metadata: ChatEntryMetadata) -> some View {
        HStack(spacing: 8) { // Increased spacing slightly
            // --- NEW Buttons --- 
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(message.content, forType: .string)
            } label: {
                Image(systemName: "doc.on.clipboard") // CORRECTED Icon for raw copy
            }
            .buttonStyle(.plain)
            .help("Copy Raw Answer")
            
            // --- Delete Button --- Modify Action
            Button {
                // Don't delete directly, show confirmation instead
                showingDeleteConfirm = true 
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .help("Delete Entry")
            
            // --- MOVED Raw/Rendered Toggle Button --- 
            Button { 
                showRawMarkdown.toggle() 
            } label: { 
                Image(systemName: showRawMarkdown ? "doc.richtext.fill" : "doc.plaintext")
            } 
            .buttonStyle(.plain)
            .help(showRawMarkdown ? "Rendered View" : "Raw Markdown View")
            
            Spacer() // Push the original metadata info right
            
            // --- Original Info Button + Timestamp --- 
            Button {
                showingMetadataPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingMetadataPopover,
                     attachmentAnchor: .point(.bottomLeading),
                     arrowEdge: .leading) {
                metadataPopover(metadata: metadata)
            }
            
            Text(message.timestamp, style: .time)
        }
        .font(.caption) 
        .foregroundColor(.secondary)
        .padding(.leading, 35) 
        .padding(.top, 2)
    }
    
    // --- Custom Popover View --- 
    @ViewBuilder
    private func metadataPopover(metadata: ChatEntryMetadata) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let wc = metadata.wordCount { Text("Words: \(wc)") }
            if let tc = metadata.candidatesTokenCount { Text("Tokens (Cand.): \(tc)") } // More descriptive
            if let tt = metadata.totalTokenCount { Text("Tokens (Total): \(tt)") } // More descriptive
            if let rt = metadata.responseTimeMs { Text("Latency: \(rt)ms") }
            if let model = metadata.modelName { Text("Model: \(model.replacingOccurrences(of: "gemini-", with: ""))") }
        }
        .font(.caption) // Keep caption font for consistency
        .padding(8) // Inner padding
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 3)
        .fixedSize() // Prevent it from taking full width
    }
} 