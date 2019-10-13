// Copyright 2005-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniInspector/OITabCell.h>

#import <OmniBase/OmniBase.h>
#import <OmniAppKit/OmniAppKit.h>
#import <OmniInspector/OIAppearance.h>

RCS_ID("$Id$");

#if !defined(MAC_OS_X_VERSION_10_14)

typedef NS_ENUM(NSInteger, NSColorSystemEffect) {
    NSColorSystemEffectNone,
    NSColorSystemEffectPressed,
    NSColorSystemEffectDeepPressed,
    NSColorSystemEffectDisabled,
    NSColorSystemEffectRollover,
} NS_AVAILABLE_MAC(10_14);

@interface NSColor (Mojave)
@property (class, strong, readonly) NSColor *controlAccentColor NS_AVAILABLE_MAC(10_14);
- (NSColor *)colorWithSystemEffect:(NSColorSystemEffect)systemEffect NS_AVAILABLE_MAC(10_14);
@end
#endif

NSString * const TabTitleDidChangeNotification = @"TabTitleDidChange";

@interface OITabCell (/*Private*/)
- (void)_drawImageInRect:(NSRect)cellFrame inView:(NSView *)controlView;
@end

@implementation OITabCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return [NSColor blueColor];
}

- (BOOL)duringMouseDown;
{
    return duringMouseDown;
}

- (void)saveState;
{
    duringMouseDown = YES;
    oldState = [self state];
}

- (void)clearState;
{
    duringMouseDown = NO;
}

- (BOOL)isPinned;
{
    return isPinned;
}

- (void)setIsPinned:(BOOL)newValue;
{
    // If we get pinned, make sure we are turned on
    if (newValue && ([self state] != NSControlStateValueOn)) {
        [self setState:NSControlStateValueOn];
    }
    
    isPinned = newValue;    // Set our state to On before turning on pinning, so that we're always in a consistent state (can't be pinned and not on)
}

- (void)setState:(NSInteger)value
{
    // If we're pinned, don't allow ourself to be turned off
    if (isPinned) {
        return;
    }
    
    [super setState:value];
    if (duringMouseDown)
        [[NSNotificationCenter defaultCenter] postNotificationName:TabTitleDidChangeNotification object:self];
}

- (BOOL)drawState
{
    return (duringMouseDown) ? oldState : [self state];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if (![self image])
        return;
    
    // The highlight is now drawn by the matrix so that parts can be behind all cells and parts can be in front of all cells, etc.

    NSRect imageRect;
    imageRect.size = NSMakeSize(24,24);
    imageRect.origin.x = (CGFloat)(cellFrame.origin.x + floor((cellFrame.size.width - imageRect.size.width)/2));
    imageRect.origin.y = (CGFloat)(cellFrame.origin.y + floor((cellFrame.size.height - imageRect.size.height)/2));
    
    [self _drawImageInRect:imageRect inView:controlView];

    if (isPinned) {
        NSImage *image = OAImageNamed(@"OITabLock.pdf", OMNI_BUNDLE);
        NSSize imageSize = image.size;
        NSPoint point = NSMakePoint(NSMaxX(cellFrame) - imageSize.width - 3.0f, NSMaxY(cellFrame) - imageSize.height - 2.0f);
        [image drawFlippedInRect:(NSRect){point, imageSize} operation:NSCompositingOperationSourceOver];
    }
    
    return;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    OITabCell *copy = [super copyWithZone:zone];
    copy->_imageCell = [_imageCell copy];

    return copy;
}

#pragma mark - Private

- (void)_drawImageInRect:(NSRect)cellFrame inView:(NSView *)controlView;
{
    NSImage *image = [self image];
    NSRect imageRect = cellFrame;
    
    if (image) {
        imageRect.size = [image size];
        imageRect.origin.x = cellFrame.origin.x + rint((cellFrame.size.width - [image size].width)/2);
        imageRect.origin.y = cellFrame.origin.y + rint((cellFrame.size.height - [image size].height)/2);
    }
    NSColor *tabColor;
    if (@available(macOS 10.14, *)) {
        if ([self state]) {
            tabColor = [NSColor controlAccentColor];
        } else if ([self isHighlighted]) {
            tabColor = [[NSColor controlAccentColor] colorWithSystemEffect:NSColorSystemEffectPressed];
        } else {
            tabColor = [NSColor colorNamed:@"InspectorTabNormalTintColor" bundle:OMNI_BUNDLE];
        }

        image = [image imageByTintingWithColor:tabColor];
    } else if (@available(macOS 10.13, *)) {
        if ([self state]) {
            tabColor = [NSColor colorNamed:@"InspectorTabOnStateTintColor" bundle:OMNI_BUNDLE];
        } else if ([self isHighlighted]) {
            tabColor = [NSColor colorNamed:@"InspectorTabHighlightedTintColor" bundle:OMNI_BUNDLE];
        } else {
            tabColor = [NSColor colorNamed:@"InspectorTabNormalTintColor" bundle:OMNI_BUNDLE];
        }
        
        image = [image imageByTintingWithColor:tabColor];
    } else {
        NSColor *InspectorTabOnStateTintColor = [NSColor colorWithCalibratedRed:0.1843 green:0.5137 blue:0.98431373 alpha:1];
        NSColor *InspectorTabHighlightedTintColor = [NSColor colorWithCalibratedRed:0.098039216 green:0.25490196 blue:0.58431373 alpha:1];

        if ([self state]) {
            image = [image imageByTintingWithColor:InspectorTabOnStateTintColor];
        } else if ([self isHighlighted]) {
            image = [image imageByTintingWithColor:InspectorTabHighlightedTintColor];
        }
    }
    
    [image drawFlippedInRect:imageRect fromRect:NSMakeRect(0,0,imageRect.size.width,imageRect.size.height) operation:NSCompositingOperationSourceOver fraction:1];
}

@end
