// Copyright 2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/OAAppearancePropertyListCoder.h>

@import OmniBase;
@import OmniFoundation;

RCS_ID("$Id$");

#import "OAAppearance-Internal.h"
#import "OAAppearancePropertyListCoder-Internal.h"

#import <OmniAppKit/OAAppearance.h>
#import <OmniAppKit/OAColor.h>
#import <OmniAppKit/OAColor-Archiving.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

OB_REQUIRE_ARC

NSString * const OAAppearanceUnknownKeyKey = @"OAAppearanceUnknownKeyKey";
NSString * const OAAppearanceMissingKeyKey = @"OAAppearanceMissingKeyKey";

@interface NSMutableDictionary (PropertyListKeyPathReferrable)
- (void)setObject:(id)anObject forKeyPath:(NSString *)keyPath;
@end

@interface OAAppearancePropertyListClassKeypathExtractor()
/// Assumes instances of Class conform to OAAppearancePropertyListCodeable
- (instancetype)initWithClass:(Class)codeableClass;
@property (nonatomic, readonly) Class codeableClass;
@end

@interface OAAppearancePropertyListCoder ()
@property (nonatomic) NSObject <OAAppearancePropertyListCodeable> *codeable;
@end

@implementation OAAppearancePropertyListClassKeypathExtractor

- (instancetype)initWithClass:(Class)codeableClass;
{
    OBPRECONDITION([codeableClass conformsToProtocol:@protocol(OAAppearancePropertyListCodeable)]);
    self = [super init];
    if (self != nil) {
        _codeableClass = codeableClass;
    }
    return self;
}

#pragma mark Testable Private API

- (NSMutableSet <NSString *> *)_keyPaths;
{
    NSMutableSet *result = [self _localKeyPaths];
    [result unionSet:[self _inheritedKeyPaths]];
    return result;
}

- (NSMutableSet <NSString *> *)_localDynamicPropertyNames;
{
    NSMutableSet *result = [NSMutableSet new];
    
    unsigned int propertyCount;
    objc_property_t *allProperties = class_copyPropertyList(self.codeableClass, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = allProperties[i];
        SEL selector = sel_getUid(property_getName(property));
        char *propertyIsDynamic = property_copyAttributeValue(property, "D");
        char *propertyIsReadOnly = property_copyAttributeValue(property, "R");
        if (propertyIsDynamic != NULL && propertyIsReadOnly != NULL) {
            NSString *propertyName = NSStringFromSelector(selector);
            [result addObject:propertyName];
        }
        free(propertyIsReadOnly);
        free(propertyIsDynamic);
    }
    
    free(allProperties);
    
    if ([self.codeableClass respondsToSelector:@selector(localDynamicPropertyNamesToOmit)]) {
        [result minusSet:[self.codeableClass localDynamicPropertyNamesToOmit]];
    }
    
    return result;
}

- (NSMutableSet <NSString *> *)_localKeyPaths;
{
    NSMutableSet *result = [self _localDynamicPropertyNames];

    if ([self.codeableClass respondsToSelector:@selector(additionalLocalKeyPaths)]) {
        NSSet *additionalLocalKeyPaths = [self.codeableClass additionalLocalKeyPaths];
        [result unionSet:additionalLocalKeyPaths];
    }
    
    return result;
}

- (NSMutableSet <NSString *> *)_inheritedKeyPaths;
{
    if ([self.codeableClass respondsToSelector:@selector(includeSuperclassKeyPaths)] && ![self.codeableClass includeSuperclassKeyPaths]) {
        return [NSMutableSet new];
    }
    
    Class superclass = [self.codeableClass superclass];
    if (![superclass conformsToProtocol:@protocol(OAAppearancePropertyListCodeable)]) {
        return [NSMutableSet new];
    }
    
    OAAppearancePropertyListClassKeypathExtractor *superExtractor = [[OAAppearancePropertyListClassKeypathExtractor alloc] initWithClass:superclass];
    NSMutableSet *result = [superExtractor _keyPaths];
    return result;
}

@end

@implementation OAAppearancePropertyListCoder
{
    OAAppearancePropertyListClassKeypathExtractor *_keyExtractor;
}

- (instancetype)initWithCodeable:(NSObject <OAAppearancePropertyListCodeable> *)codeable;
{
    self = [super init];
    if (self != nil) {
        _codeable = codeable;
    }
    return self;
}

#pragma mark Public API

- (NSDictionary <NSString *, NSObject *> *)propertyList;
{
    NSSet *keyPaths = [self.keyExtractor _keyPaths];
    NSMutableDictionary <NSString *, NSObject *> *result = [NSMutableDictionary new];
    for (NSString *keypath in keyPaths) {
        NSObject *value = [self _encodedValueForKeyPath:keypath];
        [result setObject:value forKeyPath:keypath];
    }
    return result;
}

- (NSDictionary <NSString *, NSArray <NSString *> *> * _Nullable)invalidKeysInPropertyList:(NSDictionary <NSString *, NSObject *> *)propertyList;
{
    // TODO: Return missing keys (OAAppearanceMissingKeyKey) and extra keys (OAAppearanceUnknownKeyKey) <bug:///126282> (Feature: Present list of any extra and missing keys to user when importing style file)
    // TODO: return nil if ok
    return nil;
}

#pragma mark Private API

