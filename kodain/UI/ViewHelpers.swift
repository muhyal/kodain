import SwiftUI

// MARK: - Preference Keys

// Preference Key for Row Height (Used by SidebarListView and potentially others)
struct RowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue()) // Use the maximum height encountered
    }
}

// MARK: - Protocols & Extensions

// Sidebar Filter Enum (Simplified back) - REMOVED
/*
enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "All Chats"
    case favorites = "Favorites"
    // Removed color cases

    var id: String { self.rawValue }
}
*/

// Protocol to allow generic color setting menu
protocol HasColor {
    var colorHex: String? { get }
}

// Make Folder and ChatSession conform (ChatSession already does implicitly)
extension Folder: HasColor {}
// Explicitly declare conformance for ChatSession
extension ChatSession: HasColor {}

// Helper to get app version
func appVersion() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
}

// Helper to convert hex to Color
func colorFromHex(_ hex: String?) -> Color {
    guard let hex = hex, hex.hasPrefix("#"), hex.count == 7 else { return Color.gray }
    let scanner = Scanner(string: String(hex.dropFirst()))
    var rgbValue: UInt64 = 0
    scanner.scanHexInt64(&rgbValue)
    let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
    let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
    let b = Double(rgbValue & 0x0000FF) / 255.0
    return Color(red: r, green: g, blue: b)
}

// Optional helper to get a name for a hex color
func colorName(from hex: String?) -> String {
    guard let hex = hex else { return "Unknown" }
    switch hex {
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