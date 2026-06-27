//
//  GhostSaverRenderer
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

#import <SavedByGhostKit/GhostSaverRenderer.h>

#import <SavedByGhostKit/GhostImageData.h>
#import <SavedByGhostKit/SavedByGhostKit-Swift.h>

#import <AppKit/AppKit.h>

@implementation GhostSaverRenderer

@synthesize attributedStrings;
@synthesize prerenderedFrames;

- (id)init:(NSColor*)foregroundColor {
    
    self = [super init];
    
    // Preload the font
    NSURL* fontURL = [SavedByGhostUtils urlForExtractedAssetWithNamed:@"SavedByGhostFont"];
    CFErrorRef err = NULL;
    if (!CTFontManagerRegisterFontsForURL((CFURLRef)fontURL, kCTFontManagerScopeProcess, &err)) {
        if (err) {
            NSError *fontLoadError = CFBridgingRelease(err);
            NSLog(@"An error occured: %@", fontLoadError);
        } else {
            NSLog(@"Font loading failed");
        }
    }
    
    NSFont* ghostSaverFont = [NSFont fontWithName:@"GhostSaverFont" size:14.0];
    
    NSDictionary *baseAttributes = @{
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSFontAttributeName: ghostSaverFont,
    };
    NSDictionary *specialAttributes = @{
        NSForegroundColorAttributeName: foregroundColor,
        NSFontAttributeName: ghostSaverFont,
    };
    
    NSMutableArray* frameStringArray = [NSMutableArray arrayWithCapacity:FRAME_COUNT];
    
    NSAttributedString* newlineAttrStr = [[NSAttributedString alloc] initWithString:@"\n" attributes:baseAttributes];
    
#pragma unroll
    for (int frameIndex = 0; frameIndex < FRAME_COUNT; ++frameIndex) {
        frameStringArray[frameIndex] = [NSMutableAttributedString new];
    }
    
    // Pre-generate all AttributedStrings
#pragma unroll
    for (int frameIndex = 0; frameIndex < FRAME_COUNT; ++frameIndex) {
        NSMutableAttributedString* currAttrStr = frameStringArray[frameIndex];
        
#pragma unroll
        for (int frameLine = 0; frameLine < FRAME_HEIGHT; ++frameLine) {
            
            const char* currLineStr = FRAMES[frameIndex][frameLine];
            size_t currLineStrLen = strlen(currLineStr);
            
            struct escaped_instring_range_t {
                const char* begin;
                const char* end;
                bool is_colored;
            };
            
            NSMutableArray* escapedStringRanges = [NSMutableArray new];
            
            // First, scan the entire line for any opening and closing tags
            const char* currLineStrNextPtr = currLineStr;
            ssize_t currLineStrLenRemaining = currLineStrLen;
            for(;;) {
                // Break if the end of the line string is reached
                if (currLineStrLenRemaining <= 0)
                    break;
                
                // First try to find the opening tag
                const char* openingFound = strstr(currLineStrNextPtr, "<c>");
                if (!openingFound) {
                    // No tags are in this substring, just append the whole string
                    struct escaped_instring_range_t fullRange = {
                        .begin = currLineStrNextPtr,
                        .end = currLineStrNextPtr + currLineStrLenRemaining - 1, // Range should be inclusive as all others are as well
                        .is_colored = false,
                    };
                    NSValue* range = [NSValue valueWithBytes:&fullRange objCType:@encode(struct escaped_instring_range_t)];
                    [escapedStringRanges addObject:range];
                    break;
                }
                
                // Handle the range preceding the opening tag, if there is any
                if (openingFound > currLineStrNextPtr) {
                    struct escaped_instring_range_t precedingRange = {
                        .begin = currLineStrNextPtr,
                        .end = openingFound - 1,    // Is one char before the opening tag!
                        .is_colored = false,
                    };
                    NSValue* range = [NSValue valueWithBytes:&precedingRange objCType:@encode(struct escaped_instring_range_t)];
                    [escapedStringRanges addObject:range];
                }
                
                // Bump the current line string (skip the opening tag!)
                currLineStrLenRemaining -= (openingFound + 3) - currLineStrNextPtr;
                currLineStrNextPtr = openingFound + 3;
                
                // Opening tag was found, now try to find the accompanying closing tag following it
                const char* closingFound = strstr(currLineStrNextPtr, "</c>");
                if (!closingFound) {
                    assert(false && "Malformed document: opening tag without accompanying closing tag!");
                }
                
                struct escaped_instring_range_t coloredRange = {
                    .begin = currLineStrNextPtr,  // Range starts after the tag
                    .end = closingFound - 1,    // Is one char before the closing tag!
                    .is_colored = true,
                };
                NSValue* range = [NSValue valueWithBytes:&coloredRange objCType:@encode(struct escaped_instring_range_t)];
                [escapedStringRanges addObject:range];
                
                // Bump the current line string (skip the closing tag!)
                currLineStrLenRemaining -= (closingFound + 4) - currLineStrNextPtr;
                currLineStrNextPtr = closingFound + 4;
                
                // Loop again
            }
            
            // Append ranges to the attributed string accordingly
            for (NSValue* escapedTextRangeWrapped in escapedStringRanges) {
                
                // Extract value
                struct escaped_instring_range_t escapedTextRange = {};
                [escapedTextRangeWrapped getValue:&escapedTextRange];
                
                // Create NSString from C substring
                size_t escapedRangeStrLength = escapedTextRange.end - escapedTextRange.begin + 1; // Range is inclusive, so add one
                NSString* newStr = [[NSString alloc] initWithBytesNoCopy:(void* _Nonnull)escapedTextRange.begin length:escapedRangeStrLength encoding:NSUTF8StringEncoding freeWhenDone:FALSE];
                
                // Create the attributed string for this occurance
                NSAttributedString* newAttrStr = [[NSAttributedString alloc] initWithString:newStr attributes:escapedTextRange.is_colored ? specialAttributes : baseAttributes];
                
                // Append it to the current attributed string
                [currAttrStr appendAttributedString:newAttrStr];
            }
            
            // Insert newline after line ended
            [currAttrStr appendAttributedString:newlineAttrStr];
        }
        
    }
    
    self.attributedStrings = frameStringArray;
    self.prerenderedFrames = [NSMutableDictionary new];
    
    return self;
}

