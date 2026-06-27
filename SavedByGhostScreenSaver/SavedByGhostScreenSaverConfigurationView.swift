//
//  SavedByGhostScreenSaverConfigurationView.swift
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

struct SavedByGhostScreenSaverConfigurationView: View {

    let abortButtonCallback: () -> Void
    let confirmButtonCallback: (_ foregroundColor: SavedByGhostColor, _ backgroundColor: SavedByGhostColor, _ usesASCII: Bool) -> Void

    @State var isBackgroundColorPickerOpen: Bool = false
    @State var isForegroundColorPickerOpen: Bool = false

    @State var currentBackgroundColor: SavedByGhostColor = SavedByGhostColorManager.backgroundColorFor(name: SavedByGhostConfiguration.shared.currentBackgroundColor)!
    @State var currentForegroundColor: SavedByGhostColor = SavedByGhostColorManager.foregroundColorFor(name: SavedByGhostConfiguration.shared.currentForegroundColor)!
    @State var usesASCIIArt: Bool = SavedByGhostConfiguration.shared.usesASCIIArt

    var videoView: SavedByGhostVideoView!

    public init(abortButtonCallback: @escaping () -> Void, confirmButtonCallback: @escaping (_: SavedByGhostColor, _: SavedByGhostColor, _: Bool) -> Void) {
        self.abortButtonCallback = abortButtonCallback
        self.confirmButtonCallback = confirmButtonCallback
        self.videoView = SavedByGhostVideoView(initialForegroundColor: self.currentForegroundColor.color)
    }

    var body: some View {

        ZStack {

            VStack(spacing: 10) {

                Spacer()

                self.videoView
                    .frame(width: 96.0, height: 96.0)

                Text("SavedByGhost Settings")
                    .font(Font.system(size: 16.0, weight: .bold))
                    .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))

                Spacer()


                    Grid(horizontalSpacing: 25.0, verticalSpacing: 10.0) {

                    GridRow {

                        Text("Background Color: ")
                            .gridCellAnchor(.leading)
                            .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            .font(Font.system(size: 12.0, weight: .light))

                        Button(action: { self.isBackgroundColorPickerOpen.toggle() }) {
                            Text(self.currentBackgroundColor.name)
                                .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()).opacity(0.85))
                                .frame(minWidth: 80.0)
                        }
                        .buttonStyle(.accessoryBar)
                        .background(Color(nsColor: currentBackgroundColor.color))
                        .cornerRadius(2.5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2.5)
                                .stroke(Material.regular, lineWidth: 1.0)
                        )
                        .popover(isPresented: self.$isBackgroundColorPickerOpen, arrowEdge: .leading) {
                            SavedByGhostColorPickerView(availableColors: SavedByGhostColorManager.allBackgroundColors(), currentBackgroundColor: self.currentBackgroundColor, updateCallback: {
                                color in
                                self.currentBackgroundColor = color
                                SavedByGhostConfiguration.shared.currentBackgroundColor = color.name
                                self.videoView.manuallyUpdate()
                            })
                                .environmentObject(self.currentBackgroundColor)
                        }

                    }

                    GridRow {

                        Text("Ghost Color:")
                            .gridCellAnchor(.leading)
                            .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            .font(Font.system(size: 12.0, weight: .light))

                        Button(action: { self.isForegroundColorPickerOpen.toggle() }) {
                            Text(self.currentForegroundColor.name)
                                .foregroundStyle(Color(self.currentForegroundColor.adaptiveTextColor()).opacity(0.85))
                                .frame(minWidth: 80.0)
                        }
                        .buttonStyle(.accessoryBar)
                        .background(Color(nsColor: currentForegroundColor.color))
                        .cornerRadius(2.5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2.5)
                                .stroke(Material.regular, lineWidth: 1.0)
                        )
                        .popover(isPresented: self.$isForegroundColorPickerOpen, arrowEdge: .leading) {
                            SavedByGhostColorPickerView(availableColors: SavedByGhostColorManager.allForegroundColors(), currentBackgroundColor: self.currentBackgroundColor, updateCallback: {
                                color in
                                self.currentForegroundColor = color
                                SavedByGhostConfiguration.shared.currentForegroundColor = color.name
                                self.videoView.manuallyUpdate()
                            })
                                .environmentObject(self.currentForegroundColor)
                        }

                    }

                }

                Spacer()

                Toggle(isOn: self.$usesASCIIArt, label: {
                    Text("Use the ASCII variant")
                        .padding(.leading, 10)
                        .foregroundStyle(Color(nsColor: self.currentBackgroundColor.adaptiveTextColor()))
                })

                Spacer()

                HStack(spacing: 50) {

                    if #available(macOS 26, *) {
                        Button("Apply", action: {
                            self.confirmButtonCallback(self.currentForegroundColor, self.currentBackgroundColor, self.usesASCIIArt)
                        })
                            .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            .buttonStyle(.glassProminent)
                    } else {
                        Button("Apply", action: {
                            self.confirmButtonCallback(self.currentForegroundColor, self.currentBackgroundColor, self.usesASCIIArt)
                        })
                            .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            .buttonStyle(.borderedProminent)
                    }

                    if #available(macOS 26, *) {
                        Button("Close", action: self.abortButtonCallback)
                            .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            .buttonStyle(.glass)
                    } else {
                        Button("Close", action: self.abortButtonCallback)
                            .foregroundStyle(Color(self.currentBackgroundColor.adaptiveTextColor()))
                            .buttonStyle(.bordered)
                    }

                }

                Spacer()

            }
            .frame(
              maxWidth: .infinity,
            )

        }
        .frame(minWidth: 400.0, maxWidth: 400.0, minHeight: 350.0, maxHeight: 350.0)
        .background(Color(self.currentBackgroundColor.color))
        .onDisappear {
            self.videoView.stopAnimation()
        }
    }

}

#Preview {
    SavedByGhostScreenSaverConfigurationView(
        abortButtonCallback: {},
        confirmButtonCallback: { _, _, _ in },
    )
}
