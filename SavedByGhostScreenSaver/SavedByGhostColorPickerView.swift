//
//  SavedByGhostColorPickerView.swift
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

import SwiftUI

struct SavedByGhostColorPickerView: View {
    
    @EnvironmentObject var currentSelectedColor: SavedByGhostColor
    
    let availableColors: OrderedDictionaryWrapper<String, SavedByGhostColor>
    let currentBackgroundColor: SavedByGhostColor
    let updateCallback: (SavedByGhostColor) -> Void
    
    var body: some View {
        
        ScrollView {
            
            VStack(alignment: .leading) {
                
                ForEach(self.availableColors.intoOrderedArray()) { element in
                    
                    Button(action: {
                        self.updateCallback(element.value)
                    }) {
                        
                        HStack {
                            
                            RoundedRectangle(cornerRadius: 5)
                                .foregroundStyle(Color(element.value.color))
                                .frame(width: 32, height: 32)
                                .overlay(content: element.value.name == self.currentSelectedColor.name ? {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                } : {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color(self.currentBackgroundColor.adaptiveTextColor()), lineWidth: 1)
                                })
                            
                            Text(element.value.name)
                                .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            
                        }
                        .padding(.all, 2)
                        
                    }
                    .buttonStyle(.plain)
                    
                }
                
            }
            .padding()
            
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: 200, maxHeight: 250)
        .background(Color(self.currentBackgroundColor.color))
        
    }
}

#Preview {
    SavedByGhostColorPickerView(availableColors: SavedByGhostColorManager.allBackgroundColors(), currentBackgroundColor: SavedByGhostColorManager.backgroundColorFor(name: "Classic")!, updateCallback: { _ in })
        .environmentObject(SavedByGhostColorManager.backgroundColorFor(name: "Classic")!)
}

