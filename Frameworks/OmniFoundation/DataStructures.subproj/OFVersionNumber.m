// Copyright 2004-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFVersionNumber.h>

#import <OmniBase/OBObject.h> // For -debugDictionary
#import <OmniFoundation/OFStringScanner.h>
#import <OmniFoundation/NSString-OFReplacement.h>

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#import <UIKit/UIDevice.h>
#else
#import <CoreServices/CoreServices.h>
#endif

RCS_ID("$Id$");

@implementation OFVersionNumber

+ (OFVersionNumber *)mainBundleVersionNumber;
{
    static OFVersionNumber *mainBundleVersionNumber = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        mainBundleVersionNumber = [[OFVersionNumber alloc] initWithVersionString:versionString];
    });
    return mainBundleVersionNumber;
}

+ (OFVersionNumber *)userVisibleOperatingSystemVersionNumber;
{
    static OFVersionNumber *userVisibleOperatingSystemVersionNumber = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if TARGET_OS_IPHONE
        UIDevice *device = [UIDevice currentDevice];
        NSString *versionString = device.systemVersion;
#else
        // There is no good replacement for this API right now. NSProcessInfo's -operatingSystemVersionString is explicitly documented as not appropriate for parsing. We could look in "/System/Library/CoreServices/SystemVersion.plist", but that seems fragile. We could get the sysctl kern.osrevision and map it ourselves, but that seems terrible too.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        SInt32 major, minor, bug;
        Gestalt(gestaltSystemVersionMajor, &major);
        Gestalt(gestaltSystemVersionMinor, &minor);
        Gestalt(gestaltSystemVersionBugFix, &bug);
#pragma clang diagnostic pop
        
        NSString *versionString = [NSString stringWithFormat:@"%d.%d.%d", major, minor, bug];
#endif
        
        // TODO: Add a -initWithComponents:count:?
        userVisibleOperatingSystemVersionNumber = [[self alloc] initWithVersionString:versionString];
    });
    return userVisibleOperatingSystemVersionNumber;
}

static BOOL isOperatingSystemLaterThanVersionString(NSString *versionString) __attribute__((unused)); // Can end up being unused when we require the latest version available of a platform's OS.

static BOOL isOperatingSystemLaterThanVersionString(NSString *versionString)
    // NOTE: Don't expose this directly! Instead, declare a new method (such as +isOperatingSystemLionOrLater) which caches its result (and which will give us nice warnings to find later when we decide to retire support for pre-Lion).
    // This implementation is meant to be called during initialization, not repeatedly, since this allocates and discards an instance.
{
    OFVersionNumber *version = [[OFVersionNumber alloc] initWithVersionString:versionString];
    BOOL isLater = ([[OFVersionNumber userVisibleOperatingSystemVersionNumber] compareToVersionNumber:version] != NSOrderedAscending);
    [version release];
    return isLater;
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE

// We require iOS 9.0 currently

#else

+ (BOOL)isOperatingSystemElCapitanOrLater; // 10.11
{
    static BOOL isLater;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isLater = isOperatingSystemLaterThanVersionString(@"10.11");
    });

    return isLater;
}

#endif

/* Initializes the receiver from a string representation of a version number.  The input string may have an optional leading 'v' or 'V' followed by a sequence of positive integers separated by '.'s.  Any trailing component of the input string that doesn't match this pattern is ignored.  If no portion of this string matches the pattern, nil is returned. */
- initWithVersionString:(NSString *)versionString;
{
    OBPRECONDITION([versionString isKindOfClass:[NSString class]]);
    
    // Input might be from a NSBundle info dictionary that could be misconfigured, so check at runtime too
    if (!versionString || ![versionString isKindOfClass:[NSString class]]) {
        [self release];
        return nil;
    }

    if (!(self = [super init]))
        return nil;

    _originalVersionString = [versionString copy];
    
    NSMutableString *cleanVersionString = [[NSMutableString alloc] init];
    OFStringScanner *scanner = [[OFStringScanner alloc] initWithString:versionString];
    unichar c = scannerPeekCharacter(scanner);
    if (c == 'v' || c == 'V')
        scannerSkipPeekedCharacter(scanner);

    NSUInteger componentsBufSize = 40; // big enough for five 64-bit version number components
    _components = malloc(componentsBufSize);
    
    while (scannerHasData(scanner)) {
        // TODO: Add a OFCharacterScanner method that allows you specify the maximum uint32 value (and a parameterless version that uses UINT_MAX) and passes back a BOOL indicating success (since any uint32 would be valid).
        NSUInteger location = scannerScanLocation(scanner);
        NSUInteger component = [scanner scanUnsignedIntegerMaximumDigits:10];

        if (location == scannerScanLocation(scanner))
            // Failed to scan integer
            break;

        [cleanVersionString appendFormat: _componentCount ? @".%lu" : @"%lu", component];

        _componentCount++;
        if (_componentCount*sizeof(*_components) > componentsBufSize) {
            componentsBufSize = _componentCount*sizeof(*_components);
            _components = realloc(_components, componentsBufSize);
        }
        _components[_componentCount - 1] = component;

        c = scannerPeekCharacter(scanner);
        if (c != '.')
            break;
        scannerSkipPeekedCharacter(scanner);
    }

    // If we got "x.y.0.0.0" as input, strip off the trailing .0 components.
    NSString *trimmedVersionString = [[cleanVersionString copy] autorelease];
    [cleanVersionString release];
    
    while ([trimmedVersionString hasSuffix:@".0"]) {
        trimmedVersionString = [trimmedVersionString stringByRemovingSuffix:@".0"];
    }
    
    if ([trimmedVersionString isEqualToString:_originalVersionString])
        _cleanVersionString = [_originalVersionString retain];
    else
        _cleanVersionString = [trimmedVersionString copy];
    
    [scanner release];

    if (_componentCount == 0) {
        // Failed to parse anything and we don't allow empty version strings.  For now, we'll not assert on this, since people might want to use this to detect if a string begins with a valid version number.
        [self release];
        return nil;
    }
    
    return self;
}

