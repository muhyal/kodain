//
//  KodainApp.swift
//  kodain
//
//  Created by Muhammed Yalçınkaya on 17.04.2025.
//

import SwiftUI
import SwiftData
import AppKit
// Import ApplicationServices for Accessibility check
import ApplicationServices

// Define AppDelegate to handle global events and window management
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    // Remove unused variables related to manual window management
    // private var optionKeyPressCount = 0
    // private var lastOptionKeyPressTime: TimeInterval = 0
    // private let keyIntervalThreshold: TimeInterval = 0.5
    // private var previousModifierFlags: NSEvent.ModifierFlags?
    // Make these private
    private var optionKeyPressCount = 0
    private var lastOptionKeyPressTime: TimeInterval = 0
    private let keyIntervalThreshold: TimeInterval = 0.5
    private var previousModifierFlags: NSEvent.ModifierFlags?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: applicationDidFinishLaunching")
        if checkAndRequestAccessibilityPermissions() {
            print("AppDelegate: Accessibility permissions granted.")
            setupGlobalMonitor()
        } else {
            print("AppDelegate: Accessibility permissions NOT granted.")
        }

        // Status bar item setup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
             button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Kodain")
             button.action = #selector(statusItemClicked(_:))
             button.target = self
             print("AppDelegate: Status item created and configured.")
        } else {
             print("AppDelegate Error: Unable to create status bar button.")
        }
        
        NSApp.setActivationPolicy(.regular)
    }

    // Function to check accessibility permissions and prompt user if needed
    func checkAndRequestAccessibilityPermissions() -> Bool {
        print("AppDelegate: Checking Accessibility Permissions...")
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if accessEnabled {
            print("AppDelegate: Accessibility Access is already enabled.")
            return true
        } else {
            print("AppDelegate: Accessibility Access is not enabled. System prompt may be shown.")
            return false
        }
    }

    // Function to setup the global keyboard shortcut monitor
    func setupGlobalMonitor() {
        print("AppDelegate: Setting up global monitor for double Option key press...")
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            
            let currentFlags = event.modifierFlags
            let previousFlags = self.previousModifierFlags ?? NSEvent.ModifierFlags() 

            if !previousFlags.contains(.option) && currentFlags.contains(.option) {
                 let currentTime = Date().timeIntervalSince1970
                if (currentTime - self.lastOptionKeyPressTime) < self.keyIntervalThreshold {
                    self.optionKeyPressCount += 1
                } else {
                    self.optionKeyPressCount = 1
                }
                self.lastOptionKeyPressTime = currentTime
                
                if self.optionKeyPressCount == 2 {
                    print("AppDelegate: Double Option Key DETECTED!")
                    self.optionKeyPressCount = 0
                    self.lastOptionKeyPressTime = 0 
                    
                    DispatchQueue.main.async {
                        print("AppDelegate: Calling toggleMainWindowActivation() on main thread.")
                        self.toggleMainWindowActivation()
                    }
                 }
            } 
            self.previousModifierFlags = currentFlags
        }
        print("AppDelegate: Global monitor setup complete for flagsChanged.")
    }

    // Action called when the status item is clicked
    @objc func statusItemClicked(_ sender: Any?) {
        print("AppDelegate: Status item clicked.")
        toggleMainWindowActivation()
    }

    // Yeni fonksiyon: Uygulamayı aktive eder ve pencereyi öne getirir
    func toggleMainWindowActivation() {
        print("AppDelegate: toggleMainWindowActivation called.")
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible && !($0 is NSPanel) && $0.identifier?.rawValue.contains("mainWindow") ?? false }) {
             print("AppDelegate: Found main window, making key and ordering front.")
             mainWindow.makeKeyAndOrderFront(nil)
        } else {
             print("AppDelegate: Main window not found or not suitable. App activation should handle reopening/showing.")
        }
    }

    // Delegate method called when the app is reactivated (e.g., clicking Dock icon)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("AppDelegate: applicationShouldHandleReopen called. Has visible windows: \(flag)")
        if !flag {
             print("AppDelegate: No visible windows, activating app to reopen/show main window.")
             NSApp.activate(ignoringOtherApps: true) 
        } else {
            print("AppDelegate: Windows visible, ensuring one is key.")
            if let mainWindow = NSApp.windows.first(where: { $0.canBecomeKey && !($0 is NSPanel) && $0.identifier?.rawValue.contains("mainWindow") ?? false }) { 
                 mainWindow.makeKeyAndOrderFront(nil)
            } else {
                 NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true 
    }
}

@main
struct KodainApp: App {
    // Inject the App Delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // DataManager'ı StateObject olarak oluştur
    @StateObject private var dataManager = DataManager()

    var body: some Scene {
        // --- Ana Pencere ---
        WindowGroup(id: "mainWindow") { // ID ekledik
            ModalView()
                .environmentObject(dataManager) // DataManager'ı inject et
        }
        // Başlangıçta gizli olmasını istiyorsanız:
        // .defaultVisibility(.hidden) 
        
        // --- Ayarlar Penceresi ---
        Settings {
            SettingsView()
                .environmentObject(dataManager) // DataManager'ı inject et
                .frame(minWidth: 450, minHeight: 300) 
        }
        
        // --- Komutlar ---
        // Standart komutları kullanıyoruz, özel About'u kaldırdık.
        .commands {
            // Gerekirse SidebarCommands gibi özel komut setleri eklenebilir
            // CommandGroup(replacing: .newItem) { } // Örnek
        }
    }
}

// Placeholder for ModalView - Create ModalView.swift next
// struct ModalView: View { ... }