- (NSObject *)_encodedValueForKeyPath:(NSString *)keyPath;
{
    // We separate encoding lookup from value encoding because the current value may be based on subclass overriding, while the desired export encoding is defined by a superclass.
    OAAppearanceValueEncoding encoding = [self.codeable valueEncodingForKeyPath:keyPath];
    id value = [self.codeable valueForKeyPath:keyPath];
    switch (encoding) {
        case OAAppearanceValueEncodingRaw:
            return value;
        case OAAppearanceValueEncodingWhiteColor:
        case OAAppearanceValueEncodingRGBColor: {
            OA_SYSTEM_COLOR_CLASS *color = OB_CHECKED_CAST(OA_SYSTEM_COLOR_CLASS, value);
            OAColor *oaColor = [OAColor colorWithPlatformColor:color];
            NSObject *result = [oaColor propertyListRepresentationWithNumberComponentsOmittingDefaultValues:NO];
            return result;
        }
        case OAAppearanceValueEncodingHSBColor: {
            // OAColor doesn't handle HSB, so we need to special case it
            OA_SYSTEM_COLOR_CLASS *color = OB_CHECKED_CAST(OA_SYSTEM_COLOR_CLASS, value);
            CGFloat h = 0.0f;
            CGFloat s = 0.0f;
            CGFloat b = 0.0f;
            CGFloat a = 0.0f;
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
            // Mac
            NSColor *colorInAppropriateSpace = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
            if (colorInAppropriateSpace != nil) {
                [colorInAppropriateSpace getHue:&h saturation:&s brightness:&b alpha:&a];
            }
#else
            // iOS
            BOOL success = [color getHue:&h saturation:&s brightness:&b alpha:&a];
            OB_UNUSED_VALUE(success);
            OBASSERT(success, @"expect to be able to convert to HSB if we were defined in HSB color space");
#endif
            return @{@"h": @(h), @"s": @(s), @"b": @(b), @"a": @(a)};
        }
        case OAAppearanceValueEncodingEdgeInsets: {
            OA_SYSTEM_EDGE_INSETS_STRUCT insets;
            [OB_CHECKED_CAST(NSValue, value) getValue:&insets];
            return @{@"top": @(insets.top), @"left": @(insets.left), @"bottom": @(insets.bottom), @"right": @(insets.right)};
        }
        case OAAppearanceValueEncodingSize: {
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
            // Mac
            CGSize size = OB_CHECKED_CAST(NSValue, value).sizeValue;
#else
            // iOS
            CGSize size = OB_CHECKED_CAST(NSValue, value).CGSizeValue;
#endif
            return @{ @"width": @(size.width), @"height": @(size.height) };
        }
        case OAAppearanceValueEncodingCustom: {
            if ([self.codeable respondsToSelector:@selector(customEncodingForKeyPath:)]) {
                NSObject *result = [self.codeable customEncodingForKeyPath:keyPath];
                return result;
            } else {
                @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Codeable instance %@ requests custom encoding but fails to implement “%@”", NSStringFromClass([self.codeable class]), NSStringFromSelector(@selector(customEncodingForKeyPath:))] userInfo:nil];
            }
        }
    }
}

@end

@implementation OAAppearancePropertyListCoder (PrivateTestable)
- (OAAppearancePropertyListClassKeypathExtractor *)keyExtractor
{
    if (_keyExtractor == nil) {
        Class cls = self.codeable.class;
        if ([OAAppearance isReifyingClass:cls]) {
            // If it's a reifying class instance, then the conformance to OAAppearancePropertyListCodeable must be on the superclass. That's also where the properties must be declared. So, climb up to the superclass.
            cls = [cls superclass];
            OBASSERT_NOTNULL(cls);
            OBASSERT([cls conformsToProtocol:@protocol(OAAppearancePropertyListCodeable)]);
        }
        
        _keyExtractor = [[OAAppearancePropertyListClassKeypathExtractor alloc] initWithClass:cls];
    }
    return _keyExtractor;
}

@end

@implementation NSMutableDictionary (PropertyListKeyPathReferrable)
- (void)setObject:(id)object forKeyPath:(NSString *)keyPath;
{
    NSArray <NSString *> *keyPathComponents = OFKeysForKeyPath(keyPath);
    [self _setObject:object forKeyPathComponents:keyPathComponents fromIndex:0];
}

- (void)_setObject:(id)object forKeyPathComponents:(NSArray <NSString *> *)keyPathComponents fromIndex:(NSUInteger)index;
{
    if (index >= keyPathComponents.count) {
        NSString *reason = [NSString stringWithFormat:@"component index %@ out of bounds for keyPath: %@", @(index), [keyPathComponents componentsJoinedByString:@"."]];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
    }

    BOOL isLastComponent = index == keyPathComponents.count - 1;
    NSString *currentComponent = keyPathComponents[index];
    if (isLastComponent) {
        [self setObject:object forKey:currentComponent];
        return;
    }
    
    NSMutableDictionary *subdictionary = [self objectForKey:currentComponent];
    if (subdictionary != nil && ![subdictionary isKindOfClass:[NSMutableDictionary class]]) {
        NSString *reason = [NSString stringWithFormat:@"Attempting to set object for key path “%@” that passes through a value at key “%@” that is not a mutable dictionary: %@", [keyPathComponents componentsJoinedByString:@"."], currentComponent, subdictionary];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
    }
    
    if (subdictionary == nil) {
        subdictionary = [NSMutableDictionary new];
        [self setObject:subdictionary forKey:currentComponent];
    }
    
    [subdictionary _setObject:object forKeyPathComponents:keyPathComponents fromIndex:index + 1];
}
@end


NS_ASSUME_NONNULL_END
