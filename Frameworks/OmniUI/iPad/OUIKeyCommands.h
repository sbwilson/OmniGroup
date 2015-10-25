// Copyright 2010-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSObject.h>

@interface OUIKeyCommands : NSObject

+ (NSArray *)keyCommandsWithCategories:(NSString *)categories; // categories should be a comma separated list

+ (NSString *)truncatedDiscoverabilityTitle:(NSString *)title;

@end
