// Copyright 2010-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUIDocument/OUIDocument.h>

@class OFFileEdit;

OB_HIDDEN extern NSString * const OUIDocumentPreviewsUpdatedForFileItemNotification;

@interface OUIDocument (/*Internal*/)
- (void)_willBeRenamedLocally;
- (void)_writePreviewsIfNeeded:(BOOL)onlyIfNeeded fileEdit:(OFFileEdit *)fileEdit withCompletionHandler:(void (^)(void))completionHandler;
- (void)_manualSync:(id)sender;
@end
