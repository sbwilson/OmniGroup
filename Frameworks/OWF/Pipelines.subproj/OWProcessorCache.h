// Copyright 2003-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniFoundation/OFObject.h>

@class NSLock, NSMutableArray;
@class OFMultiValueDictionary;
@class OWProcessorCacheArc;

#import <OWF/OWContentCacheProtocols.h> // For OWCacheArcProvider;

@interface OWProcessorCache : OFObject <OWCacheArcProvider>

- (void)removeArc:(OWProcessorCacheArc *)anArc;

@end


