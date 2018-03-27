// Copyright 2016-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <UIKit/UIAlertController.h>

@interface OUIReplaceRenameDocumentAlertController : UIAlertController

+ (instancetype)replaceRenameAlertForURL:(NSURL *)aURL withCancelHandler:(void (^)(void))cancel replaceHandler:(void (^)(void))replace renameHandler:(void (^)(void))rename;

@end
