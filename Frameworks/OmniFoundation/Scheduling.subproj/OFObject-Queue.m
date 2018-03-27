// Copyright 1997-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject-Queue.h>

#import <objc/objc-class.h>

#import <OmniFoundation/OFInvocation.h>
#import <OmniFoundation/OFMessageQueue.h>

RCS_ID("$Id$")


@implementation NSObject (Queue)

+ (void)queueSelectorOnce:(SEL)aSelector;
{
    [[OFMessageQueue mainQueue] queueSelectorOnce:aSelector forObject:(id)self];
}

- (void)queueSelector:(SEL)aSelector;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self];
}

- (void)queueSelectorOnce:(SEL)aSelector;
{
    [[OFMessageQueue mainQueue] queueSelectorOnce:aSelector forObject:self];
}

- (void)queueSelector:(SEL)aSelector withObject:(id)anObject;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self withObject:anObject];
}

- (void)queueSelectorOnce:(SEL)aSelector withObject:(id)anObject;
{
    [[OFMessageQueue mainQueue] queueSelectorOnce:aSelector forObject:self withObject:anObject];
}

- (void)queueSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self withObject:object1 withObject:object2];
}

- (void)queueSelectorOnce:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;
{
    [[OFMessageQueue mainQueue] queueSelectorOnce:aSelector forObject:self withObject:object1 withObject:object2];
}

- (void)queueSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2 withObject:(id)object3;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self withObject:object1 withObject:object2 withObject:object3];
}

- (void)queueSelector:(SEL)aSelector withBool:(BOOL)aBool;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self withBool:aBool];
}

- (void)queueSelector:(SEL)aSelector withInt:(int)anInt;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self withInt:anInt];
}

- (void)queueSelector:(SEL)aSelector withInt:(int)anInt withInt:(int)anotherInt;
{
    [[OFMessageQueue mainQueue] queueSelector:aSelector forObject:self withInt:anInt withInt:anotherInt];
}

//

+ (void)mainThreadPerformSelectorOnce:(SEL)aSelector;
{
    if ([NSThread isMainThread])
        OBSendVoidMessage(self, aSelector);
    else
	[self queueSelectorOnce:aSelector];
}

- (void)mainThreadPerformSelector:(SEL)aSelector;
{
    if ([NSThread isMainThread])
	OBSendVoidMessage(self, aSelector);
    else
	[self queueSelector:aSelector];
}

- (void)mainThreadPerformSelectorOnce:(SEL)aSelector;
{
    if ([NSThread isMainThread])
	OBSendVoidMessage(self, aSelector);
    else
	[self queueSelectorOnce:aSelector];
}

- (void)mainThreadPerformSelector:(SEL)aSelector withObject:(id)anObject;
{
    if ([NSThread isMainThread])
        OBSendVoidMessageWithObject(self, aSelector, anObject);
    else
	[self queueSelector:aSelector withObject:anObject];
}

- (void)mainThreadPerformSelectorOnce:(SEL)aSelector withObject:(id)anObject;
{
    if ([NSThread isMainThread])
	OBSendVoidMessageWithObject(self, aSelector, anObject);
    else
	[self queueSelectorOnce:aSelector withObject:anObject];
}

- (void)mainThreadPerformSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;
{
    if ([NSThread isMainThread])
	OBSendVoidMessageWithObjectObject(self, aSelector, object1, object2);
    else
	[self queueSelector:aSelector withObject:object1 withObject:object2];
}

- (void)mainThreadPerformSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2 withObject:(id)object3;
{
    if ([NSThread isMainThread])
        OBSendVoidMessageWithObjectObjectObject(self, aSelector, object1, object2, object3);
    else
	[self queueSelector:aSelector withObject:object1 withObject:object2 withObject:object3];
}

- (void)mainThreadPerformSelector:(SEL)aSelector withBool:(BOOL)aBool;
{
    if ([NSThread isMainThread]) {
	Method method;

	method = class_getInstanceMethod([self class], aSelector);
        if (!method)
            [NSException raise:NSInvalidArgumentException format:@"%@ does not respond to the selector %@", OBShortObjectDescription(self), NSStringFromSelector(aSelector)];
        void (*imp)(id, SEL, BOOL) = (typeof(imp))method_getImplementation(method);
	imp(self, aSelector, aBool);
    } else
	[self queueSelector:aSelector withBool:aBool];
}

- (void)mainThreadPerformSelector:(SEL)aSelector withInt:(int)anInt;
{
    if ([NSThread isMainThread]) {
	Method method;

	method = class_getInstanceMethod([self class], aSelector);
        if (!method)
            [NSException raise:NSInvalidArgumentException format:@"%@ does not respond to the selector %@", OBShortObjectDescription(self), NSStringFromSelector(aSelector)];
        void (*imp)(id, SEL, int) = (typeof(imp))method_getImplementation(method);
	imp(self, aSelector, anInt);
    } else
	[self queueSelector:aSelector withInt:anInt];
}

- (void)mainThreadPerformSelector:(SEL)aSelector withInt:(int)anInt withInt:(int)anInt2;
{
    if ([NSThread isMainThread]) {
	Method method;

	method = class_getInstanceMethod([self class], aSelector);
        if (!method)
            [NSException raise:NSInvalidArgumentException format:@"%@ does not respond to the selector %@", OBShortObjectDescription(self), NSStringFromSelector(aSelector)];
        void (*imp)(id, SEL, int, int) = (typeof(imp))method_getImplementation(method);
	imp(self, aSelector, anInt, anInt2);
    } else
	[self queueSelector:aSelector withInt:anInt withInt:anInt2];
}

- (void)invokeSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2 withObject:(id)object3;
{
    OFInvocation *invocation;

    invocation = [[OFInvocation alloc] initForObject:self selector:aSelector withObject:object1 withObject:object2 withObject:object3];
    [invocation invoke];
    [invocation release];
}

@end
