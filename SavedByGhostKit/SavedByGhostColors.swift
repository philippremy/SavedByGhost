//
//  SavedByGhostColors.swift
//  SavedByGhostKit
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
import Combine
import Foundation

@MainActor
@objc public class SavedByGhostColor : NSObject, Identifiable, ObservableObject {
    
    public init(color: NSColor, name: String) {
        self.color = color
        self.name = name
    }

    func isLight() -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        unsafe self.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5
    }

    public func adaptiveTextColor() -> NSColor {
        isLight() ? .black : .white
    }
    
    public let color: NSColor
    public let name: String
}

public final class SavedByGhostColorManager {
    
    @MainActor
    static let AVAILABLE_BACKGROUND_COLORS: OrderedDictionaryWrapper<String, SavedByGhostColor> = OrderedDictionaryWrapper(dict: [
        "Classic" : SavedByGhostColor(color: NSColor(red: 30.0/255.0, green: 39.0/255.0, blue: 46.0/255.0, alpha: 1.0), name: "Classic"),
        "Obsidian": SavedByGhostColor(color: NSColor(red: 17.0/255.0, green: 17.0/255.0, blue: 27.0/255.0, alpha: 1.0), name: "Obsidian"),
        "Onyx": SavedByGhostColor(color: NSColor(red: 24.0/255.0, green: 24.0/255.0, blue: 37.0/255.0, alpha: 1.0), name: "Onyx"),
        "Midnight": SavedByGhostColor(color: NSColor(red: 30.0/255.0, green: 30.0/255.0, blue: 46.0/255.0, alpha: 1.0), name: "Midnight"),
        "Graphite": SavedByGhostColor(color: NSColor(red: 49.0/255.0, green: 50.0/255.0, blue: 68.0/255.0, alpha: 1.0), name: "Graphite"),
        "Charcoal": SavedByGhostColor(color: NSColor(red: 69.0/255.0, green: 71.0/255.0, blue: 90.0/255.0, alpha: 1.0), name: "Charcoal"),
        "Stone": SavedByGhostColor(color: NSColor(red: 88.0/255.0, green: 91.0/255.0, blue: 112.0/255.0, alpha: 1.0), name: "Stone"),
        "Steel": SavedByGhostColor(color: NSColor(red: 108.0/255.0, green: 112.0/255.0, blue: 134.0/255.0, alpha: 1.0), name: "Steel"),
    ])
    
    @MainActor
    static let AVAILABLE_FOREGROUND_COLORS: OrderedDictionaryWrapper<String, SavedByGhostColor> = OrderedDictionaryWrapper(dict: [
        "Classic" : SavedByGhostColor(color: NSColor(red: 0.0, green: 0.0, blue: 0.898, alpha: 1.0), name: "Classic"),
        "Rosewater" : SavedByGhostColor(color: NSColor(red: 220.0/255.0, green: 138.0/255.0, blue: 120.0/255.0, alpha: 1.0), name: "Rosewater"),
        "Flamingo" : SavedByGhostColor(color: NSColor(red: 221.0/255.0, green: 120.0/255.0, blue: 120.0/255.0, alpha: 1.0), name: "Flamingo"),
        "Pink" : SavedByGhostColor(color: NSColor(red: 234.0/255.0, green: 118.0/255.0, blue: 203.0/255.0, alpha: 1.0), name: "Pink"),
        "Mauve" : SavedByGhostColor(color: NSColor(red: 136.0/255.0, green: 57.0/255.0, blue: 239.0/255.0, alpha: 1.0), name: "Mauve"),
        "Red" : SavedByGhostColor(color: NSColor(red: 210.0/255.0, green: 15.0/255.0, blue: 57.0/255.0, alpha: 1.0), name: "Red"),
        "Maroon" : SavedByGhostColor(color: NSColor(red: 230.0/255.0, green: 69.0/255.0, blue: 83.0/255.0, alpha: 1.0), name: "Maroon"),
        "Peach" : SavedByGhostColor(color: NSColor(red: 254.0/255.0, green: 100.0/255.0, blue: 11.0/255.0, alpha: 1.0), name: "Peach"),
        "Yellow" : SavedByGhostColor(color: NSColor(red: 223.0/255.0, green: 142.0/255.0, blue: 29.0/255.0, alpha: 1.0), name: "Yellow"),
        "Green" : SavedByGhostColor(color: NSColor(red: 64.0/255.0, green: 160.0/255.0, blue: 43.0/255.0, alpha: 1.0), name: "Green"),
        "Teal" : SavedByGhostColor(color: NSColor(red: 23.0/255.0, green: 146.0/255.0, blue: 153.0/255.0, alpha: 1.0), name: "Teal"),
        "Sky" : SavedByGhostColor(color: NSColor(red: 4.0/255.0, green: 165.0/255.0, blue: 229.0/255.0, alpha: 1.0), name: "Sky"),
        "Sapphire" : SavedByGhostColor(color: NSColor(red: 32.0/255.0, green: 159.0/255.0, blue: 181.0/255.0, alpha: 1.0), name: "Sapphire"),
        "Blue" : SavedByGhostColor(color: NSColor(red: 30.0/255.0, green: 102.0/255.0, blue: 245.0/255.0, alpha: 1.0), name: "Blue"),
        "Lavender" : SavedByGhostColor(color: NSColor(red: 114.0/255.0, green: 135.0/255.0, blue: 253.0/255.0, alpha: 1.0), name: "Lavender"),
    ])
    
    @MainActor
    @objc public static func backgroundColorFor(name: String) -> SavedByGhostColor? {
        AVAILABLE_BACKGROUND_COLORS[name]
    }
    
    @MainActor
    @objc public static func foregroundColorFor(name: String) -> SavedByGhostColor? {
        AVAILABLE_FOREGROUND_COLORS[name]
    }
    
    @MainActor
    public static func allBackgroundColors() -> OrderedDictionaryWrapper<String, SavedByGhostColor> {
        self.AVAILABLE_BACKGROUND_COLORS
    }
    
    @MainActor
    public static func allForegroundColors() -> OrderedDictionaryWrapper<String, SavedByGhostColor> {
        self.AVAILABLE_FOREGROUND_COLORS
    }
    
}
