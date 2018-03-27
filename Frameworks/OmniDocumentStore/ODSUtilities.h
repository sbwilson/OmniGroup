// Copyright 2010-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniFoundation/NSURL-OFExtensions.h>

// iOS uses an 'Inbox' folder in the app's ~/Documents for opening files from other applications
extern BOOL ODSIsInInbox(NSURL *url);
extern BOOL ODSIsZipFileType(NSString *uti);
extern NSString * const ODSDocumentInteractionInboxFolderName;

extern OFScanDirectoryFilter ODSScanDirectoryExcludeSytemFolderItemsFilter(void);

