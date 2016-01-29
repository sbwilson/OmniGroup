// Copyright 2004-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

@class NSData;

extern BOOL OFXMLIsValidID(NSString * _Nullable identifier);
extern NSString *OFXMLCreateID(void) NS_RETURNS_RETAINED;
extern NSString *OFXMLCreateIDFromData(NSData *data) NS_RETURNS_RETAINED;

NS_ASSUME_NONNULL_END
