// Copyright 1997-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>

#import <OmniFoundation/OFMessageQueuePriorityProtocol.h>

@interface OFInvocation : OFObject <OFMessageQueuePriority, NSCopying>

- (id <NSObject>)object;
- (SEL)selector;

- (void)invoke;

@end

@interface OFInvocation (Inits)
- (id)initForObject:(id <NSObject>)targetObject nsInvocation:(NSInvocation *)anInvocation;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withBool:(BOOL)aBool;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withInt:(int)int1;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withInt:(int)int1 withInt:(int)int2;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)anObject;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)anObject withInt:(int)anInt;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)object1 withObject:(id <NSObject>)object2;
- (id)initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)object1 withObject:(id <NSObject>)object2 withObject:(id <NSObject>)object3;
@end
