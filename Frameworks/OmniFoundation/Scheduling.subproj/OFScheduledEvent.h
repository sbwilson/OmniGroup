// Copyright 1997-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>

@class NSDate;
@class OFInvocation;

@interface OFScheduledEvent : OFObject
{
    OFInvocation *invocation;
    NSDate *date;
    BOOL fireOnTermination;
}

- (id)initWithInvocation:(OFInvocation *)anInvocation atDate:(NSDate *)aDate;
- (id)initWithInvocation:(OFInvocation *)anInvocation atDate:(NSDate *)aDate fireOnTermination:(BOOL)shouldFireOnTermination;
- (id)initForObject:(id)anObject selector:(SEL)aSelector withObject:(id)aWithObject atDate:(NSDate *)date;

- (OFInvocation *)invocation;
- (NSDate *)date;
- (BOOL)fireOnTermination;

- (void)invoke;

- (NSComparisonResult)compare:(OFScheduledEvent *)otherEvent;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)anObject;

@end
