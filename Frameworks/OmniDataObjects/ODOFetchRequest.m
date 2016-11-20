// Copyright 2008-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniDataObjects/ODOFetchRequest.h>

RCS_ID("$Id$")

@implementation ODOFetchRequest

- (void)dealloc;
{
    [_entity release];
    [_predicate release];
    [_sortDescriptors release];
    [_reason release];
    [super dealloc];
}

@end

