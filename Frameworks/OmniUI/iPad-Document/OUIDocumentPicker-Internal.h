// Copyright 2010-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUIDocument/OUIDocumentPicker.h>

@class ODSFileItem, ODSFolderItem;

@interface OUIDocumentPicker (/*Internal*/)

- (void)navigateForDeletionOfFolder:(ODSFolderItem *)deletedItem animated:(BOOL)animated;
- (ODSFileItem *)preferredVisibleItemForNextPreviewUpdate:(NSSet *)eligibleItems;

- (NSArray *)availableFiltersForScope:(ODSScope *)scope;

@end
