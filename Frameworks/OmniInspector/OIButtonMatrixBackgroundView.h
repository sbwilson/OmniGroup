// Copyright 2006-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-09-09/OmniGroup/Frameworks/OmniInspector/OIButtonMatrixBackgroundView.h 98223 2008-03-04 21:07:09Z kc $

#import <AppKit/NSView.h>

@interface OIButtonMatrixBackgroundView : NSView
{
    NSColor *color;
}

- (void)setBackgroundColor:(NSColor *)aColor;

@end

