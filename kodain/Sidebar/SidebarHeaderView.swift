import SwiftUI

struct SidebarHeaderView: View {
    var body: some View {
        HStack {
            Text("🧠 Kodain Chats")
                .font(.title2.bold()) // Bolder title

            Spacer()

            // REMOVED Settings button (as it's no longer in the original SidebarView)
            /*
            // Group buttons for better spacing control if needed
            HStack(spacing: 15) { // Increase spacing
                Button { openSettings() } label: {
                     Image(systemName: "gearshape.fill")
                         .font(.title3) // Consistent font size
                 }
                .buttonStyle(.plain)
                .help("Settings")
                .contentShape(Rectangle()) // Ensure tappable area
            }
            */
        }
        .padding(.horizontal)
        .padding(.top, 10) // Add top padding
        .padding(.bottom, 8) // Adjust bottom padding
    }
}

// Preview if needed
#if DEBUG
struct SidebarHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarHeaderView()
            .frame(width: 250) // Example width for preview
    }
}
#endif 