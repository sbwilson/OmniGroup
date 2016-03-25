// Copyright 2003-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFXMLElement.h>

#import <Foundation/Foundation.h>

#import <OmniFoundation/CFArray-OFExtensions.h>
#import <OmniFoundation/NSDate-OFExtensions.h>
#import <OmniFoundation/NSString-OFConversion.h>
#import <OmniFoundation/NSString-OFSimpleMatching.h>
#import <OmniFoundation/NSString-OFUnicodeCharacters.h>
#import <OmniFoundation/OFNull.h>
#import <OmniFoundation/OFXMLBuffer.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLString.h>
#import <OmniFoundation/OFXMLUnparsedElement.h>

#import "OFXMLFrozenElement.h"

#import <OmniBase/OmniBase.h>

RCS_ID("$Id$");

NS_ASSUME_NONNULL_BEGIN

@implementation OFXMLElement
{
    NSMutableArray * _Nullable _children;
    NSMutableArray * _Nullable _attributeOrder;
    NSMutableDictionary * _Nullable _attributes;
    BOOL _markedAsReferenced;
}

- initWithName:(NSString *)name attributeOrder:(nullable NSMutableArray *)attributeOrder attributes:(nullable NSMutableDictionary *)attributes; // RECIEVER TAKES OWNERSHIP OF attributeOrder and attributes!
{
    if (!(self = [super init]))
        return nil;

    _name = [name copy];
    
    // We take ownership of these instead of making new collections.  If nil, they'll be lazily created.
    _attributeOrder = [attributeOrder retain];
    _attributes = [attributes retain];
    
    // _children is lazily allocated

    return self;
}

- initWithName:(NSString *)name;
{
    return [self initWithName:name attributeOrder:nil attributes:nil];
}

- (void) dealloc;
{
    [_name release];
    [_children release];
    [_attributeOrder release];
    [_attributes release];
    [super dealloc];
}

- (id)deepCopy;
{
    return [self deepCopyWithName:_name];
}

- (OFXMLElement *)deepCopyWithName:(NSString *)name;
{
    OFXMLElement *newElement = [[OFXMLElement alloc] initWithName:name];
    
    if (_attributeOrder != nil)
        newElement->_attributeOrder = [[NSMutableArray alloc] initWithArray:_attributeOrder];
    
    if (_attributes != nil)
        newElement->_attributes = [_attributes mutableCopy];	// don't need a deep copy because all the attributes are non-mutable strings, but we don need a unique copy of the attributes dictionary

    for (id child in _children) {
        if ([child isKindOfClass:[OFXMLElement class]]) {
            id copiedChild = [child deepCopy];
            [newElement appendChild:copiedChild];
            [copiedChild release];
        } else {
            [newElement appendChild:child];
        }
    }

    return newElement;
}

- (NSUInteger)childrenCount;
{
    return [_children count];
}

- (id)childAtIndex:(NSUInteger)childIndex;
{
    return [_children objectAtIndex: childIndex];
}

- (id)lastChild;
{
    return [_children lastObject];
}

- (NSUInteger)indexOfChildIdenticalTo:(id)child;
{
    return [_children indexOfObjectIdenticalTo:child];
}

- (void)insertChild:(id)child atIndex:(NSUInteger)childIndex;
{
    if (!_children) {
        OBASSERT(childIndex == 0); // Else, certain doom
        _children = [[NSMutableArray alloc] initWithObjects:&child count:1];
    }
    [_children insertObject:child atIndex:childIndex];
}

- (void)appendChild:(id)child;  // Either a OFXMLElement or an NSString
{
    OBPRECONDITION([child respondsToSelector:@selector(appendXML:withParentWhiteSpaceBehavior:document:level:error:)]);

    if (!_children)
        _children = [[NSMutableArray alloc] initWithObjects:&child count:1];
    else
        [_children addObject:child];
}

