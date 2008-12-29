// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/NSApplication-OAExtensions.h>
#import <OmniBase/OmniBase.h>
#import <AppKit/AppKit.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-09-09/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSApplication-OAExtensions.m 104581 2008-09-06 21:18:23Z kc $")

@implementation NSApplication (OAExtensions)

- (BOOL)useColor;
{
    return NSNumberOfColorComponents (
	    NSColorSpaceFromDepth([NSWindow defaultDepthLimit])) > 1;
}

- (NSEvent *)peekEvent;
{
    NSString *mode;
    
    if (!(mode = [[NSRunLoop currentRunLoop] currentMode]))
        // NSApp crashes on nil modes in DP4
        mode = NSDefaultRunLoopMode;

    // We get system-defined events quite frequently, so ignore them.
    return [self nextEventMatchingMask:(NSAnyEventMask & ~NSSystemDefinedMask) untilDate:[NSDate distantPast] inMode:mode dequeue:NO];
}

@end
