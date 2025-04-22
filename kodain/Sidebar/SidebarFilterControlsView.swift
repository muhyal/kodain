import SwiftUI

// Helper functions (Consider moving to a dedicated utility file)
/*
func colorFromHex(_ hex: String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0

    Scanner(string: hexSanitized).scanHexInt64(&rgb)

    let red = Double((rgb & 0xFF0000) >> 16) / 255.0
    let green = Double((rgb & 0x00FF00) >> 8) / 255.0
    let blue = Double(rgb & 0x0000FF) / 255.0

    return Color(red: red, green: green, blue: blue)
}
*/

// Replicate necessary definitions if not globally available
// /* // Keep commented out if defined elsewhere
enum SidebarFilter: Int, CaseIterable, Identifiable {
    case all
    case favorites
    var id: Int { self.rawValue }
}
// */ // Keep commented out if defined elsewhere

struct SidebarFilterControlsView: View {
    @Binding var selectedFilter: SidebarFilter
    @Binding var selectedColorHexFilter: String?
    @Binding var showingSearchSheet: Bool
    @Binding var swipeResetTrigger: Bool // Needed for ColorSelectionPopoverView

    // Actions passed from the parent view
    var onNewRootFolder: () -> Void
    var onNewChat: () -> Void

    // Internal state for the color popover
    @State private var showingColorPopover = false

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager // Needed for onNewChat action

    // Constants moved from SidebarView
    private let availableColors: [String?] = [
        nil, "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE", "#8E8E93"
    ]
    private let colorCircleSize: CGFloat = 14
    private let iconFontSize: Font = .body

    var body: some View {
        HStack(spacing: 10) { // Reduced spacing
            Picker("", selection: $selectedFilter) {
                ForEach(SidebarFilter.allCases) { filter in
                    switch filter {
                    case .all:
                        Image(systemName: "list.bullet").tag(filter).help("All Chats")
                    case .favorites:
                        Image(systemName: "star.fill").tag(filter).help("Favorites")
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.trailing, 5)

            // --- NEW Single Color Filter Button ---
            Button {
                showingColorPopover = true
            } label: {
                HStack(spacing: 4) {
                    if let selectedColor = selectedColorHexFilter {
                        Circle().fill(colorFromHex(selectedColor)).frame(width: colorCircleSize, height: colorCircleSize)
                            .padding(.leading, 6)
                            .padding(.trailing, 2)
                    } else {
                        Image(systemName: "paintpalette")
                            .font(iconFontSize)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.vertical, 4)
                .background(colorScheme == .dark ? Color.gray.opacity(0.25) : Color.gray.opacity(0.15), in: Capsule())
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingColorPopover, arrowEdge: .bottom) {
                // Popover content remains here as its state is managed here
                ColorSelectionPopoverView(
                    selectedColorHexFilter: $selectedColorHexFilter,
                    availableColors: availableColors,
                    swipeResetTrigger: $swipeResetTrigger // Pass the binding
                )
            }
            .help("Filter by Color")
            // --- END Single Color Filter Button ---

            Spacer() // Pushes filters and color button left

            // Group Action Buttons
            HStack(spacing: 12) {
                // Search Button
                Button {
                    showingSearchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Search Chats")

                // New Folder Button
                Button { onNewRootFolder() } label: { // Call closure
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("New Folder")

                // New Chat Button
                Button { onNewChat() } label: { // Call closure
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("New Chat")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8) // Add vertical padding
    }
}

// MARK: - Popover Content View (Keep it with the view that presents it)
// (Assuming ColorSelectionPopoverView is defined elsewhere or moved here)
// If ColorSelectionPopoverView is complex, it should be in its own file.
// For now, we assume it's accessible or defined below/in another file.

// --- Re-define ColorSelectionPopoverView here or ensure it's imported ---
// Helper function (Consider moving to a dedicated utility file) - REMOVED
/*
func colorName(from hex: String) -> String {
     // Basic implementation, enhance as needed
     switch hex.uppercased() {
         case "#FF3B30": return "Red"
         case "#FF9500": return "Orange"
         case "#FFCC00": return "Yellow"
         case "#34C759": return "Green"
         case "#007AFF": return "Blue"
         case "#AF52DE": return "Purple"
         case "#8E8E93": return "Grey"
         default: return "Unknown"
     }
}
*/


private struct ColorSelectionPopoverView: View {
    @Binding var selectedColorHexFilter: String?
    let availableColors: [String?] // Expects the full list including nil
    @Binding var swipeResetTrigger: Bool

    @Environment(\.dismiss) var dismiss
    private let popoverCircleSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by Color").font(.headline).padding(.bottom, 4)

            // Replace LazyVGrid with VStack for simplicity and stability
            VStack(alignment: .leading, spacing: 8) { // Use VStack
                ForEach(availableColors, id: \.self) { colorHex in
                    Button {
                        selectedColorHexFilter = colorHex
                        swipeResetTrigger.toggle()
                        dismiss()
                    } label: {
                        HStack {
                            if let hex = colorHex {
                                Circle()
                                    .fill(colorFromHex(hex))
                                    .frame(width: popoverCircleSize, height: popoverCircleSize)
                                Text(colorName(from: hex))
                                    .font(.callout)
                            } else {
                                Image(systemName: "circle.slash")
                                    .font(.body)
                                Text("All Colors")
                                    .font(.callout)
                            }
                            Spacer()
                            if selectedColorHexFilter == colorHex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding() // Padding around the VStack
    }
}


#if DEBUG
struct SidebarFilterControlsView_Previews: PreviewProvider {
    @State static var filter: SidebarFilter = .all
    @State static var color: String? = nil
    @State static var searchSheet = false
    @State static var swipeTrigger = false

    static var previews: some View {
        SidebarFilterControlsView(
            selectedFilter: $filter,
            selectedColorHexFilter: $color,
            showingSearchSheet: $searchSheet,
            swipeResetTrigger: $swipeTrigger,
            onNewRootFolder: { print("New Root Folder Tapped") },
            onNewChat: { print("New Chat Tapped") }
        )
        .environmentObject(DataManager.preview) // Provide a preview DataManager
        .frame(width: 300)
        .padding()
    }
}
#endif 