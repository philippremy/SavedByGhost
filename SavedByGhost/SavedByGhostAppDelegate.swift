//
//  AppDelegate.swift
//  SavedByGhost
//
//  Copyright (C)  Philipp Remy 2026 - Present
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

import SavedByGhostKit

import Cocoa
import ScreenSaver
import SwiftUI

@MainActor
class SavedByGhostAppDelegate: NSObject, NSApplicationDelegate {
    
    var savedByGhostScreenSaverPreviewWindow: NSWindow?
    var savedByGhostUIWindow: NSPanel?
    
    var statusItem: NSStatusItem!

    @objc func openScreenSaverWindow() {
        
        let screenSaverWindowID = "de.philippremy.SavedByGhost.ScreenSaverPreviewWindowID"
        
        if NSApplication.shared.windows.contains(where: { window in
            return window.identifier == NSUserInterfaceItemIdentifier(screenSaverWindowID)
        }) {
            NSApplication.shared.windows.first(where: {
                window in
                    return window.identifier == NSUserInterfaceItemIdentifier(screenSaverWindowID)
            })?.makeKeyAndOrderFront(self)
            return
        }
        
        let screenRect = NSScreen.main!.visibleFrame;
        let visibleRect = NSRect(origin: screenRect.origin, size: NSMakeSize(screenRect.width, screenRect.height))
        self.savedByGhostScreenSaverPreviewWindow = NSWindow(contentRect: visibleRect, styleMask: [.titled, .closable, .miniaturizable, .unifiedTitleAndToolbar, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        self.savedByGhostScreenSaverPreviewWindow?.identifier = NSUserInterfaceItemIdentifier(screenSaverWindowID)
        self.savedByGhostScreenSaverPreviewWindow?.isReleasedWhenClosed = false
        self.savedByGhostScreenSaverPreviewWindow?.contentView = SavedByGhostView().setup()
        self.savedByGhostScreenSaverPreviewWindow?.center()
        self.savedByGhostScreenSaverPreviewWindow?.titlebarAppearsTransparent = true
        self.savedByGhostScreenSaverPreviewWindow?.makeKeyAndOrderFront(self)
    }
    
    private func openAppWindow() {

        let savedByGhostUIView = SavedByGhostUIView()
        let swiftUIBridge = NSHostingController(rootView: savedByGhostUIView)
        swiftUIBridge.sizingOptions = [.intrinsicContentSize, .preferredContentSize, .minSize]
        swiftUIBridge.view.wantsLayer = true
        swiftUIBridge.view.layer?.cornerRadius = 12
        swiftUIBridge.view.layer?.masksToBounds = true
        
        self.savedByGhostUIWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        savedByGhostUIWindow!.hasShadow = true
        savedByGhostUIWindow!.backgroundColor = .clear
        savedByGhostUIWindow!.isFloatingPanel = false
        savedByGhostUIWindow!.titleVisibility = .hidden
        savedByGhostUIWindow!.titlebarAppearsTransparent = true
        savedByGhostUIWindow!.contentView = swiftUIBridge.view // SwiftUI, or set an NSViewController
        savedByGhostUIWindow!.becomesKeyOnlyIfNeeded = true

    }
    
    func showPanel() {
        guard let button = statusItem.button, let buttonWindow = unsafe button.window else { return }
        let buttonFrame = buttonWindow.frame
        let panelSize = savedByGhostUIWindow!.frame.size

        let x = buttonFrame.midX - panelSize.width / 2
        let y = buttonFrame.minY - panelSize.height
        savedByGhostUIWindow!.setFrameOrigin(NSPoint(x: x, y: y))

        savedByGhostUIWindow!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "SavedByGhostStatusBarIcon")!
            icon.size = NSSize(width: 20, height: 20)
            icon.isTemplate = true
            button.image = icon
            button.action = #selector(togglePanel(_:))
            button.target = self
        }
        
        self.openAppWindow()
    }
    
    @objc func togglePanel(_ sender: AnyObject?) {
        if self.savedByGhostUIWindow == nil {
            self.openAppWindow()
        }
        if self.savedByGhostUIWindow!.isVisible {
            savedByGhostUIWindow!.close()
            savedByGhostUIWindow = nil
        } else {
            showPanel()
        }
     }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Stop the animation timer, if it is currently running
        if self.savedByGhostScreenSaverPreviewWindow != nil {
            (self.savedByGhostScreenSaverPreviewWindow!.contentView as! SavedByGhostView).stopAnimation()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if savedByGhostUIWindow != nil {
            savedByGhostUIWindow!.makeKeyAndOrderFront(nil)
        } else {
            self.openAppWindow()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

}
