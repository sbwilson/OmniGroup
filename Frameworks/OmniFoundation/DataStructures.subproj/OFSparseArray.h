// Copyright 1997-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>

@class NSArray, NSMutableArray;

@interface OFSparseArray : OFObject
{
    NSMutableArray *values;
    NSUInteger valuesLength;
    id defaultValue;
}

- (id)initWithCapacity:(NSUInteger)aCapacity;
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)anIndex;
- (void)setObject:(id)anObject atIndex:(NSUInteger)anIndex;
- (void)setDefaultValue:(id)aDefaultValue;
- (NSArray *)valuesArray;

@end
