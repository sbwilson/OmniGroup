// Copyright 2010-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <UIKit/UIView.h>

#import <OmniUIDocument/OUIDocumentPickerItemSort.h>

extern NSString * const OUIDocumentPickerScrollViewItemsBinding;

@class OFPreference;
@class ODSItem, ODSFileItem;
@class OUIDocumentPickerItemView, OUIDocumentPickerFileItemView, OUIDocumentPickerScrollView;
@class OUIDocumentRenameSession;

@protocol OUIDocumentPickerScrollViewDelegate <UIScrollViewDelegate>
- (void)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView itemViewTapped:(OUIDocumentPickerItemView *)itemView;
- (void)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView itemViewLongpressed:(OUIDocumentPickerItemView *)itemView;
- (void)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView itemViewStartedEditingName:(OUIDocumentPickerItemView *)itemView;
- (void)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView itemView:(OUIDocumentPickerItemView *)itemView finishedEditingName:(NSString *)name;
- (void)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView willDisplayItemView:(OUIDocumentPickerItemView *)itemView;
- (void)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView willEndDisplayingItemView:(OUIDocumentPickerItemView *)itemView;

- (NSArray *)sortDescriptorsForDocumentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView;
- (BOOL)isReadyOnlyForDocumentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView;

- (BOOL)documentPickerScrollView:(OUIDocumentPickerScrollView *)scrollView rectIsFullyVisible:(CGRect)rect;

@optional
- (BOOL)documentPickerScrollViewShouldMultiselect:(OUIDocumentPickerScrollView *)scrollView;

@end

@interface OUIDocumentPickerScrollView : UIScrollView <UIGestureRecognizerDelegate>

@property(nonatomic,assign) id <OUIDocumentPickerScrollViewDelegate> delegate;

@property(nonatomic,assign) BOOL shouldHideTopControlsOnNextLayout;
@property(nonatomic,readonly) BOOL isShowingTitleLabel;

- (CGFloat)contentOffsetYToHideTopControls;
- (CGFloat)contentOffsetYToHideCompactTitleBehindNavBar;
- (CGFloat)contentOffsetYForTopControlsFullAlpha;
- (CGFloat)contentOffsetYToShowTopControls;

- (void)retileItems;

@property(nonatomic,retain) UILabel *titleViewForCompactWidth;
@property(nonatomic,retain) UIView *topControls;
@property(nonatomic,retain) OUIDocumentRenameSession *renameSession;

@property(nonatomic,readonly) NSSet *items;

- (void)startAddingItems:(NSSet *)toAdd;
- (void)finishAddingItems:(NSSet *)toAdd;
@property(nonatomic,readonly) NSSet *itemsBeingAdded;

- (void)startRemovingItems:(NSSet *)toRemove;
- (void)finishRemovingItems:(NSSet *)toRemove;
@property(nonatomic,readonly) NSSet *itemsBeingRemoved;

@property(nonatomic,readonly) NSArray *sortedItems;
@property(nonatomic,retain) id draggingDestinationItem;

- (void)scrollItemToVisible:(ODSItem *)item animated:(BOOL)animated;
- (void)scrollItemsToVisible:(id <NSFastEnumeration>)items animated:(BOOL)animated;
- (void)scrollItemsToVisible:(id <NSFastEnumeration>)items animated:(BOOL)animated completion:(void (^)(void))completion;

@property(nonatomic,readonly) BOOL hasScrollFinishedHandlers;
- (void)performScrollFinishedHandlers; // Called by the delegate when scrolling is done

- (void)sortItems;

- (CGRect)frameForItem:(ODSItem *)item;

/// - point: Expected to be in OUIDocumentPickerScrollView's coordinates.
- (OUIDocumentPickerItemView *)itemViewForPoint:(CGPoint)point;
- (OUIDocumentPickerItemView *)itemViewForItem:(ODSItem *)item;
- (OUIDocumentPickerFileItemView *)fileItemViewForFileItem:(ODSFileItem *)fileItem;
- (OUIDocumentPickerItemView *)itemViewHitByRecognizer:(UIGestureRecognizer *)recognizer;

- (ODSFileItem *)preferredVisibleItemFromSet:(NSSet *)fileItemsNeedingPreviewUpdate;
- (void)previewsUpdatedForFileItem:(ODSFileItem *)fileItem;
- (void)previewedItemsChangedForGroups;

- (void)setEditing:(BOOL)editing animated:(BOOL)animated;

@property(nonatomic) OUIDocumentPickerItemSort itemSort;

- (void)startIgnoringItemForLayout:(ODSItem *)item;
- (void)stopIgnoringItemForLayout:(ODSItem *)item;

@end
