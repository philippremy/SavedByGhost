//
//  SavedByGhostView.swift
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
import ScreenSaver
import SwiftUI

// MARK: - ASCII rendering mode

/// Encapsulates everything the old `SavedByGhostView` did for ASCII-art mode:
/// owning the `GhostSaverRenderer`, prerendering frames, advancing the frame
/// index, and drawing into a dirty rect. Kept separate so it can be installed
/// or torn down independently of the SwiftUI ("XYZ") mode.
@MainActor
final class ASCIIRenderingController {

    private(set) var renderer: GhostSaverRenderer
    private var frameIndex: Int32 = 0
    private var backgroundColorName: String

    init?(foregroundColorName: String, backgroundColorName: String) {
        guard let color = SavedByGhostColorManager.foregroundColorFor(name: foregroundColorName)?.color,
              let renderer = GhostSaverRenderer(color) else {
            return nil
        }
        self.renderer = renderer
        self.backgroundColorName = backgroundColorName
    }

    /// Prerenders frames for the given bounds. Call before installing/swapping
    /// this controller in, so the first draw doesn't stall.
    func prerenderFrames(_ bounds: NSRect) {
        renderer.prerenderFrames(bounds)
    }

    func resetFrameIndex() {
        frameIndex = 0
    }

    func updateBackgroundColorName(_ name: String) {
        backgroundColorName = name
    }

    /// Draws the current frame into `dirtyRect` and advances the frame index.
    func draw(in dirtyRect: NSRect, bounds: NSRect) {
        SavedByGhostColorManager.backgroundColorFor(name: backgroundColorName)!.color.set()
        dirtyRect.fill()

        let prerenderedImage: NSImage = renderer.getPrerenderedImage(for: frameIndex)

        let imageSize: NSSize = prerenderedImage.size
        let drawRect: NSRect = NSMakeRect(
            (bounds.size.width  - imageSize.width)  / 2,
            (bounds.size.height - imageSize.height) / 2,
            imageSize.width,
            imageSize.height
        )

        prerenderedImage.draw(in: drawRect, from: NSZeroRect, operation: .sourceOver, fraction: 1.0)

        frameIndex += 1
        if frameIndex == FRAME_COUNT {
            frameIndex = 0
        }
    }
}

// MARK: - SwiftUI fallback mode

/// Placeholder SwiftUI view shown when the configuration says not to use
/// ASCII rendering. Intentionally minimal for now — fill in the real
/// presentation later.
struct SavedByGhostVideoWrapper: View {
    
    private var videoView: SavedByGhostVideoView!
    @State private var currentConfig = SavedByGhostConfiguration.shared!
    @State private var uiNeedsStateNotificationObserver: NSObjectProtocol!
    
    init() {
        self.videoView = SavedByGhostVideoView(initialForegroundColor: SavedByGhostColorManager.foregroundColorFor(name: self.currentConfig.currentForegroundColor)!.color)
    }
    
    var body: some View {
        
        ZStack {
         
            self.videoView
                .frame(width: 650.0, height: 650.0)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(SavedByGhostColorManager.backgroundColorFor(name: self.currentConfig.currentBackgroundColor)!.color))
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

// MARK: - Coordinator

@MainActor
public class SavedByGhostView: ScreenSaverView {

    private var internalTimer: Timer?
    private let fps: Double = 1.0 / 30.0

    private var currentConfig: SavedByGhostConfiguration = SavedByGhostConfiguration.shared

    // The two interchangeable render modes. Exactly one is "active" at a time,
    // matching `currentConfig.usesASCIIArt`.
    private var asciiController: ASCIIRenderingController?
    private var swiftUIHostingView: NSHostingView<SavedByGhostVideoWrapper>?

    private var uiNeedsStateNotificationObserver: NSObjectProtocol?

    public func setup() -> Self {
        installActiveMode(for: currentConfig)

        self.uiNeedsStateNotificationObserver = NotificationCenter.default.addObserver(
            forName: SavedByGhostUtils.SavedByGhostUINeedsStateReloadNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.handleConfigReload()
                }
            }
        )
        return self
    }

    @MainActor
    deinit {
        if let observer = uiNeedsStateNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Notification handling

    private func handleConfigReload() {
        let newConfig = SavedByGhostConfiguration.shared!

        // If the rendering mode itself changed, tear down the old mode and
        // install the new one fresh.
        if newConfig.usesASCIIArt != currentConfig.usesASCIIArt {
            currentConfig = newConfig
            installActiveMode(for: newConfig)
            requestRerender()
            return
        }

        currentConfig = newConfig

        if newConfig.usesASCIIArt {
            updateASCIIControllerForCurrentConfig()
        }

        requestRerender()
    }

    /// Rebuilds the ASCII renderer in place (e.g. foreground color changed)
    /// without switching modes.
    private func updateASCIIControllerForCurrentConfig() {
        guard let newController = ASCIIRenderingController(
            foregroundColorName: currentConfig.currentForegroundColor,
            backgroundColorName: currentConfig.currentBackgroundColor
        ) else {
            return
        }
        newController.prerenderFrames(self.bounds) // prerender BEFORE swap
        newController.resetFrameIndex()
        self.asciiController = newController
    }

    // MARK: Mode installation

    /// Installs whichever mode `config` calls for, tearing down the other one
    /// if it was previously active.
    private func installActiveMode(for config: SavedByGhostConfiguration) {
        if config.usesASCIIArt {
            removeSwiftUIMode()
            installASCIIMode(for: config)
        } else {
            removeASCIIMode()
            installSwiftUIMode()
        }
    }

    private func installASCIIMode(for config: SavedByGhostConfiguration) {
        guard let controller = ASCIIRenderingController(
            foregroundColorName: config.currentForegroundColor,
            backgroundColorName: config.currentBackgroundColor
        ) else {
            return
        }
        controller.prerenderFrames(self.bounds)
        self.asciiController = controller
    }

    private func removeASCIIMode() {
        asciiController = nil
    }

    private func installSwiftUIMode() {
        let hostingView = NSHostingView(rootView: SavedByGhostVideoWrapper())
        hostingView.frame = self.bounds
        hostingView.autoresizingMask = [.width, .height]
        self.addSubview(hostingView)
        self.swiftUIHostingView = hostingView
    }

    private func removeSwiftUIMode() {
        swiftUIHostingView?.removeFromSuperview()
        swiftUIHostingView = nil
    }

    // MARK: Rendering / lifecycle

    private func requestRerender() {
        self.setNeedsDisplay(self.frame)
    }

    public override func stopAnimation() {
        self.internalTimer?.invalidate()
        super.stopAnimation()
    }

    public override func viewDidMoveToWindow() {
        asciiController?.prerenderFrames(self.bounds)

        self.internalTimer = Timer(timeInterval: self.fps, repeats: true, block: { [weak self] _ in
            Task { @MainActor in
                self?.requestRerender()
            }
        })
        RunLoop.main.add(self.internalTimer!, forMode: .common)
    }

    public override func draw(_ dirtyRect: NSRect) {
        // Only the ASCII path needs manual drawing; the SwiftUI path renders
        // itself via its hosting view.
        guard currentConfig.usesASCIIArt, let asciiController else { return }
        asciiController.draw(in: dirtyRect, bounds: self.bounds)
    }
}
