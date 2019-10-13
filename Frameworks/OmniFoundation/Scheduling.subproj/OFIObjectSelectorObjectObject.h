// Copyright 1997-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFIObjectSelector.h>

@interface OFIObjectSelectorObjectObject : OFIObjectSelector
{
    id object1;
    id object2;
}

- initForObject:(id)targetObject selector:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2;

@end
