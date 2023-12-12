//
//  nightscoutbarApp.swift
//  nightscoutbar
//
//  Created by Peter Wallman on 2023-12-11.
//

import SwiftUI
import Combine

@main
struct NightscoutBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // Define your settings view here
            // This is optional if you are handling everything in the AppDelegate
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusBarItem: NSStatusItem!
    var nightscoutViewModel = NightscoutViewModel()
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the initial text or image for the status bar item
        if let button = statusBarItem.button {
            button.title = "Nightscout"
//            button.action = #selector(statusBarButtonClicked(_:))
        }

        // Create a new menu
        let statusBarMenu = NSMenu(title: "Status Bar Menu")

        // Add menu items
        statusBarMenu.addItem(
            withTitle: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        statusBarMenu.addItem(
            withTitle: "Quit",
            action: #selector(quitApp),
            keyEquivalent: ""
        )

        // Assign the menu to the status bar item
        statusBarItem.menu = statusBarMenu
        statusBarItem.button?.title = "0.0 ?"
        nightscoutViewModel.startFetching()

        // Observe any changes in the NightscoutViewModel
           nightscoutViewModel.objectWillChange.sink { [weak self] _ in
               // Update the status bar whenever there is a change in the ViewModel
               self?.updateStatusBar()
           }.store(in: &cancellables)
    }

    func updateStatusBar() {
        let valueString = nightscoutViewModel.useMmol ? String(format: "%.1f", nightscoutViewModel.glucoseValue) : "\(Int(nightscoutViewModel.glucoseValue))"
        let withArrow = valueString + " " + nightscoutViewModel.direction

        if let button = statusBarItem.button {
            DispatchQueue.main.async {
                button.title = withArrow
            }
        }
    }

    var cancellables = Set<AnyCancellable>()

    @objc func quitApp() {
        NSApp.terminate(self)
    }

    @objc func openSettings() {
        // Check if the settings window already exists
        if settingsWindow == nil {
            // Create the settings window if it does not exist
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("Settings")
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.title = "Settings"
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView(viewModel: nightscoutViewModel))
        }

        // Bring the existing or new settings window to the front
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


