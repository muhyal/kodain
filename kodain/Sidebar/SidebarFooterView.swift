import SwiftUI

// Helper function (Consider moving to a dedicated utility file)
/*
func appVersion() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
}
*/

struct SidebarFooterView: View {
    var body: some View {
        HStack(spacing: 8) { // Increased spacing slightly for icons
             // App Logo (Replace "AppIcon" if your asset has a different name)
             Image(nsImage: NSImage(named: "AppIcon") ?? NSImage()) // Use NSImage directly for safety
                 .resizable()
                 .aspectRatio(contentMode: .fit)
                 .frame(width: 24, height: 24) // Adjust size as needed

             VStack(alignment: .leading, spacing: 2) {
                 Text("Kodain")
                     .font(.subheadline) // Reduced font size
                 Text("Version \(appVersion())")
                     .font(.caption) // Use caption size
                     .foregroundColor(.secondary)
             }

             Spacer() // Pushes text left and icons right

             // Info Button
             Button {
                 // Activate app first
                 NSApplication.shared.activate(ignoringOtherApps: true)
                 // Then open the standard About panel
                 NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
             } label: {
                 Image(systemName: "info.circle")
                     .font(.title3)
                     .foregroundColor(.secondary)
             }
             .buttonStyle(.plain)
             .help("About Kodain")

             // Settings Link (Correct way to open Settings)
             SettingsLink {
                  Image(systemName: "gearshape.fill")
                      .font(.title3)
                      .foregroundColor(.secondary)
             }
             .buttonStyle(.plain) // Keep the plain style
              .help("Settings")
         }
         .padding(.top, 8) // Add top padding to match bottom padding
         .padding(.horizontal) // Add horizontal padding to the HStack
         .padding(.bottom, 8) // Add bottom padding
    }
}

#if DEBUG
struct SidebarFooterView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarFooterView()
            .frame(width: 250)
    }
}
#endif 