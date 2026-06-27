//
//  SavedByGhostScreenSaverViewController.swift
//  SavedByGhostScreenSaver
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

import AppKit
import ScreenSaver

@objc(SavedByGhostScreenSaverViewController)
class SavedByGhostScreenSaverViewController : ScreenSaverViewController {
    
    var screenSaverView: SavedByGhostView?
    
    /// Called by the framework to create the view.
    override func loadView() {

        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let isPreview = frame.width < 400

        screenSaverView = SavedByGhostView(frame: frame, isPreview: isPreview)!.setup()
        self.view = self.screenSaverView!
        
    }
    
}
