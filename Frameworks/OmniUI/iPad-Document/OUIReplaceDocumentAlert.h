// Copyright 2010-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSObject.h>

@class OUIReplaceDocumentAlert;
@protocol OUIReplaceDocumentAlertDelegate
- (void)replaceDocumentAlert:(OUIReplaceDocumentAlert *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex documentURL:(NSURL *)documentURL;
@end

__attribute__((deprecated("use OUIReplaceRenameDocumentAlertController instead")))
@interface OUIReplaceDocumentAlert : NSObject <UIAlertViewDelegate>
- (id)initWithDelegate:(id <OUIReplaceDocumentAlertDelegate>)delegate documentURL:(NSURL *)aURL;
- (void)showFromViewController:(UIViewController *)presentingViewController;
@property (readwrite, nonatomic) BOOL dontOpenSampleDocuments;
@end
