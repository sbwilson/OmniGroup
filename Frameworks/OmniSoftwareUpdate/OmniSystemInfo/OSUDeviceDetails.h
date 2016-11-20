// Copyright 2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

@class NSString;

/*!
 Copies a human-readable device name (e.g. "MacBook Pro" or "iPhone 6s Plus") for a hardware model identifier (e.g. "MacBookPro11,5" or "N66AP"). The returned names are suitable for display in user interfaces, but are not localized (following Apple's convention of leaving product names unchanged in languages other than English). They are not suitable for further parsing.
 */
extern NSString *OSUCopyDeviceNameForModel(NSString *hardwareModel);
