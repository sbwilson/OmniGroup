// Copyright 2002-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <AppKit/NSButton.h>

@class NSPopUpButton, NSToolbarItem;

#import <AppKit/NSNibDeclarations.h> // For IBOutlet

@interface OAToolbarButton : NSButton
{
    IBOutlet id delegate;
    BOOL isShowingMenu;
}

// API
@property (weak) NSToolbarItem *toolbarItem;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

- (void)_showMenu;

@end

@interface NSObject (OAToolbarButtonDelegate)
- (NSPopUpButton *)popUpButtonForToolbarButton:(OAToolbarButton *)button;
@end
