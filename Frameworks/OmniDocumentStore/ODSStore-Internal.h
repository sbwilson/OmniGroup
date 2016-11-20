// Copyright 2010-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniDocumentStore/ODSStore.h>

@interface ODSStore ()
- (void)_fileItem:(ODSFileItem *)fileItem willMoveToURL:(NSURL *)newURL;
- (void)_fileItemEdit:(ODSFileItemEdit *)fileItemEdit willCopyToURL:(NSURL *)newURL;
- (void)_fileItemEdit:(ODSFileItemEdit *)fileItemEdit finishedCopyToURL:(NSURL *)destinationURL withFileItemEdit:(ODSFileItemEdit *)destinationFileItemEditOrNil;
- (void)_willRemoveFileItems:(NSArray <ODSFileItem *> *)fileItems;
@end

OB_HIDDEN NSString *ODSPathExtensionForFileType(NSString *fileType, BOOL *outIsPackage);
