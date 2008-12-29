// Copyright 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAFlippedView.h"
#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-09-09/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OAFlippedView.m 104581 2008-09-06 21:18:23Z kc $")

// Useful for nibs where you need a flipped container view that has nothing else special about it.
@implementation OAFlippedView

- (BOOL)isFlipped;
{
    return YES;
}

@end