- (void)dealloc;
{
    [_originalVersionString release];
    [_cleanVersionString release];
    if (_components)
        free(_components);
    [super dealloc];
}


#pragma mark -
#pragma mark API

- (NSString *)originalVersionString;
{
    return _originalVersionString;
}

- (NSString *)cleanVersionString;
{
    return _cleanVersionString;
}

- (NSString *)prettyVersionString; // NB: This version string can't be parsed back into an OFVersionNumber. For display only!
{
    // The current Omni convention is to append the SVN revision number to the version number at build time, so that we don't have to explicitly increment things for nightlies and so on. This is ugly, though, so let's not display it like that.
    if (_componentCount >= 3 && _components[_componentCount-2] == 0 && _components[_componentCount-1] > 100) {
        NSMutableString *buf = [NSMutableString string];
        for(NSUInteger component = 0; component < (_componentCount-2); component ++) {
            if (component > 0)
                [buf appendString:@"."];
            [buf appendFormat:@"%u", (unsigned int)_components[component]];
        }
        [buf appendFormat:@" r%u", (unsigned int)_components[_componentCount-1]];
        return buf;
    } else {
        return [self cleanVersionString];
    }
}

- (NSUInteger)componentCount;
{
    return _componentCount;
}

- (NSUInteger)componentAtIndex:(NSUInteger)componentIndex;
{
    // This treats the version as a infinite sequence ending in "...0.0.0.0", making comparison easier
    if (componentIndex < _componentCount)
        return _components[componentIndex];
    return 0;
}

#pragma mark -
#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];
}

#pragma mark -
#pragma mark Comparison

- (NSUInteger)hash;
{
    return [_cleanVersionString hash];
}

- (BOOL)isEqual:(id)otherObject;
{
    if (![otherObject isKindOfClass:[OFVersionNumber class]])
        return NO;
    return [self compareToVersionNumber:(OFVersionNumber *)otherObject] == NSOrderedSame;
}

- (NSComparisonResult)compare:(id)otherObject;
{
    if (!otherObject || [otherObject isKindOfClass:[OFVersionNumber class]])
        return [self compareToVersionNumber:otherObject];
    
    if ([otherObject isKindOfClass:[NSString class]]) {
        OFVersionNumber *otherNumber = [[[OFVersionNumber alloc] initWithVersionString:otherObject] autorelease];
        return [self compareToVersionNumber:otherNumber];
    }
    
    // We could maybe make some attempt with NSNumber at some point, but the conversion from a floating point number a dotted sequence of integers is iffy.
    return NSOrderedAscending;
}

- (NSComparisonResult)compareToVersionNumber:(OFVersionNumber *)otherVersion;
{
    if (!otherVersion)
        return NSOrderedAscending;

    NSUInteger componentIndex, componentCount = MAX(_componentCount, [otherVersion componentCount]);
    for (componentIndex = 0; componentIndex < componentCount; componentIndex++) {
        NSUInteger component = [self componentAtIndex:componentIndex];
        NSUInteger otherComponent = [otherVersion componentAtIndex:componentIndex];

        if (component < otherComponent)
            return NSOrderedAscending;
        else if (component > otherComponent)
            return NSOrderedDescending;
    }

    return NSOrderedSame;
}

#pragma mark -
#pragma mark Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [super debugDictionary];

    [dict setObject:_originalVersionString forKey:@"originalVersionString"];
    [dict setObject:_cleanVersionString forKey:@"cleanVersionString"];

    NSMutableArray *components = [NSMutableArray array];
    NSUInteger componentIndex;
    for (componentIndex = 0; componentIndex < _componentCount; componentIndex++)
        [components addObject:[NSNumber numberWithUnsignedInteger:_components[componentIndex]]];
    [dict setObject:components forKey:@"components"];

    return dict;
}

@end

NSString * const OFVersionNumberTransformerName = @"OFVersionNumberTransformer";

@interface OFVersionNumberTransformer : NSValueTransformer
@end

@implementation OFVersionNumberTransformer

+ (void)didLoad;
{
    OFVersionNumberTransformer *instance = [[self alloc] init];
    [NSValueTransformer setValueTransformer:instance forName:@"OFVersionNumberTransformer"];
    [instance release];
}

+ (Class)transformedValueClass;
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation;
{
    return YES;
}

- (id)transformedValue:(id)value;
{
    if ([value isKindOfClass:[OFVersionNumber class]])
        return [(OFVersionNumber *)value cleanVersionString];
    return nil;
}

- (id)reverseTransformedValue:(id)value;
{
    if ([value isKindOfClass:[NSString class]])
        return [[[OFVersionNumber alloc] initWithVersionString:value] autorelease];
    return nil;
}

@end
