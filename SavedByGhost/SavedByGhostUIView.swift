//
//  SavedByGhostUIView.swift
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

import PaperSaverKit

import SwiftUI

struct SavedByGhostUIView: View {
        
    @StateObject private var pluginManager: SavedByGhostPluginManager = SavedByGhostPluginManager()

    @State private var setAsGlobalInProgress: Bool = false
    
    @State private var currentConfig = SavedByGhostConfiguration.shared!
    
    @State private var uiNeedsStateNotificationObserver: NSObjectProtocol!
    
    @State private var closeButtonHovered: Bool = false
    @State private var closeButtonBaseColor: Color = Color(red: 255.0 / 255.0, green: 92.0 / 255.0, blue: 96.0 / 255.0)
    
    private var videoView: SavedByGhostVideoView!
    
    init() {
        self.videoView = SavedByGhostVideoView(initialForegroundColor: SavedByGhostColorManager.foregroundColorFor(name: self.currentConfig.currentForegroundColor)!.color)
    }
    
    var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            HStack {
                
                // Close Button
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text("")
                }
                .buttonStyle(.accessoryBar)
                .frame(width: 14, height: 14)
                .background(self.closeButtonBaseColor)
                .cornerRadius(.infinity)
                .padding()
                .onHover { hovering in
                    self.closeButtonHovered = hovering
                }
                .overlay {
                    if self.closeButtonHovered {
                        Image(systemName: "xmark")
                            .resizable()
                            .fontWeight(.black)
                            .opacity(0.65)
                            .scaledToFit()
                            .frame(width: 8, height: 8)
                            .allowsHitTesting(false)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }, label: {
                    Image(systemName: "info.circle")
                        .resizable()
                        .frame(width: 16, height: 16)
                })
                .frame(width: 16, height: 16)
                .buttonStyle(.accessoryBar)
                .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                .padding()
                
            }
            .frame(maxWidth: .infinity)

            VStack {
                
                Spacer()
                
                self.videoView
                    .frame(width: 196.0, height: 196.0)
                
                Text("SavedByGhost")
                    .font(Font.system(size: 36.0, weight: .bold))
                    .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                    .padding(.bottom, 5)
                
                Text("A Scary Screen Saver")
                    .font(Font.system(size: 14.0, weight: .thin))
                    .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                
                Spacer()
                
                HStack(spacing: 20) {
                    
                    VStack {
                        
                        Label(title: {
                            Text(self.pluginManager.isInstalled ? "Installed" : "Not installed")
                                .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                        }, icon: {
                            Image(systemName: "circlebadge.fill")
                                .foregroundStyle(self.pluginManager.isInstalled ? Color.green : Color.red)
                        })
                        
                        Divider()
                            .padding([.top, .bottom], 10)
                            .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                        
                        Button(action: {
                            if self.pluginManager.isInstalled {
                                try? self.pluginManager.uninstall()
                            } else {
                                try? self.pluginManager.install()
                            }
                        }, label: {
                            Text(self.pluginManager.isInstalled ? "Uninstall" : "Install")
                        })
                        .disabled(self.setAsGlobalInProgress)
                        .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                        .buttonStyle(.borderedProminent)
                        
                    }
                    
                    VStack {
                        
                        Label(title: {
                            Text(self.pluginManager.isActiveScreensaver ? "Screensaver active" : "Screensaver inactive")
                                .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                        }, icon: {
                            Image(systemName: "circlebadge.fill")
                                .foregroundStyle(self.pluginManager.isActiveScreensaver ? Color.green : Color.red)
                        })
                        
                        Divider()
                            .padding([.top, .bottom], 10)
                            .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                        
                        if self.setAsGlobalInProgress {
                            Button(action: {
                                Task {
                                    self.setAsGlobalInProgress = true
                                    await self.pluginManager.enableAsScreensaver()
                                    self.setAsGlobalInProgress = false
                                }
                            }, label: {
                                Text("Setting Screensaver...")
                            })
                            .disabled(self.pluginManager.isActiveScreensaver || self.setAsGlobalInProgress)
                            .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                            .buttonStyle(.bordered)
                        } else {
                            Button(action: {
                                Task {
                                    self.setAsGlobalInProgress = true
                                    await self.pluginManager.enableAsScreensaver()
                                    self.setAsGlobalInProgress = false
                                }
                            }, label: {
                                Text(self.pluginManager.isActiveScreensaver ? "Already set" : "Set as default")
                            })
                            .disabled(self.pluginManager.isActiveScreensaver || self.setAsGlobalInProgress)
                            .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                            .buttonStyle(.bordered)
                        }
                        
                    }
                    
                }
                .padding([.leading, .trailing], 20)
                
                Spacer()
                
                VStack(spacing: 15) {
                    
                    Button("Open Screen Saver Settings", action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    })
                    .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                    
                    Button("Preview Screen Saver", action: {
                        (NSApplication.shared.delegate as! SavedByGhostAppDelegate).openScreenSaverWindow()
                    })
                    .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()))
                    
                }
                .padding([.bottom, .top], 15.0)
                
                Spacer()
                
                Text(self.pluginManager.installedVersion != nil ? "Installed version: \(self.pluginManager.installedVersion!)" : "Installed version: Unknown")
                    .font(Font.system(size: 12, weight: .light))
                    .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()).opacity(0.15))
                Text(self.pluginManager.embeddedVersion != nil ? "Embedded version: \(self.pluginManager.embeddedVersion!)" : "Embedded version: Unknown")
                    .font(Font.system(size: 12, weight: .light))
                    .foregroundStyle(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.adaptiveTextColor()).opacity(0.15))
                
                Spacer()
                
            }
            .padding([.bottom, .top], 20)
            
        }
        .frame(minWidth: 400.0, maxWidth: 400.0, minHeight: 600.0, maxHeight: 600.0)
        .background(Color(SavedByGhostColorManager.backgroundColorFor(name: currentConfig.currentBackgroundColor)!.color))
        .task {
            self.uiNeedsStateNotificationObserver = NotificationCenter.default.addObserver(forName: SavedByGhostUtils.SavedByGhostUINeedsStateReloadNotification, object: nil, queue: .main, using: { _ in
                Task { @MainActor in
                    self.currentConfig = SavedByGhostConfiguration.shared
                    self.videoView.manuallyUpdate()
                }
            })
        }
        .onDisappear {
            self.videoView.stopAnimation()
        }
    }
}

#Preview {
    SavedByGhostUIView()
}
