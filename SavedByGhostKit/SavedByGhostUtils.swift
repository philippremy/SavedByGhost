//
//  SavedByGhostUtils.swift
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

internal import OrderedCollections

import CxxStdlib
import Foundation
import OSLog
import UniformTypeIdentifiers
import ScreenSaver

public final class SavedByGhostUtils : NSObject {
    
    static let EMBEDDED_DATA_NAMES: [String] = [
        "SavedByGhostVideo",
        "SavedByGhostFont",
    ]
    
    @MainActor
    static var EXTRACTED_DATA_PATHS: [String : URL?] = [
        "SavedByGhostVideo" : nil,
        "SavedByGhostFont" : nil
    ]
    
    static let SavedByGhostAppGroupIdentifier = "group.de.philippremy.SavedByGhost"
    static let SavedByGhostConfigDidChangeNotification = Notification.Name("de.philippremy.SavedByGhost.Config.DidChangeNotification")
    public static let SavedByGhostUINeedsStateReloadNotification = Notification.Name("de.philippremy.SavedByGhost.UINeedsStateReload")
    static let SavedByGhostApplicationSupportDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SavedByGhostAppGroupIdentifier)!
        .appending(path: "Library")
        .appending(path: "Application Support")
    static let SavedByGhostPreferencesDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SavedByGhostAppGroupIdentifier)!
        .appending(path: "Library")
        .appending(path: "Preferences")
    static let SavedByGhostUserConfigFile = SavedByGhostPreferencesDir.appending(path: "de.philippremy.SavedByGhost.UserConfig.plist")
    
    // To retain the observer
    @MainActor
    static var SavedByGhostConfigDidChangeObserver: NSObjectProtocol!
    
    @MainActor
    @objc public static func extractBundledAssets() {
        
        let appExtractedAssetsFolder = self.SavedByGhostApplicationSupportDir.appending(component: "ExtractedAssets");
        
        try! FileManager.default.createDirectory(at: appExtractedAssetsFolder, withIntermediateDirectories: true)
        
        for embedded_item_name in EMBEDDED_DATA_NAMES {
            
            let dataAsset = NSDataAsset(name: embedded_item_name, bundle: Bundle(for: self))
            let dataAssetExtractionPath = appExtractedAssetsFolder.appending(path: "\(dataAsset!.name)").appendingPathExtension(for: UTType(dataAsset!.typeIdentifier)!)
            
            defer {
                EXTRACTED_DATA_PATHS[embedded_item_name] = dataAssetExtractionPath
            }
            
            guard !SavedByGhost.cxxCheckIfFileExists(std.string(dataAssetExtractionPath.path(percentEncoded: false))) else { continue }
            

            try! dataAsset!.data.write(to: dataAssetExtractionPath, options: .atomic)
            
        }
        
    }
    
    @MainActor
    @objc public static func urlForExtractedAsset(named: String) -> URL? {
        EXTRACTED_DATA_PATHS[named] ?? nil
    }
    
    @MainActor
    @objc public static func fetchCurrentConfiguration() {
        
        do {
            
            if !SavedByGhost.cxxCheckIfFileExists(std.string(SavedByGhostUserConfigFile.path(percentEncoded: false)))  {
                // Write a default user config
                self.updateConfigWith(value: SavedByGhostConfiguration.DEFAULT_DATA)
            }
            
            let propertyListData = try Data(contentsOf: self.SavedByGhostUserConfigFile)
            let deserializedInstance = try PropertyListDecoder().decode(SavedByGhostConfiguration.self, from: propertyListData)
            SavedByGhostConfiguration.shared = deserializedInstance
            
        } catch {
            Logger().fault("Failed to deserialize user config: \(error) from \(self.SavedByGhostUserConfigFile)")
            SavedByGhostConfiguration.shared = SavedByGhostConfiguration.DEFAULT_DATA
        }
        
    }
    
    @MainActor
    @objc public static func updateConfigWith(value: SavedByGhostConfiguration) {
        
        do {
            let propertyListConfig = try PropertyListEncoder().encode(value)
            try propertyListConfig.write(to: self.SavedByGhostUserConfigFile)
            DistributedNotificationCenter.default().postNotificationName(self.SavedByGhostConfigDidChangeNotification, object: nil, deliverImmediately: true)
        } catch {
            Logger().fault("Failed to save user config: \(error) to \(self.SavedByGhostUserConfigFile.path())")
        }
        
    }
    
    @MainActor
    @objc public static func subscribeToObservers() {
        
        // Subscribe to config changes
        self.SavedByGhostConfigDidChangeObserver = DistributedNotificationCenter.default().addObserver(forName: self.SavedByGhostConfigDidChangeNotification, object: nil, queue: .main, using: { _notification in
            Task { @MainActor in
                self.fetchCurrentConfiguration()
                NotificationCenter.default.post(name: self.SavedByGhostUINeedsStateReloadNotification, object: nil)
            }
        })
        
    }
    
}

public final class SavedByGhostConfiguration: NSObject, Codable {

    @MainActor @objc public static var shared: SavedByGhostConfiguration!
    
    @MainActor @objc public static let DEFAULT_DATA = SavedByGhostConfiguration(
        currentForegroundColor: "Classic",
        currentBackgroundColor: "Classic",
        usesASCIIArt: true,
    )
    
    private init(currentForegroundColor: String, currentBackgroundColor: String, usesASCIIArt: Bool) {
        self.currentForegroundColor = currentForegroundColor
        self.currentBackgroundColor = currentBackgroundColor
        self.usesASCIIArt = usesASCIIArt
    }
    
    public var currentForegroundColor: String
    public var currentBackgroundColor: String
    public var usesASCIIArt: Bool
    
}

public final class OrderedDictionaryWrapper<Key, Value> where Key: Hashable {
    
    init(dict: OrderedDictionary<Key, Value>) {
        self.dict = dict
    }
    
    subscript(_ key: Key) -> Value? {
        self.dict[key]
    }
    
    let dict: OrderedDictionary<Key, Value>
    
    public struct KeyValueTuple : Identifiable {
        
        public let id: Key
        public let value: Value
        
        static func from(_ element: OrderedDictionary<Key, Value>.Element) -> Self {
            Self(id: element.key, value: element.value)
        }
        
    }
    
    public func intoOrderedArray() -> [KeyValueTuple] {
        self.dict.elements.map({ element in
            KeyValueTuple.from(element)
        })
    }
    
}

extension OrderedDictionaryWrapper : Sendable where Key: Sendable, Value: Sendable {}