- (void)removeChild:(id)child;
{
    OBPRECONDITION([child isKindOfClass:[NSString class]] || [child isKindOfClass:[OFXMLElement class]]);

    [_children removeObjectIdenticalTo:child];
}

- (void)removeChildAtIndex:(NSUInteger)childIndex;
{
    [_children removeObjectAtIndex:childIndex];
}

- (void)removeAllChildren;
{
    [_children removeAllObjects];
}

- (void)setChildren:(NSArray *)children;
{
#ifdef OMNI_ASSERTIONS_ON
    {
        for (id child in children)
            OBPRECONDITION([child respondsToSelector:@selector(appendXML:withParentWhiteSpaceBehavior:document:level:error:)]);
    }
#endif

    if (_children)
        [_children setArray:children];
    else if ([children count] > 0)
        _children = [[NSMutableArray alloc] initWithArray:children];
}

- (void)sortChildrenUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    [_children sortUsingFunction:comparator context:context];
}

// TODO: Really need a common superclass for OFXMLElement and OFXMLFrozenElement
- (OFXMLElement *)firstChildNamed:(NSString *)childName;
{
    for (id child in _children) {
        if ([child respondsToSelector:@selector(name)]) {
            NSString *name = [child name];
            if ([name isEqualToString:childName])
                return child;
        }
    }

    return nil;
}

// Does a bunch of -firstChildNamed: calls with each name split by '/'.  This isn't XPath, just a convenience.  Don't put a '/' at the beginning since there is always relative to the receiver.
- (OFXMLElement *)firstChildAtPath:(NSString *)path;
{
    OBPRECONDITION([path hasPrefix:@"/"] == NO);
    
    // Not terribly efficient.  Might use CF later to avoid autoreleases at least.
    NSArray *pathComponents = [path componentsSeparatedByString:@"/"];

    OFXMLElement *currentElement = self;
    for (NSString *pathElement in pathComponents)
        currentElement = [currentElement firstChildNamed:pathElement];
    return currentElement;
}

- (OFXMLElement *)firstChildWithAttribute:(NSString *)attributeName value:(NSString *)value;
{
    OBPRECONDITION(attributeName);
    OBPRECONDITION(value); // Can't look for unset attributes for now.
    
    for (id child in _children) {
        if ([child respondsToSelector:@selector(attributeNamed:)]) {
            NSString *attributeValue = [child attributeNamed:attributeName];
            if ([value isEqualToString:attributeValue])
                return child;
        }
    }
    
    return nil;
}

- (NSArray *)attributeNames;
{
    return _attributeOrder;
}

- (NSString *)attributeNamed:(NSString *)name;
{
    return [_attributes objectForKey: name];
}

- (void)setAttribute:(NSString *)name string:(nullable NSString *)value;
{
    if (!_attributeOrder) {
        OBASSERT(!_attributes);
        _attributeOrder = [[NSMutableArray alloc] init];
        _attributes = [[NSMutableDictionary alloc] init];
    }

    OBASSERT([_attributeOrder count] == [_attributes count]);

    if (value) {
        if (![_attributes objectForKey:name])
            [_attributeOrder addObject:name];
        id copy = [value copy];
        [_attributes setObject:copy forKey:name];
        [copy release];
    } else {
        [_attributeOrder removeObject:name];
        [_attributes removeObjectForKey:name];
    }
}

- (void) setAttribute: (NSString *) name value: (nullable id) value;
{
    [self setAttribute: name string: [value description]]; // For things like NSNumbers
}

- (void) setAttribute: (NSString *) name integer: (int) value;
{
    NSString *str;
    str = [[NSString alloc] initWithFormat: @"%d", value];
    [self setAttribute: name string: str];
    [str release];
}

- (void) setAttribute: (NSString *) name real: (float) value;  // "%g"
{
    [self setAttribute: name real: value format: @"%g"];
}

- (void) setAttribute: (NSString *) name real: (float) value format: (NSString *) formatString;
{
    NSString *str = [[NSString alloc] initWithFormat: formatString, value];
    [self setAttribute: name string: str];
    [str release];
}

