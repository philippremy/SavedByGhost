//
//  GhostChromaView.swift
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

import AVKit
import Foundation
import SwiftUI

@unsafe @preconcurrency import Metal
@unsafe @preconcurrency import QuartzCore

@MainActor
public final class GhostChromaView: NSView {

    // MARK: Metal

    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var shaders: MTLLibrary!
    private var renderPipelineState: MTLRenderPipelineState!

    // MARK: Video

    private let videoAsset: AVURLAsset = AVURLAsset(url: SavedByGhostUtils.urlForExtractedAsset(named: "SavedByGhostVideo")!)
    private var videoPlayerItem: AVPlayerItem!
    private var videoPlayerOutput: AVPlayerItemVideoOutput!
    private var videoPlayer: AVPlayer!
    private var videoPlayerDidEndObserver: NSObjectProtocol!
    private var videoPlayerIsPlayingForward: Bool = true
    private var videoPlayerStatusObservation: NSKeyValueObservation!

    /// Per-instance CADisplayLink (via NSView.displayLink(target:selector:),
    /// macOS 14+) instead of a shared main-thread Timer or raw CVDisplayLink.
    /// Each display link ties to actual vsync timing for the screen the view
    /// is on, so multiple GhostChromaView instances no longer serialize
    /// through (and drift into lockstep on) the same RunLoop/Timer. Unlike
    /// CVDisplayLink, this AppKit-managed display link automatically
    /// suspends itself when the view isn't on a window/screen, and gives us
    /// a deterministic `invalidate()` for teardown — which is what
    /// CVDisplayLinkStop did not reliably give us (CPU usage could persist
    /// after stopAnimation()).
    private var displayLink: CADisplayLink?

    private var videoTextureCache: CVMetalTextureCache!

    private var foregroundColor: NSColor!

    /// Cached tint color, in `simd_float4` form, matched to the window's
    /// current color space. Recomputed only when the foreground color or the
    /// window's color space actually changes — not on every frame. Color
    /// matching via `usingColorSpace(_:)` does real work; doing it 30-60
    /// times a second for a value that's almost always unchanged was pure
    /// waste.
    private var cachedTintColor: simd_float4 = simd_float4(1, 1, 1, 1)

    /// Guards against issuing copyPixelBuffer(forItemTime:) calls while a
    /// seek is in flight. AVPlayerItemVideoOutput's internal buffer pool is
    /// not in a consistent state mid-seek, and continuing to pull frames
    /// during that window is what was producing the flicker/crash after
    /// playback reached the end and the loop seeked back.
    private var isSeeking: Bool = false

    /// Tracks whether a render is already in flight on the GPU, so we never
    /// kick off a second one before the first's completion handler has run.
    /// Replaces the old `waitUntilCompleted()` main-thread stall.
    private var isRenderInFlight: Bool = false

    // MARK: Pixel format

    /// Pixel format used for both the video frame textures and the layer's
    /// drawable.
    private let pixelFormat: MTLPixelFormat = .bgra8Unorm

    @MainActor
    deinit {
        if let videoPlayerDidEndObserver {
            NotificationCenter.default.removeObserver(videoPlayerDidEndObserver)
        }
        if let displayLink {
            displayLink.invalidate()
        }
    }

    // MARK: Backing layer

    /// Backs the view with a CAMetalLayer instead of a plain CALayer. We
    /// render straight into the layer's drawable and `present()` it — no
    /// CGImage, no CIContext, no CPU/GPU readback. This is the change that
    /// actually removes the extra render pass + sync point that was costing
    /// the ~40% CPU.
    public override func makeBackingLayer() -> CALayer {
        let metalLayer = CAMetalLayer()
        metalLayer.pixelFormat = self.pixelFormat
        // We are the sole writer of this layer's drawables every frame, and
        // never need to sample them back ourselves, so framebufferOnly can
        // stay true (the default) — this also keeps drawable allocation
        // cheaper than if we needed shader-read access on the drawable itself.
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = false
        // Avoid implicit animation when we present a new drawable every frame.
        metalLayer.actions = ["contents": NSNull()]
        return metalLayer
    }

