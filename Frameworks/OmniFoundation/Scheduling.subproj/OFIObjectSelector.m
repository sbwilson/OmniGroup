// Copyright 1997-2018 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFIObjectSelector.h>

#import <objc/objc-class.h>

#import <OmniFoundation/OFMessageQueuePriorityProtocol.h>

RCS_ID("$Id$")

@implementation OFIObjectSelector

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id <NSObject>)targetObject;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- initForObject:(id)anObject selector:(SEL)aSelector;
{
    OBPRECONDITION([anObject respondsToSelector:aSelector]);

    if (!(self = [super initForObject:anObject]))
        return nil;

    selector = aSelector;

    return self;
}

- (void)invoke;
{
    Class cls = object_getClass(object);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        [NSException raise:NSInvalidArgumentException format:@"%s(%p) does not respond to the selector %@", class_getName(cls), object, NSStringFromSelector(selector)];

    void (*imp)(id self, SEL _cmd) = (typeof(imp))method_getImplementation(method);
    imp(object, selector);
}

- (SEL)selector;
{
    return selector;
}

- (NSUInteger)hash;
{
    uintptr_t hashv = (uintptr_t)object + (uintptr_t)(void *)selector;
    return OFHashUIntptr(hashv);
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelector *otherObject;

    otherObject = anObject;
    if (otherObject == self)
	return YES;
    if (object_getClass(otherObject) != myClass)
	return NO;
    return object == otherObject->object && selector == otherObject->selector;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
	[debugDictionary setObject:object forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@]", OBShortObjectDescription(object), NSStringFromSelector(selector)];
}

@end
