//
//  SavedByGhost.swift
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

import AppKit
import Foundation

@main
class SavedByGhost {
    
    static let shared: SavedByGhost = SavedByGhost()
    
    static func main() {
        let app = NSApplication.shared
        let delegate = SavedByGhostAppDelegate()
        let menu = self.shared.buildAppMenu()
        app.delegate = delegate
        app.mainMenu = menu
        app.setActivationPolicy(.accessory)
        app.run()
    }
    
    func buildAppMenu() -> NSMenu {

        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()

        appMenu.addItem(NSMenuItem(
            title: "About SavedByGhost",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        
        appMenu.addItem(NSMenuItem.separator())
        
        let previewItem = NSMenuItem(
            title: "Preview SavedByGhost",
            action: #selector(SavedByGhostAppDelegate.openScreenSaverWindow),
            keyEquivalent: "p",
        );
        previewItem.target = NSApplication.shared.delegate
        appMenu.addItem(previewItem)

        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(NSMenuItem(
            title: "Quit SavedByGhost",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        appMenuItem.submenu = appMenu

        return mainMenu
    }
    
}
