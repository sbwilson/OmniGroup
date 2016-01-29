// Copyright 2005-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <AppKit/NSButtonCell.h>

@class NSImageCell;

extern NSString *TabTitleDidChangeNotification;

@interface OITabCell : NSButtonCell
{
    BOOL duringMouseDown;
    NSInteger oldState;
    BOOL isPinned;
    NSImageCell *_imageCell;
}

- (BOOL)duringMouseDown;
- (void)saveState;
- (void)clearState;
- (BOOL)isPinned;
- (void)setIsPinned:(BOOL)newValue;
- (BOOL)drawState;

@end