- (void)setAttribute: (NSString *) name double: (double) value;  // "%.15g"
{
    OBASSERT(DBL_DIG == 15);
    [self setAttribute: name double: value format: @"%.15g"];
}

- (void)setAttribute: (NSString *) name double: (double) value format: (NSString *) formatString;
{
    NSString *str = [[NSString alloc] initWithFormat: formatString, value];
    [self setAttribute: name string: str];
    [str release];
}

- (NSString *)stringValueForAttributeNamed:(NSString *)name defaultValue:(NSString *)defaultValue;
{
    NSString *value = [self attributeNamed:name];
    return value ? value : defaultValue;
}

- (int)integerValueForAttributeNamed:(NSString *)name defaultValue:(int)defaultValue;
{
    NSString *value = [self attributeNamed:name];
    return value ? [value intValue] : defaultValue;
}

- (float)realValueForAttributeNamed:(NSString *)name defaultValue:(float)defaultValue;
{
    NSString *value = [self attributeNamed:name];
    return value ? [value floatValue] : defaultValue;
}

- (double)doubleValueForAttributeNamed:(NSString *)name defaultValue:(double)defaultValue;
{
    NSString *value = [self attributeNamed:name];
    return value ? [value doubleValue] : defaultValue;
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingString:(nullable NSString *)contents;
{
    OFXMLElement *child = [[OFXMLElement alloc] initWithName: elementName];

    if (!OFIsEmptyString(contents))
        [child appendChild: contents];
    [self appendChild: child];
    [child release];
    return child;
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingInteger:(int)contents;
{
    NSString *str = [[NSString alloc] initWithFormat: @"%d", contents];
    OFXMLElement *child = [self appendElement: elementName containingString: str];
    [str release];
    return child;
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingReal:(float)contents; // "%g"
{
    return [self appendElement: elementName containingReal: contents format: @"%g"];
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingReal:(float)contents format:(NSString *)formatString;
{
    NSString *str = [[NSString alloc] initWithFormat: formatString, contents];
    OFXMLElement *child = [self appendElement: elementName containingString: str];
    [str release];
    return child;
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingDouble:(double)contents; // "%.15g"
{
    OBASSERT(DBL_DIG == 15);
    return [self appendElement: elementName containingDouble: contents format: @"%.15g"];
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingDouble:(double) contents format:(NSString *) formatString;
{
    NSString *str = [[NSString alloc] initWithFormat: formatString, contents];
    OFXMLElement *child = [self appendElement: elementName containingString: str];
    [str release];
    return child;
}

- (OFXMLElement *)appendElement:(NSString *)elementName containingDate:(NSDate *)date;
{
    return [self appendElement:elementName containingString:[date xmlString]];
}

- (void) removeAttributeNamed: (NSString *) name;
{
    if ([_attributes objectForKey: name]) {
        [_attributeOrder removeObject: name];
        [_attributes removeObjectForKey: name];
    }
}

- (void)sortAttributesUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    [_attributeOrder sortUsingFunction:comparator context:context];
}

- (void)sortAttributesUsingSelector:(SEL)comparator;
{
    [_attributeOrder sortUsingSelector:comparator];
}

- (void)markAsReferenced;
{
    _markedAsReferenced = 1;
}

- (BOOL)shouldIgnore;
{
    if (_ignoreUnlessReferenced)
        return !_markedAsReferenced;
    return NO;
}

- (void)applyFunction:(OFXMLElementApplier)applier context:(void *)context;
{
    // We are an element
    applier(self, context);
    
    for (id child in _children) {
	if ([child respondsToSelector:_cmd])
	    [(OFXMLElement *)child applyFunction:applier context:context];
    }
}

- (void)applyBlock:(OFXMLElementApplierBlock)applierBlock;
{
    OBPRECONDITION(applierBlock != nil);
    
    applierBlock(self);
    
    for (id child in _children) {
	if ([child respondsToSelector:_cmd])
	    [(OFXMLElement *)child applyBlock:applierBlock];
    }
}

- (nullable NSData *)xmlDataAsFragment:(NSError **)outError; // Mostly useful for debugging since this assumes no whitespace is important
{
    OFXMLWhitespaceBehavior *whitespace = [[OFXMLWhitespaceBehavior alloc] init];
    [whitespace setBehavior:OFXMLWhitespaceBehaviorTypeIgnore forElementName:[self name]];
    
    NSError *error = nil;
    OFXMLDocument *doc = [[OFXMLDocument alloc] initWithRootElement:self dtdSystemID:NULL dtdPublicID:nil whitespaceBehavior:whitespace stringEncoding:kCFStringEncodingUTF8 error:&error];
    if (!doc) {
        OBASSERT_NOT_REACHED("We always pass the same input parameters, so this should never error out");
    }
    
    [whitespace release];
    
    NSData *xml = [doc xmlDataAsFragment:outError];
    [doc release];
    
    return xml;
}

#pragma mark - NSObject (OFXMLWriting)

- (BOOL)appendXML:(struct _OFXMLBuffer *)xml withParentWhiteSpaceBehavior:(OFXMLWhitespaceBehaviorType)parentBehavior document:(OFXMLDocument *)doc level:(unsigned int)level error:(NSError **)outError;
{
    OFXMLWhitespaceBehaviorType whitespaceBehavior;

    if (_ignoreUnlessReferenced && !_markedAsReferenced)
        return YES; // trivial success

    whitespaceBehavior = [[doc whitespaceBehavior] behaviorForElementName: _name];
    if (whitespaceBehavior == OFXMLWhitespaceBehaviorTypeAuto)
        whitespaceBehavior = parentBehavior;

    OFXMLBufferAppendUTF8CString(xml, "<");
    OFXMLBufferAppendString(xml, (__bridge CFStringRef)_name);
    
    if (_attributeOrder) {
        // Quote the attribute values
        CFStringEncoding encoding = [doc stringEncoding];
        
        for (NSString *name in _attributeOrder) {
            NSString *value = [_attributes objectForKey:name];

            OBASSERT(value); // If we write out <element key>, libxml will hate us. This shouldn't happen, but it has once.
            if (!value)
                continue;
            
            OBASSERT(![value containsCharacterInSet:[NSString discouragedXMLCharacterSet]]);
            
            OFXMLBufferAppendUTF8CString(xml, " ");
            OFXMLBufferAppendString(xml, (__bridge CFStringRef)name);
            
            if (value) {
                OFXMLBufferAppendUTF8CString(xml, "=\"");
                NSString *quotedString = OFXMLCreateStringWithEntityReferencesInCFEncoding(value, OFXMLBasicEntityMask, nil, encoding);
                OFXMLBufferAppendString(xml, (__bridge CFStringRef)quotedString);
                [quotedString release];
                OFXMLBufferAppendUTF8CString(xml, "\"");
            }
        }
    }

    BOOL hasWrittenChild = NO;
    BOOL doIntenting = NO;
    
    // See if any of our children are non-ignored and use this for isEmpty instead of the plain count
    for (id child in _children) {
        if ([child respondsToSelector:@selector(shouldIgnore)] && [child shouldIgnore])
            continue;
        
        // If we have actual element children and whitespace isn't important for this node, do some formatting.
        // We will produce output that is a little strange for something like '<x>foo<y/></x>' or any other mix of string and element children, but usually whitespace is important in this case and it won't be an issue.
        if (whitespaceBehavior == OFXMLWhitespaceBehaviorTypeIgnore)  {
            doIntenting = [child xmlRepresentationCanContainChildren];
        }

        // Close off the parent tag if this is the first child
        if (!hasWrittenChild)
            OFXMLBufferAppendUTF8CString(xml, ">");
        
        if (doIntenting) {
            OFXMLBufferAppendUTF8CString(xml, "\n");
            OFXMLBufferAppendSpaces(xml, 2*(level + 1));
        }

        if (![child appendXML:xml withParentWhiteSpaceBehavior:whitespaceBehavior document:doc level:level+1 error:outError])
            return NO;

        hasWrittenChild = YES;
    }

    if (doIntenting) {
        OFXMLBufferAppendUTF8CString(xml, "\n");
        OFXMLBufferAppendSpaces(xml, 2*level);
    }
    
    if (hasWrittenChild) {
        OFXMLBufferAppendUTF8CString(xml, "</");
        OFXMLBufferAppendString(xml, (__bridge CFStringRef)_name);
        OFXMLBufferAppendUTF8CString(xml, ">");
    } else
        OFXMLBufferAppendUTF8CString(xml, "/>");
    
    return YES;
}

- (BOOL)xmlRepresentationCanContainChildren;
{
    return YES;
}

- (NSObject *)copyFrozenElement;
{
    // Frozen elements don't have any support for marking referenced
    return [[OFXMLFrozenElement alloc] initWithName:_name children:_children attributes:_attributes attributeOrder:_attributeOrder];
}

#pragma mark - Comparison

- (BOOL)isEqual:(id)otherObject;
{
    // We don't consider OFXMLFrozenElement or OFXMLUnparsedElement the same, even if they would produce the same output.  Not sure if this is a bug; let's catch this case here to see if it ever hits.
    OBPRECONDITION(![otherObject isKindOfClass:[OFXMLFrozenElement class]] && ![otherObject isKindOfClass:[OFXMLUnparsedElement class]]);
    if (![otherObject isKindOfClass:[OFXMLElement class]])
        return NO;
    
    OFXMLElement *otherElement = otherObject;
    
    if (OFNOTEQUAL(_name, otherElement->_name))
        return NO;
    
    // Allow nil to be equal to empty
    
    if ([_attributeOrder count] != 0 || [otherElement->_attributeOrder count] != 0) {
        // For now, at least, we'll consider elements with the same attributes, but in different orders, to be non-equal.
        if (OFNOTEQUAL(_attributeOrder, otherElement->_attributeOrder))
            return NO;
    }
    if ([_attributes count] != 0 || [otherElement->_attributes count] != 0) {
        if (OFNOTEQUAL(_attributes, otherElement->_attributes))
            return NO;
    }
    
    if ([_children count] != 0 || [otherElement->_children count] != 0) {
        if (OFNOTEQUAL(_children, otherElement->_children))
            return NO;
    }
    
    // Ignoring the flags
    return YES;
}

#pragma mark - Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    [debugDictionary setObject: _name forKey: @"_name"];
    if (_children)
        [debugDictionary setObject: _children forKey: @"_children"];
    if (_attributes) {
        [debugDictionary setObject: _attributeOrder forKey: @"_attributeOrder"];
        [debugDictionary setObject: _attributes forKey: @"_attributes"];
    }

    return debugDictionary;
}

- (NSString *)debugDescription;
{
    NSError *error = nil;
    NSData *data = [self xmlDataAsFragment:&error];
    if (!data) {
        NSLog(@"Error converting element to data: %@", [error toPropertyList]);
        return [error description];
    }
    
    return [NSString stringWithData:data encoding:NSUTF8StringEncoding];
}

@end


@implementation NSObject (OFXMLWritingPartial)

#if 0 // NOT implementing this since our precondition in -appendChild: is easier this way.
- (BOOL)appendXML:(struct _OFXMLBuffer *)xml withParentWhiteSpaceBehavior:(OFXMLWhitespaceBehaviorType)parentBehavior document:(OFXMLDocument *)doc level:(unsigned int)level error:(NSError **)outError;
{
    OBRejectUnusedImplementation([self class], _cmd);
}
#endif

- (BOOL)xmlRepresentationCanContainChildren;
{
    return NO;
}

- (NSObject *)copyFrozenElement;
{
    return [self retain];
}
@end

NS_ASSUME_NONNULL_END
