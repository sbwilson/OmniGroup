// Copyright 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-09-09/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OADatePicker.h 104581 2008-09-06 21:18:23Z kc $

#import <AppKit/NSDatePicker.h>

@class /* Foundation */ NSDate;

@interface OADatePicker : NSDatePicker
{
    BOOL sentAction;
    NSDate *_lastDate;
    BOOL ignoreNextDateRequest; // <bug://bugs/38625> (Selecting date selects current date first when switching between months, disappears (with some filters) before proper date can be selected)
}

- (void)reset;

@end
