//
//  LegacyCode.m
//  SavedByGhost (Legacy Code)
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

/*
- (void)prerenderFrames:(NSRect)screenRect {
    
    // Prerender all frames
    if (self.attributedStrings.count == 0)
        assert(false && "Attributed strings must have been generated before the pre-render stage");
    
    // Serial queue used only to guard writes into the shared dictionary
    dispatch_queue_t writeQueue = dispatch_queue_create("de.philippremy.GhostSaver.WriteQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    
    dispatch_apply(FRAME_COUNT, concurrentQueue, ^(size_t frameIndex) {
    
        NSLog(@"Prerendering frame %zu", frameIndex);
        
        NSAttributedString* attrStr = self.attributedStrings[frameIndex];
        
        // Get required size
        // We cannot use [attrStr size], because it takes an internal lock and prevents doing parallel work
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attrStr);
        CFRange fitRange;
        NSSize attrStrSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, attrStr.length),
            NULL,
            CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX),
            &fitRange
        );
        CFRelease(framesetter);
        
        // Guard against zero-size strings (e.g. empty frame) which would make an invalid image
        if (attrStrSize.width < 1) attrStrSize.width = 1;
        if (attrStrSize.height < 1) attrStrSize.height = 1;
        
        // Create image and lock it for rendering
        NSImage* renderImage = [NSImage imageWithSize:(NSSize)attrStrSize flipped:NO drawingHandler:^BOOL(NSRect rect) {
            [attrStr drawInRect:rect];
            return YES;
        }];
           
        dispatch_sync(writeQueue, ^() {
            [self.prerenderedFrames setObject:renderImage forKey:[NSNumber numberWithInt:(int)frameIndex]];
        });
    });
    
}
*/
