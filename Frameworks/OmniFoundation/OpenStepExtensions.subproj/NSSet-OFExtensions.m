// Copyright 2005-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSSet-OFExtensions.h>
#import <OmniFoundation/NSMutableArray-OFExtensions.h>
#import <OmniBase/rcsid.h>
#import <OmniBase/assertions.h>

RCS_ID("$Id$");

@implementation NSSet (OFExtensions)

+ (BOOL)isEmptySet:(NSSet *)set;
{
    return set == nil || set.count == 0;
}

- (NSSet *)setByPerformingSelector:(SEL)aSelector;
{
    return [self setByPerformingBlock:^(id object){
        return OBSendObjectReturnMessage(object, aSelector);
    }];
}

- (NSSet *)setByPerformingBlock:(OFObjectToObjectBlock)block;
{
    NSMutableSet *resultSet = nil;
    id singleResult = nil;
    
    for (id object in self) {
        id result = block(object);
        if (!result)
            continue;
        
        if (resultSet)
            [resultSet addObject:result];
        else if (singleResult)
            resultSet = [NSMutableSet setWithObjects:singleResult, result, nil];
        else
            singleResult = result;
    }
    
    if (resultSet)
        return resultSet;
    if (singleResult)
        return [NSSet setWithObject:singleResult];
    return [NSSet set];
}

- (NSSet *)setByRemovingObject:(id)anObject;
{
    return [self filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return ![evaluatedObject isEqual:anObject];
    }]];
}

- (NSArray *)sortedArrayUsingSelector:(SEL)comparator;
{
    NSMutableArray *into = [NSMutableArray arrayWithCapacity:[self count]];
    for (id object in self) {
        [into insertObject:object inArraySortedUsingSelector:comparator];
    }
    
    return into;
}

- (NSArray *)sortedArrayUsingComparator:(NSComparator)comparator;
{
    NSMutableArray *into = [NSMutableArray arrayWithCapacity:[self count]];
    for (id object in self) {
        [into insertObject:object inArraySortedUsingComparator:comparator];
    }
    
    return into;
}

// This is just nice so that you don't have to check for a NULL set.
- (void)applyFunction:(CFSetApplierFunction)applier context:(void *)context;
{
    CFSetApplyFunction((CFSetRef)self, applier, context);
}

- (id)any:(OFPredicateBlock)predicate;
{
    for (id obj in self) {
        if (predicate(obj))
            return obj;
    }
    return nil;
}

- (BOOL)all:(OFPredicateBlock)predicate;
{
    for (id obj in self) {
        if (!predicate(obj))
            return NO;
    }
    return YES;
}

- (id)min:(NSComparator)comparator;
{
    id minimumValue = nil;
    for (id value in self) {
        if (!minimumValue || comparator(minimumValue, value) == NSOrderedDescending)
            minimumValue = value;
    }
    return minimumValue;
}

- (id)max:(NSComparator)comparator;
{
    id maximumValue = nil;
    for (id value in self) {
        if (!maximumValue || comparator(maximumValue, value) == NSOrderedAscending)
            maximumValue = value;
    }
    return maximumValue;
}

- (id)minValueForKey:(NSString *)key comparator:(NSComparator)comparator;
{
    id minimumValue = nil;
    for (id object in self) {
        id value = [object valueForKey:key];
        if (!minimumValue || (value && comparator(minimumValue, value) == NSOrderedDescending))
            minimumValue = value;
    }
    return minimumValue;
}

- (id)maxValueForKey:(NSString *)key comparator:(NSComparator)comparator;
{
    id maximumValue = nil;
    for (id object in self) {
        id value = [object valueForKey:key];
        if (!maximumValue || (value && comparator(maximumValue, value) == NSOrderedAscending))
            maximumValue = value;
    }
    return maximumValue;
}

- (NSSet *)select:(OFPredicateBlock)predicate;
{
    NSMutableSet *matches = [NSMutableSet set];
    for (id obj in self)
        if (predicate(obj))
            [matches addObject:obj];
    return matches;
}

- (NSDictionary *)indexByBlock:(OFObjectToObjectBlock)blk;
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    for (id object in self) {
        id key;
        if ((key = blk(object)) != nil) {
            OBASSERT(dict[key] == nil, "We may want a non-unique index variant later, but this is probably an error");
            [dict setObject:object forKey:key];
        }
    }
    
    NSDictionary *result = [NSDictionary dictionaryWithDictionary:dict];
    [dict release];
    return result;
}

- (BOOL)containsObjectIdenticalTo:(id)anObject;
{
    for (id candidate in self) {
        if (candidate == anObject) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isIdenticalToSet:(NSSet *)otherSet;
{
    if ([self count] != [otherSet count]) {
        return NO;
    }
    
    for (id anObject in self) {
        if (![otherSet containsObjectIdenticalTo:anObject]) {
            return NO;
        }
    }
    
    return YES;
}

@end