    private var metalLayer: CAMetalLayer {
        guard let layer = self.layer as? CAMetalLayer else {
            fatalError("GhostChromaView's backing layer must be a CAMetalLayer")
        }
        return layer
    }

    // MARK: Setup

    func setup(withGhostColor: NSColor) -> Self {

        self.foregroundColor = withGhostColor

        self.wantsLayer = true

        self.device = MTLCreateSystemDefaultDevice()
        self.shaders = try! self.device.makeDefaultLibrary(bundle: Bundle(for: Self.self))

        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = self.shaders.makeFunction(name: "frameRenderVertex")
        renderPipelineDescriptor.fragmentFunction = self.shaders.makeFunction(name: "frameRenderFragment")
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = self.pixelFormat
        self.renderPipelineState = try! self.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        self.commandQueue = self.device.makeCommandQueue()

        self.metalLayer.device = self.device
        self.metalLayer.contentsScale = unsafe self.window?.backingScaleFactor ?? 2.0

        self.updateCachedTintColor()

        self.videoPlayerItem = AVPlayerItem(asset: self.videoAsset)
        self.videoPlayerStatusObservation = self.videoPlayerItem.observe(\.status, options: [.new]) { item, _ in
            switch item.status {
            case .failed:
                print("GhostChromaView: AVPlayerItem failed to load: \(item.error?.localizedDescription ?? "unknown error")")
                if let error = item.error as NSError? {
                    print("GhostChromaView: underlying error: \(error)")
                }
            case .readyToPlay:
                print("GhostChromaView: video item ready to play, duration: \(CMTimeGetSeconds(item.duration))")
            case .unknown:
                break
            @unknown default:
                break
            }
        }
        self.videoPlayer = AVPlayer(playerItem: self.videoPlayerItem)
        self.videoPlayer.playImmediately(atRate: 1.0)
        self.videoPlayerDidEndObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main, using: { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.beginLoopSeek()
                }
            }
        )

        self.videoPlayerOutput = AVPlayerItemVideoOutput(outputSettings: [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ])
        self.videoPlayerItem.add(self.videoPlayerOutput)

        if unsafe CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.videoTextureCache) != kCVReturnSuccess {
            fatalError("Failed to create CVMetalTextureCache!")
        }

        self.setupDisplayLink()

        return self
    }

    // MARK: Loop seeking

    /// One frame's worth of tolerance on either side of a loop-boundary seek,
    /// at the loop's own frame rate. Sample-accurate (zero-tolerance) seeking
    /// forces AVFoundation to discard and exactly rebuild in-flight read
    /// requests at the moment of the seek; for a seamless ping-pong loop a
    /// visually-imperceptible few-millisecond slop is fine and is dramatically
    /// cheaper and safer to request near playback boundaries.
    private static let loopSeekTolerance = CMTime(value: 1, timescale: 30)

    /// Called when the item finishes playing in either direction. Pauses the
    /// player before seeking (to let in-flight readahead/disk-read-scheduler
    /// work wind down rather than yanking the timeline out from under it),
    /// uses tolerant seeking instead of frame-exact seeking, and guards
    /// against a second loop boundary re-entering this method while a seek
    /// from the first one is still pending.
    private func beginLoopSeek() {
        // If a previous seek hasn't completed yet, don't issue another one on
        // top of it — the completion handler below will resume playback and
        // re-arm isSeeking = false once it's actually safe to do so.
        guard !self.isSeeking else { return }

        self.isSeeking = true
        self.videoPlayer.pause()
        self.videoPlayerIsPlayingForward.toggle()

        if self.videoPlayerIsPlayingForward {
            self.videoPlayer.seek(
                to: .zero,
                toleranceBefore: .zero,
                toleranceAfter: Self.loopSeekTolerance
            ) { [weak self] finished in
                Task { @MainActor in
                    guard let self else { return }
                    if finished {
                        self.videoPlayer.rate = 1
                    }
                    self.isSeeking = false
                }
            }
        } else {
            guard self.videoPlayerItem.duration.isNumeric else {
                // Couldn't resolve a duration to seek to; don't get stuck
                // refusing to pull frames forever.
                self.isSeeking = false
                return
            }
            self.videoPlayer.seek(
                to: self.videoPlayerItem.duration,
                toleranceBefore: Self.loopSeekTolerance,
                toleranceAfter: .zero
            ) { [weak self] finished in
                Task { @MainActor in
                    guard let self else { return }
                    if finished {
                        self.videoPlayer.rate = -1
                    }
                    self.isSeeking = false
                }
            }
        }
    }

    // MARK: CADisplayLink setup

    /// Creates (or recreates) the display link for whichever window/screen
    /// the view is currently attached to. Safe to call multiple times — any
    /// previous link is invalidated first. Must be called after the view has
    /// a window, since `NSView.displayLink(target:selector:)` resolves the
    /// screen from the view's current window.
    private func setupDisplayLink() {
        // Drop any previous link before creating a new one — e.g. if the
        // view moved to a different window/screen.
        displayLink?.invalidate()
        displayLink = nil

        guard unsafe self.window != nil else {
            // No window yet; viewDidMoveToWindow will call us again once
            // there is one.
            return
        }

        let link = self.displayLink(target: self, selector: #selector(displayLinkFired))
        // Matches the previous 30 fps cadence. preferred(maximum:minimum:preferred:)
        // lets the system pick within the range but biases toward our target.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    @objc private func displayLinkFired(_ sender: CADisplayLink) {
        self.renderAndPublishFrame()
    }

    /// Renders the current video frame (tinted by `foregroundColor` via the
    /// fragment shader) directly into the Metal layer's drawable and presents
    /// it. Must run on the main thread.
    private func renderAndPublishFrame() {
        // Don't touch the video output mid-seek — its internal buffer pool
        // isn't in a consistent state, and pulling frames here is what was
        // causing the flicker/crash right after the end-of-playback loop.
        guard !self.isSeeking else { return }

        // Don't start a second GPU render while one is still in flight. We
        // don't block the main thread with waitUntilCompleted(), so without
        // this guard a slow GPU frame could overlap with the next display
        // link tick.
        guard !self.isRenderInFlight else { return }

        guard let pixelBuffer = self.copyCurrentPixelBuffer() else { return }
        self.renderFrameToDrawable(pixelBuffer: pixelBuffer)
    }

    // MARK: Rendering

    private func copyCurrentPixelBuffer() -> CVPixelBuffer? {
        let itemTime = self.videoPlayerOutput.itemTime(forHostTime: CACurrentMediaTime())
        guard self.videoPlayerOutput.hasNewPixelBuffer(forItemTime: itemTime) else { return nil }
        return unsafe self.videoPlayerOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
    }

    /// Recomputes `cachedTintColor` from `foregroundColor` and the window's
    /// current color space. Call this only when one of those two inputs
    /// actually changes (color updated, or the view moved to a window with a
    /// different color space) — not from the per-frame render path.
    private func updateCachedTintColor() {
        let targetColorSpace = unsafe self.window?.colorSpace ?? .sRGB
        let convertedColor = self.foregroundColor.usingColorSpace(targetColorSpace) ?? self.foregroundColor
        self.cachedTintColor = simd_float4(
            Float(convertedColor!.redComponent),
            Float(convertedColor!.greenComponent),
            Float(convertedColor!.blueComponent),
            Float(convertedColor!.alphaComponent)
        )
    }

    /// Renders `pixelBuffer` (tinted by `foregroundColor` via the fragment
    /// shader) straight into the next drawable from the backing
    /// `CAMetalLayer` and presents it — no offscreen render target, no
    /// CIImage/CGImage conversion, no layer.contents assignment. Must be
    /// called on the main thread.
    private func renderFrameToDrawable(pixelBuffer: CVPixelBuffer) {

        let textureWidth = CVPixelBufferGetWidth(pixelBuffer)
        let textureHeight = CVPixelBufferGetHeight(pixelBuffer)

        nonisolated(unsafe) var cvTexture: CVMetalTexture!
        let createMTLTextureResult = unsafe CVMetalTextureCacheCreateTextureFromImage(nil, self.videoTextureCache, pixelBuffer, nil, self.pixelFormat, textureWidth, textureHeight, 0, &cvTexture)
        guard createMTLTextureResult == kCVReturnSuccess, unsafe cvTexture != nil else {
            // Don't crash the whole process over a single dropped frame —
            // a transient cache miss is recoverable, just skip this frame.
            print("GhostChromaView: failed to create MTLTexture from CVPixelBuffer: \(createMTLTextureResult)")
            return
        }
        guard let frameTexture = unsafe CVMetalTextureGetTexture(cvTexture) else { return }

        // Keep the drawable's pixel size in step with the incoming video
        // frame size. CAMetalLayer only reallocates drawables when this
        // actually changes, so setting it every frame is cheap once stable.
        let drawableSize = CGSize(width: textureWidth, height: textureHeight)
        if self.metalLayer.drawableSize != drawableSize {
            self.metalLayer.drawableSize = drawableSize
        }

        guard let drawable = self.metalLayer.nextDrawable() else {
            // No drawable available this tick (e.g. layer not visible yet);
            // skip the frame rather than stalling.
            return
        }

        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        commandEncoder.setRenderPipelineState(self.renderPipelineState)
        commandEncoder.setFragmentTexture(frameTexture, index: 0)
        var color = self.cachedTintColor
        unsafe commandEncoder.setFragmentBytes(&color, length: MemoryLayout<simd_float4>.size, index: 0)

        commandEncoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 4
        )

        commandEncoder.endEncoding()

        self.isRenderInFlight = true

        // `cvTexture` is captured by this closure, which keeps the
        // CVMetalTexture (and the underlying CVPixelBuffer/IOSurface) alive
        // until the GPU has actually finished reading from it.
        commandBuffer.addCompletedHandler { [weak self] _ in
            let _ = unsafe cvTexture
            Task { @MainActor in
                guard let self else { return }
                self.isRenderInFlight = false
            }
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: NSView overrides

    public override func layout() {
        super.layout()
        self.metalLayer.contentsScale = unsafe self.window?.backingScaleFactor ?? self.metalLayer.contentsScale
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if unsafe self.window != nil {
            // (Re)create the display link now that we have a window/screen
            // to attach to. Handles both first attachment and the view
            // moving to a different window/screen later.
            self.setupDisplayLink()
            // The window (and therefore its color space) may have changed;
            // recompute the cached tint to match.
            self.updateCachedTintColor()
        } else {
            // Removed from the window hierarchy entirely — fully tear down
            // rather than leaving a link running with nothing to render to.
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }

    func updateView(newForegroundColor: NSColor) {
        guard self.foregroundColor != newForegroundColor else { return }
        self.foregroundColor = newForegroundColor
        self.updateCachedTintColor()
    }

    func stopAnimation() {
        self.videoPlayer.pause()
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
}

public struct SavedByGhostVideoView: NSViewRepresentable {

    public typealias NSViewType = GhostChromaView

    let initialForegroundColor: NSColor
    var currentView: GhostChromaView!

    public init(initialForegroundColor: NSColor) {
        self.initialForegroundColor = initialForegroundColor
        self.currentView = GhostChromaView()
            .setup(withGhostColor: self.initialForegroundColor.usingColorSpace(.displayP3) ?? self.initialForegroundColor)
    }

    public func makeNSView(context: Context) -> GhostChromaView {
        return self.currentView
    }

    public func updateNSView(_ nsView: GhostChromaView, context: Context) {
        // We need to fetch the current foreground color and update the view
        let currentForegroundColor = SavedByGhostColorManager.foregroundColorFor(name: SavedByGhostConfiguration.shared.currentForegroundColor)!
        nsView.updateView(newForegroundColor: currentForegroundColor.color)
    }

    public func manuallyUpdate() {
        // We need to fetch the current foreground color and update the view
        let currentForegroundColor = SavedByGhostColorManager.foregroundColorFor(name: SavedByGhostConfiguration.shared.currentForegroundColor)!
        self.currentView.updateView(newForegroundColor: currentForegroundColor.color)
    }

    public func stopAnimation() {
        self.currentView.stopAnimation()
    }

}
