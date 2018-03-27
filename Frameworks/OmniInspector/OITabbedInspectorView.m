// Copyright 2016-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OITabbedInspectorView.h"

#import <OmniInspector/OIAppearance.h>

RCS_ID("$Id$");

@implementation OITabbedInspectorView

- (void)drawRect:(NSRect)r;
{
    NSColor *backgroundColor = [[OIAppearance appearance] inspectorBackgroundColorForView:self];
    [backgroundColor set];
    NSRectFill(r);
}

@end
