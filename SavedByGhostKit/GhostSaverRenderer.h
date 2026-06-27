//
//  GhostSaverRenderer_H
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

#ifndef GhostSaverRenderer_h
#define GhostSaverRenderer_h

#import <AppKit/AppKit.h>
#import <Foundation/NSObject.h>

@interface GhostSaverRenderer : NSObject

- (id)init:(NSColor*)foregroundColor;

// Fetches a pregenerated NSImage for a specific frame index
- (NSImage *)getPrerenderedImageFor:(int)frameIndex;

// Ensures that all frames are properly prerendered
- (void)prerenderFrames:(NSRect)screenRect;

@property NSArray* attributedStrings;
@property NSMutableDictionary* prerenderedFrames;

@end

#endif /* GhostSaverRenderer_h */
