// Copyright 2010-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniUI/OUIActionInspectorSlice.h>

/*
 Presents a table view of navigation items, each with a title and an optional value for the current state of some setting.
 */

@class OUIDetailInspectorSlice;

// Filled out with default values so -updateItem:atIndex: can fill out only the bits relevant
@interface OUIDetailInspectorSliceItem : NSObject
@property(nonatomic,copy) NSString *title; // Defaults to the slice's title
@property(nonatomic,copy) NSString *value; // Defaults to nil
@property(nonatomic,copy) UIImage *valueImage; // Defaults to nil
@property(nonatomic,copy) UIImage *image; // Defaults to nil
@property(nonatomic,assign) BOOL drawImageAsTemplate; // Defaults to YES
@property(nonatomic,assign) BOOL enabled; // Defaults to YES
@property(nonatomic,assign) BOOL boldValue; //Defaults to NO
@end

@interface OUIDetailInspectorSlice : OUIInspectorSlice <UITableViewDataSource, UITableViewDelegate>

// Defaults to 1
@property(nonatomic,readonly) NSUInteger itemCount;
@property(nonatomic,readonly,strong) UITableView *tableView;

// Passed an item with default values. Don't need to implement if the receiver has a title and doesn't want a value. Don't need to call super in your subclass method (defaults are filled in by the caller).
- (void)updateItem:(OUIDetailInspectorSliceItem *)item atIndex:(NSUInteger)itemIndex;

// Defaults to nil, meaning the inspection set of the receiver will be passed to the detail pane.
- (NSArray *)inspectedObjectsForItemAtIndex:(NSUInteger)itemIndex;

// Will be called if the corresponding value passed to the 'handler' of -updateItemAtIndex:with: is nil. Defaults to nil.
- (NSString *)placeholderTitleForItemAtIndex:(NSUInteger)itemIndex;
- (NSString *)placeholderValueForItemAtIndex:(NSUInteger)itemIndex;

- (NSString *)groupTitle;

@end

@interface OUIDetailInspectorSlice (SubclassResponsibility)
- (OUIInspectorPane *)makeDetailsPaneForItemAtIndex:(NSUInteger)itemIndex;
@end
