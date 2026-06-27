//
//  SavedByGhostScreenSaverConfigurationViewController.swift
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

import ScreenSaver
import SwiftUI


@objc(SavedByGhostScreenSaverConfigurationViewController)
class SavedByGhostScreenSaverConfigurationViewController : ScreenSaverConfigurationViewController {

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {

        // Fetch UserDefaults or use standard

        let savedByGhostConfigurationView = SavedByGhostScreenSaverConfigurationView(
            abortButtonCallback: {
                // Close the sheet, do nothing
                self.configureSheetDidEnd()
            },
            confirmButtonCallback: { foregroundColor, backgroundColor, usesASCII in

                // Set in global config
                SavedByGhostConfiguration.shared.currentBackgroundColor = backgroundColor.name
                SavedByGhostConfiguration.shared.currentForegroundColor = foregroundColor.name
                SavedByGhostConfiguration.shared.usesASCIIArt = usesASCII

                // Write in global config
                SavedByGhostUtils.updateConfigWith(value: SavedByGhostConfiguration.shared)

                self.configureSheetDidEnd()

            }
        )

        let swiftUIBridge = NSHostingController(rootView: savedByGhostConfigurationView)
        self.view = swiftUIBridge.view
        self.view.wantsLayer = true

    }

}