- (void)prerenderFrames:(NSRect)screenRect {

    if (self.attributedStrings.count == 0)
        assert(false && "Attributed strings must have been generated before the pre-render stage");

    dispatch_queue_t writeQueue = dispatch_queue_create("de.philippremy.GhostSaver.WriteQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t concurrentQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);

    // Match the screen's backing scale so we don't over- or under-render
    CGFloat scale = screenRect.size.width > 0 ? (NSScreen.mainScreen.backingScaleFactor ?: 2.0) : 2.0;

    dispatch_apply(FRAME_COUNT, concurrentQueue, ^(size_t frameIndex) {

        NSAttributedString* attrStr = self.attributedStrings[frameIndex];

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

        if (attrStrSize.width < 1) attrStrSize.width = 1;
        if (attrStrSize.height < 1) attrStrSize.height = 1;

        NSInteger pixelWidth  = (NSInteger)ceil(attrStrSize.width  * scale);
        NSInteger pixelHeight = (NSInteger)ceil(attrStrSize.height * scale);

        // Build a real, flat bitmap up front — this *is* the render, eagerly, right now.
        NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL
                           pixelsWide:pixelWidth
                           pixelsHigh:pixelHeight
                        bitsPerSample:8
                      samplesPerPixel:4
                             hasAlpha:YES
                             isPlanar:NO
                       colorSpaceName:NSDeviceRGBColorSpace
                          bytesPerRow:0
                         bitsPerPixel:0];
        bitmap.size = attrStrSize; // logical size in points

        NSGraphicsContext* bitmapContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];

        NSGraphicsContext* previous = NSGraphicsContext.currentContext;
        NSGraphicsContext.currentContext = bitmapContext;

        [attrStr drawInRect:NSMakeRect(0, 0, attrStrSize.width, attrStrSize.height)];

        [bitmapContext flushGraphics];
        NSGraphicsContext.currentContext = previous;

        // Wrap the now-fully-rendered bitmap in a plain NSImage (no drawing handler, no deferred block)
        NSImage* renderImage = [[NSImage alloc] initWithSize:attrStrSize];
        [renderImage addRepresentation:bitmap];

        dispatch_sync(writeQueue, ^() {
            [self.prerenderedFrames setObject:renderImage forKey:[NSNumber numberWithInt:(int)frameIndex]];
        });
    });
}

- (NSImage *)getPrerenderedImageFor:(int)frameIndex {
    return [self.prerenderedFrames objectForKey:[NSNumber numberWithInt:frameIndex]];
}

@end
