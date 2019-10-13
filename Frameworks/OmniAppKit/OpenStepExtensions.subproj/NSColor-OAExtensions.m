// Copyright 2000-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/NSColor-OAExtensions.h>
#import <OmniAppKit/OAColorSpaceManager.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OmniAppKit/OAColorProfile.h>
#import <OmniAppKit/OAColor-Archiving.h>
#import <OmniAppKit/NSImage-OAExtensions.h>

RCS_ID("$Id$")

static NSColorList *classicCrayonsColorList(void)
{
    static NSColorList *classicCrayonsColorList = nil;
    
    if (classicCrayonsColorList == nil) {
	NSString *colorListName = NSLocalizedStringFromTableInBundle(@"Classic Crayons", @"OmniAppKit", OMNI_BUNDLE, "color list name");
	NSColorList *originalColorList = [[NSColorList alloc] initWithName:colorListName fromFile:[OMNI_BUNDLE pathForResource:@"Classic Crayons" ofType:@"clr"]];
        classicCrayonsColorList = [[NSColorList alloc] initWithName:colorListName];
        NSColorSpace *sRGBColorSpace = [NSColorSpace extendedSRGBColorSpace];
        for (NSString *colorName in originalColorList.allKeys) {
            NSColor *originalColor = [originalColorList colorWithKey:colorName];
            NSColor *sRGBColor = [originalColor colorUsingColorSpace:sRGBColorSpace];
            [classicCrayonsColorList setColor:sRGBColor forKey:colorName];
        }
        [originalColorList release];
    }
    return classicCrayonsColorList;
}

@interface NSColorPicker (Private)
- (void)_switchToPicker:(NSColorPicker *)picker;
- (void)attachColorList:(id)list makeSelected:(BOOL)flag;
- (void)refreashUI; // sic
@end

// Adding a color list to the color panel when it is NOT in list mode, will not to anything.  Radar #4341924.
@implementation NSColorPanel (OAHacks)

static void (*originalSwitchToPicker)(id self, SEL _cmd, NSColorPicker *picker);

OBPerformPosing(^{
    Class self = objc_getClass("NSColorPanel");
    // No public API for this
    if ([self instancesRespondToSelector:@selector(_switchToPicker:)])
	originalSwitchToPicker = (typeof(originalSwitchToPicker))OBReplaceMethodImplementationWithSelector(self, @selector(_switchToPicker:), @selector(_replacement_switchToPicker:));
});

- (void)_replacement_switchToPicker:(NSColorPicker *)picker;
{
    originalSwitchToPicker(self, _cmd, picker);

    static BOOL attached = NO;
    if (!attached && [NSStringFromClass([picker class]) isEqual:@"NSColorPickerPageableNameList"]) {
	attached = YES;
	
	// Look at the (private) preference for which color list to have selected.  If it is the one we are adding, use -attachColorList: (which will select it).  Otherwise, use the (private) -attachColorList:makeSelected: and specify to not select it (otherwise the color list selected when the real code sets up and reads the default will be overridden).  If we fail to select the color list we are adding, though, the picker will show an empty color list (since the real code will have tried to select it before it is added).  Pheh.  See <bug://30338> for some of these issues.  Logged Radar 4640063 to add for asks for -attachColorList:makeSelected: to be public.

	// Sadly, the (private) preference encodes the color list name with a '1' at the beginning.  I have no idea what this is for.  I'm uncomfortable using [defaultColorList hasSuffix:[colorList name]] below since that might match more than one color list.
	NSString *defaultColorList = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSColorPickerPageableNameListDefaults"];
	if ([defaultColorList hasPrefix:@"1"])
	    defaultColorList = [defaultColorList substringFromIndex:1];
	
	NSColorList *colorList = classicCrayonsColorList();
	if ([picker respondsToSelector:@selector(attachColorList:makeSelected:)]) {
	    BOOL select = OFISEQUAL(defaultColorList, [colorList name]);

	    [picker attachColorList:colorList makeSelected:select];
	    if (select && [picker respondsToSelector:@selector(refreashUI)])
		// The picker is in a bad state from trying to select a color list that wasn't there when -restoreDefaults was called.  Passing makeSelected:YES will apparently bail since the picker things that color list is already selected and we'll be left with an empty list of colors displayed.  First, select some other color list if possible.
		[picker refreashUI];
	} else
	    [picker attachColorList:colorList];
    }
}
@end

@implementation NSColor (OAExtensions)

typedef struct {
    BOOL (*component)(void *container, NSString *key, CGFloat *outComponent); // Should only set the output if the key was present.  Returns YES if the key was present.
    NSString * (*string)(void *container, NSString *key);
    NSData * (*data)(void *container, NSString *key);
} OAColorGetters;

// Works for both NSString and NSNumber encoded components
static BOOL _dictionaryComponentGetter(void *container, NSString *key, CGFloat *outComponent)
{
    OBPRECONDITION([(id)container isKindOfClass:[NSDictionary class]]);

    // In some cases we care if we got the default value due to it being missing or whether it was actually in the plist.
    id obj = [(NSMutableDictionary *)container objectForKey:key];
    if (!obj)
        return NO;
    *outComponent = [obj cgFloatValue];
    return YES;
}

static NSString *_dictionaryStringGetter(void *container, NSString *key)
{
    OBPRECONDITION([(id)container isKindOfClass:[NSDictionary class]]);
    NSString *result = [(NSMutableDictionary *)container objectForKey:key];
    OBASSERT(!result || [result isKindOfClass:[NSString class]]);
    return result;
}

static NSData *_dictionaryDataGetter(void *container, NSString *key)
{
    OBPRECONDITION([(id)container isKindOfClass:[NSDictionary class]]);
    id value = [(NSMutableDictionary *)container objectForKey:key];
    if ([value isKindOfClass:[NSData class]]) {
        return value;
    }
    if (![value isKindOfClass:[NSString class]]) {
        OBASSERT_NULL(value, "Unexpected value of class %@", [value class]);
        return nil;
    }
    return [[[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters] autorelease];
}

static NSColorSpace *_defaultGrayColorSpace(void)
{
    static NSColorSpace *colorSpace = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        colorSpace = [[NSColor colorWithWhite:0.5f alpha:1.0f] colorSpace];
    });
    return colorSpace;
}

+ (NSColor *)_colorFromContainer:(void *)container getters:(OAColorGetters)getters withColorSpaceManager:(OAColorSpaceManager *)manager shouldDefaultToGenericSpace:(BOOL)shouldDefaultToGenericSpace;
{
    NSData *data = getters.data(container, @"archive");
    if (data) {
        if ([data isKindOfClass:[NSData class]] && [data length] > 0) {
            NSColor *unarchived = nil;
            @try {
                __autoreleasing NSError *error = nil;
                unarchived = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:data error:&error];
                if (!unarchived) {
                    [error log:@"Error unarchiving color"];
                }
            } @catch (NSException *exc) {
                // possible that a subclass of NSColor has produced this archive and is not present
                NSLog(@"Exception unarchiving NSColor: %@", exc);
            }
            
            if (unarchived)
                return unarchived;
        }
        // otherwise, fallback -- might be a rgb color in the plist too.
    }
    
    NSString *colorSpaceName = getters.string(container, @"space");
    NSColorSpace *colorSpace = nil;
    
    if (colorSpaceName) {
        colorSpace = (manager) ? [manager colorSpaceForName:colorSpaceName] : [OAColorSpaceManager colorSpaceForName:colorSpaceName];
    }
    
    CGFloat alpha = 1.0f;
    if (!getters.component(container, @"a", &alpha)) {
        CGFloat alphaPercent = 100.0f;
        getters.component(container, @"alpha", &alphaPercent);
        alpha = alphaPercent / 100.0f;
    }
    CGFloat v0 = 0, v1 = 0, v2 = 0, v3 = 0;
    BOOL white = NO;
    if (getters.component(container, @"w", &v0)) {
        white = YES;
    } else if (getters.component(container, @"white", &v0)) {
        white = YES;
        v0 = v0/255.0f;
    }
    
    if (white) {
        CGFloat components[2] = {v0,alpha};
        BOOL isDefault = colorSpace == nil;
        if (isDefault)
            colorSpace = shouldDefaultToGenericSpace ? [NSColorSpace genericGrayColorSpace] : _defaultGrayColorSpace();
        else if (colorSpace.colorSpaceModel != NSColorSpaceModelGray)
            colorSpace = _defaultGrayColorSpace();

        NSColor *archivedColor = [NSColor colorWithColorSpace:colorSpace components:components count:2];
        if (isDefault && shouldDefaultToGenericSpace)
            return [archivedColor colorUsingColorSpace:_defaultGrayColorSpace()];
        else
            return archivedColor;
    }

    NSString *catalog = getters.string(container, @"catalog");
    if (catalog) {
        NSString *name = getters.string(container, @"name");
        if ([catalog isKindOfClass:[NSString class]] && [name isKindOfClass:[NSString class]]) {
            NSColor *color = [NSColor colorWithCatalogName:catalog colorName:name];
            if (color)
                return color;
        }
        
        // otherwise, fallback -- might be a rgb color in the plist too.
    }
    
    BOOL RGB = NO;
    if (getters.component(container, @"r", &v0)) {
        getters.component(container, @"g", &v1);
        getters.component(container, @"b", &v2);
        RGB = YES;
    } else if (getters.component(container, @"red", &v0)) {
        getters.component(container, @"green", &v1);
        getters.component(container, @"blue", &v2);
        v0/=255.0f;
        v1/=255.0f;
        v2/=255.0f;
        RGB = YES;
    }
    
    if (RGB) {
        BOOL isDefault = colorSpace == nil;
        if (isDefault)
            colorSpace = shouldDefaultToGenericSpace ? [NSColorSpace genericRGBColorSpace] : [NSColorSpace extendedSRGBColorSpace];
        else if (colorSpace.colorSpaceModel != NSColorSpaceModelRGB)
            colorSpace = [NSColorSpace extendedSRGBColorSpace];

        // Using sSRGB here results in corruption if we are reading a 'generic' blue (0 0 1), since sRGB can't represent this color in the 0..1 range for the components. If we use extended sRGB, we get (0.0168042 0.198351 1.00141), but sRGB clamps the blue to 1.0. Then, if we save the color back out as 'generic' (for older file formats that expect it), we get (0.000110865 0.00176024 0.998218). If we use extended sRGB, our round-tripped color has components (2.16067e-07 0 1), which is close enough.
        CGFloat components[4] = {v0,v1,v2,alpha};
        NSColor *archivedColor = [NSColor colorWithColorSpace:colorSpace components:components count:4];
        if (isDefault && shouldDefaultToGenericSpace)
            return [archivedColor colorUsingColorSpace:[NSColorSpace extendedSRGBColorSpace]];
        else
            return archivedColor;
    }

    BOOL CMYK = NO;
    
    if (getters.component(container, @"c", &v0)) {
        getters.component(container, @"m", &v1);
        getters.component(container, @"y", &v2);
        getters.component(container, @"k", &v3);
        CMYK = YES;
    } else if (getters.component(container, @"cyan", &v0)) {
        getters.component(container, @"magenta", &v1);
        getters.component(container, @"yellow", &v2);
        getters.component(container, @"black", &v3);
        v0 /= 100.0f;
        v1 /= 100.0f;
        v2 /= 100.0f;
        v3 /= 100.0f;
        CMYK = YES;
    }
    
    if (CMYK) {
        CGFloat components[5] = {v0, v1, v2, v3, alpha};
        // No global name for the generic CMYK color space
        if (!colorSpace || [colorSpace colorSpaceModel] != NSColorSpaceModelCMYK)
            return [NSColor colorWithColorSpace:[NSColorSpace genericCMYKColorSpace] components:components count:5];
        return [NSColor colorWithColorSpace:colorSpace components:components count:5];
    }
    
    // There is no HSB/HSV colorspace, but lets allow specifying colors in property lists (for defaults in Info.plist) that way
    if (getters.component(container, @"h", &v0)) {
        getters.component(container, @"s", &v1);
        if (!getters.component(container, @"v", &v2))
            getters.component(container, @"b", &v2);
        
        return [NSColor colorWithHue:v0 saturation:v1 brightness:v2 alpha:alpha];
    } else if (getters.component(container, @"hue", &v0)) {
        getters.component(container, @"saturation", &v1);
        if (!getters.component(container, @"value", &v2))
            getters.component(container, @"brightness", &v2);
        
        return [NSColor colorWithHue:(v0 / 360.0f) saturation:(v1 / 100.0f) brightness:(v2 / 100.0f) alpha:alpha];
    }
    
    NSData *patternData = getters.data(container, @"png");
    if (!patternData)
        patternData = getters.data(container, @"tiff");
    if ([patternData isKindOfClass:[NSData class]]) {
        NSBitmapImageRep *bitmapImageRep = (id)[NSBitmapImageRep imageRepWithData:patternData];
        NSSize imageSize = [bitmapImageRep size];
        if (bitmapImageRep == nil || NSEqualSizes(imageSize, NSZeroSize)) {
            NSLog(@"Warning, could not rebuild pattern color from image rep %@, data %@", bitmapImageRep, patternData);
        } else {
            NSImage *patternImage = [[NSImage alloc] initWithSize:imageSize];
            [patternImage addRepresentation:bitmapImageRep];
            return [NSColor colorWithPatternImage:[patternImage autorelease]];
        }
        
        // fall through
    }
    
#ifdef DEBUG
    NSLog(@"Unable to unarchive color from container %@.  Falling back to white.", container);
#endif
    return [NSColor whiteColor];
}

+ (NSColor *)colorFromPropertyListRepresentation:(NSDictionary *)dict;
{
    return [self colorFromPropertyListRepresentation:dict withColorSpaceManager:nil shouldDefaultToGenericSpace:YES];
}

+ (NSColor *)colorFromPropertyListRepresentation:(NSDictionary *)dict withColorSpaceManager:(OAColorSpaceManager *)manager;
{
    return [self colorFromPropertyListRepresentation:dict withColorSpaceManager:manager shouldDefaultToGenericSpace:YES];
}

+ (NSColor *)colorFromPropertyListRepresentation:(NSDictionary *)dict withColorSpaceManager:(OAColorSpaceManager *)manager shouldDefaultToGenericSpace:(BOOL)shouldDefaultToGenericSpace;
{
    OAColorGetters getters = {
        .component = _dictionaryComponentGetter,
        .string = _dictionaryStringGetter,
        .data = _dictionaryDataGetter,
    };
    return [self _colorFromContainer:dict getters:getters withColorSpaceManager:manager shouldDefaultToGenericSpace:shouldDefaultToGenericSpace];
}

typedef struct {
    void (*component)(id container, NSString *key, double component);
    void (*string)(id container, NSString *key, NSString *string);
    void (*data)(id container, NSString *key, NSData *data);
} OAColorAdders;

static void _dictionaryStringComponentAdder(id container, NSString *key, double component)
{
    OBPRECONDITION([container isKindOfClass:[NSMutableDictionary class]]);
    NSString *str = [[NSString alloc] initWithFormat:@"%g", component];
    [container setObject:str forKey:key];
    [str release];
}

static void _dictionaryNumberComponentAdder(id container, NSString *key, double component)
{
    OBPRECONDITION([container isKindOfClass:[NSMutableDictionary class]]);
    NSNumber *num = [[NSNumber alloc] initWithDouble:component];
    [container setObject:num forKey:key];
    [num release];
}

static void _dictionaryStringAdder(id container, NSString *key, NSString *string)
{
    OBPRECONDITION([container isKindOfClass:[NSMutableDictionary class]]);
    [container setObject:string forKey:key];
}

static void _dictionaryDataAdder(id container, NSString *key, NSData *data)
{
    OBPRECONDITION([container isKindOfClass:[NSMutableDictionary class]]);
    [container setObject:data forKey:key];
}


// Allow for including default values, particular for scripting so that users don't have to check for missing values
- (void)_addComponentsToContainer:(id)container adders:(OAColorAdders)adders omittingDefaultValues:(BOOL)omittingDefaultValues withColorSpaceManager:(OAColorSpaceManager *)manager;
{
    BOOL hasAlpha = NO;
    
    NSColorType colorType = self.type;
    NSColorSpace *colorSpace = nil;
    BOOL archiveConvertedColor = NO;

    if (colorType == NSColorTypeComponentBased) {
        colorSpace = [self colorSpace]; // This will raise if it is a pattern or catalog
    }

    if (colorSpace) {
        // NOTE: we used to convert device colors to generic colors, but now that the user can explicitly pick color spaces in the color picker we preserve them
        BOOL archiveCustomSpace = NO;
        
        if (![OAColorSpaceManager isColorSpaceGeneric:colorSpace]) {
            NSString *name = (manager) ? [manager nameForColorSpace:colorSpace] : [OAColorSpaceManager nameForColorSpace:colorSpace];
            if (name)
                adders.string(container, @"space", name);
            else
                archiveCustomSpace = YES;
        }

        NSColorSpaceModel colorSpaceModel = [colorSpace colorSpaceModel];
        if (colorSpaceModel == NSColorSpaceModelGray) {
            adders.component(container, @"w", [self whiteComponent]);
            hasAlpha = YES;
        } else if (colorSpaceModel == NSColorSpaceModelRGB) {
            adders.component(container, @"r", [self redComponent]);
            adders.component(container, @"g", [self greenComponent]);
            adders.component(container, @"b", [self blueComponent]);
            hasAlpha = YES;
        } else if (colorSpaceModel == NSColorSpaceModelCMYK) {
            CGFloat components[5]; // Assuming that it'll write out alpha too.
            [self getComponents:components];
            
            adders.component(container, @"c", components[0]);
            adders.component(container, @"m", components[1]);
            adders.component(container, @"y", components[2]);
            adders.component(container, @"k", components[3]);
            hasAlpha = YES;
        } else {
            archiveCustomSpace = YES;
            archiveConvertedColor = YES;
            // The right way to do this is probably to ask the colorSpace for the numberOfComponents, the write them out as something like C0 = x, C1 = y, ...and then add reading of CN
            // For now we are just going to keep archiving the entire color
        }
        
        if (archiveCustomSpace) {
            __autoreleasing NSError *error;
            NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:&error];
            if (!archive) {
                [error log:@"Error archiving color"];
            } else {
                adders.data(container, @"archive", archive);
            }
        }
    } else if (colorType == NSColorTypeCatalog) {
        adders.string(container, @"catalog", [self catalogNameComponent]);
        adders.string(container, @"name", [self colorNameComponent]);
    } else if (colorType == NSColorTypePattern) {
        adders.data(container, @"tiff", [[self patternImage] TIFFRepresentation]);
    } else {
        // No colorspace, not a pattern or named color.
        archiveConvertedColor = YES;
    }
    
    if (archiveConvertedColor) {
        NSColor *rgbColor = [self colorUsingColorSpace:[NSColorSpace extendedSRGBColorSpace]];
        if (!rgbColor)
            rgbColor = [NSColor colorWithRed:1 green:1 blue:1 alpha:1];
        [rgbColor _addComponentsToContainer:container adders:adders omittingDefaultValues:omittingDefaultValues withColorSpaceManager:manager];
    }

    if (hasAlpha) {
        double alpha = [self alphaComponent];
        if (alpha != 1.0 || !omittingDefaultValues)
            adders.component(container, @"a", alpha);
    }
}

- (NSMutableDictionary *)propertyListRepresentationWithStringComponentsOmittingDefaultValues:(BOOL)omittingDefaultValues;
{
    OAColorAdders adders = {
        .component = _dictionaryStringComponentAdder,
        .string = _dictionaryStringAdder,
        .data = _dictionaryDataAdder
    };
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    [self _addComponentsToContainer:plist adders:adders omittingDefaultValues:omittingDefaultValues withColorSpaceManager:nil];
    return plist;
}

- (NSMutableDictionary *)propertyListRepresentationWithNumberComponentsOmittingDefaultValues:(BOOL)omittingDefaultValues;
{
    OAColorAdders adders = {
        .component = _dictionaryNumberComponentAdder,
        .string = _dictionaryStringAdder,
        .data = _dictionaryDataAdder
    };
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    [self _addComponentsToContainer:plist adders:adders omittingDefaultValues:omittingDefaultValues withColorSpaceManager:nil];
    return plist;
}

// For backwards compatibility (these property lists can be stored in files), we return string components.
- (NSMutableDictionary *)propertyListRepresentation;
{
    return [self propertyListRepresentationWithStringComponentsOmittingDefaultValues:YES];
}

- (NSMutableDictionary *)propertyListRepresentationWithColorSpaceManager:(OAColorSpaceManager *)manager;
{
    OAColorAdders adders = {
        .component = _dictionaryNumberComponentAdder,
        .string = _dictionaryStringAdder,
        .data = _dictionaryDataAdder
    };
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    [self _addComponentsToContainer:plist adders:adders omittingDefaultValues:YES withColorSpaceManager:manager];
    return plist;
}

//

- (BOOL)isSimilarToColor:(NSColor *)color;
{
    if (self == color)
        return YES;

    NSColor *selfAsComponentBased = [self colorUsingType:NSColorTypeComponentBased];
    NSColor *colorAsComponentBased = [color colorUsingType:NSColorTypeComponentBased];

    if (selfAsComponentBased.colorSpace != colorAsComponentBased.colorSpace) {
        // perhaps we can convert colorspaces between colors & have the same color, but only if both colors actually convert to colors that HAVE colorspaces.
        if (selfAsComponentBased != nil && colorAsComponentBased != nil) {
            colorAsComponentBased = [colorAsComponentBased colorUsingColorSpace:selfAsComponentBased.colorSpace];
            if (selfAsComponentBased.colorSpace != colorAsComponentBased.colorSpace) {
                return NO;
            }
        } else {
            return NO;
        }
    }

    if (selfAsComponentBased != nil && colorAsComponentBased != nil) {
        switch (selfAsComponentBased.colorSpace.colorSpaceModel) {
            case NSColorSpaceModelRGB:
                return (fabs([selfAsComponentBased redComponent]-[colorAsComponentBased redComponent]) < 0.001) && (fabs([selfAsComponentBased greenComponent]-[colorAsComponentBased greenComponent]) < 0.001) && (fabs([selfAsComponentBased blueComponent]-[colorAsComponentBased blueComponent]) < 0.001) && (fabs([selfAsComponentBased alphaComponent]-[colorAsComponentBased alphaComponent]) < 0.001);
            case NSColorSpaceModelGray:
                return (fabs([selfAsComponentBased whiteComponent]-[colorAsComponentBased whiteComponent]) < 0.001) && (fabs([selfAsComponentBased alphaComponent]-[colorAsComponentBased alphaComponent]) < 0.001);
            case NSColorSpaceModelCMYK:
                return (fabs([selfAsComponentBased cyanComponent]-[colorAsComponentBased cyanComponent]) < 0.001) && (fabs([selfAsComponentBased magentaComponent]-[colorAsComponentBased magentaComponent]) < 0.001) && (fabs([selfAsComponentBased yellowComponent]-[colorAsComponentBased yellowComponent]) < 0.001) && (fabs([selfAsComponentBased blackComponent]-[colorAsComponentBased blackComponent]) < 0.001) && (fabs([selfAsComponentBased alphaComponent]-[colorAsComponentBased alphaComponent]) < 0.001);
            default:
                return [color isEqual:self];
        }
    }

    if (self.type == NSColorTypePattern && color.type == NSColorTypePattern) {
        return [[[self patternImage] TIFFRepresentation] isEqualToData:[[color patternImage] TIFFRepresentation]];
    } else if (self.type == NSColorTypeCatalog && color.type == NSColorTypeCatalog) {
        return [[self catalogNameComponent] isEqualToString:[color catalogNameComponent]] && [[self colorNameComponent] isEqualToString:[color colorNameComponent]];
    }

    if ([color isEqual:self])  // works for CMYK colors, which have a NSCustomColorSpace
        return YES;
    
    return NO;
}

- (NSData *)patternImagePNGData;
{
    if (self.type != NSColorTypePattern) {
        return nil;
    }

    return [[self patternImage] pngData];
}

typedef struct {
    NSString *name; // easy name lookup
    CGFloat   h, s, v, a; // avoid conversions
    CGFloat   r, g, B;
    NSColor  *color; // in the original color space
} OANamedColorEntry;

static OANamedColorEntry *_addColorsFromList(OANamedColorEntry *colorEntries, NSUInteger *entryCount, NSColorList *colorList)
{
    if (colorList == nil)
	return colorEntries;

    // -allKeys lazily decodes the color list and can throw if the user has a corrupt color list.
    // See <bug:///120632> where one of the problems leading up to the crashes was an exception with this message, from two different users
    // Reason: *** -[NSKeyedUnarchiver initForReadingWithData:]: incomprehensible archive (0x31, 0x31, 0xa, 0x30, 0x20, 0x30, 0x2e, 0x30)

    NSArray *allColorKeys = nil;
    @try {
        allColorKeys = [colorList allKeys];
    } @catch(NSException *exc) {
        NSLog(@"Exception raised while trying to use color list: %@", exc);
        @try {
            NSLog(@"Color list located at %@", [colorList valueForKey:@"fileName"]);
        } @catch(NSException *){
            // Ignore ...
        }
    }

    NSUInteger colorIndex, colorCount = [allColorKeys count];
    
    // Make room for the extra entries
    colorEntries = (OANamedColorEntry *)realloc(colorEntries, sizeof(*colorEntries)*(*entryCount + colorCount));
    NSColorSpace *sRGBColorSpace = [NSColorSpace extendedSRGBColorSpace];
    for (colorIndex = 0; colorIndex < colorCount; colorIndex++) {
	NSString *colorKey = [allColorKeys objectAtIndex:colorIndex];
	NSColor *color = [colorList colorWithKey:colorKey];
	
	OANamedColorEntry *entry = &colorEntries[*entryCount + colorIndex];
        NSString *localizedColorName =  [OMNI_BUNDLE localizedStringForKey:colorKey value:nil table:@"OACrayonNames"];
	entry->name = [localizedColorName copy];
	
	NSColor *rgbColor = [color colorUsingColorSpace:sRGBColorSpace];
	[rgbColor getHue:&entry->h saturation:&entry->s brightness:&entry->v alpha:&entry->a];
	[rgbColor getRed:&entry->r green:&entry->g blue:&entry->B alpha:&entry->a];
	
	entry->color = [color retain];
    }
    
    // Inform caller of new entry count, finally
    *entryCount += colorCount;
    return colorEntries;
}

static const OANamedColorEntry *_combinedColorEntries(NSUInteger *outEntryCount)
{
    static OANamedColorEntry *entries = NULL;
    static NSUInteger entryCount = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
	// Two built-in color lists that should get localized
        entries = _addColorsFromList(entries, &entryCount, [NSColorList colorListNamed:@"Apple"]);
        entries = _addColorsFromList(entries, &entryCount, [NSColorList colorListNamed:@"Crayons"]);
	
	// Load *our* color list last since it should be localized and has more colors than either of the above
	entries = _addColorsFromList(entries, &entryCount, classicCrayonsColorList());
    });
    
    *outEntryCount = entryCount;
    return entries;
}

static CGFloat _nearnessWithWrap(CGFloat a, CGFloat b)
{
    CGFloat value1 = 1.0f - a + b;
    CGFloat value2 = 1.0f - b + a;
    CGFloat value3 = a - b;
    return MIN3(ABS(value1), ABS(value2), ABS(value3));
}

static CGFloat _colorCloseness(const OANamedColorEntry *e1, const OANamedColorEntry *e2)
{
    // As saturation goes to zero, hue becomes irrelevant.  For example, black has h=0, but that doesn't mean it is "like" red.  So, we do the distance in RGB space.  But the modifier words in HSV.
    CGFloat sdiff = ABS(e1->s - e2->s);
    if (sdiff < 0.1 && e1->s < 0.1) {
	CGFloat rd = e1->r - e2->r;
	CGFloat gd = e1->g - e2->g;
	CGFloat bd = e1->B - e2->B;
	
	return (CGFloat)sqrt(rd*rd + gd*gd + bd*bd);
    } else {
	// We weight the hue stronger than the saturation or brightness, since it's easier to talk about 'dark yellow' than it is 'yellow except for with a little red in it'
	return (CGFloat)(3.0 * _nearnessWithWrap(e1->h, e2->h) + sdiff + ABS(e1->v - e2->v));
    }
}
        
- (NSString *)similarColorNameFromColorLists;
{
    switch (self.type) {
        case NSColorTypeCatalog:
            return [self localizedColorNameComponent];
        case NSColorTypePattern:
            return NSLocalizedStringFromTableInBundle(@"Image", @"OmniAppKit", OMNI_BUNDLE, "generic color name for pattern colors");
        case NSColorTypeComponentBased:
            break;
    }

    NSColorSpace *sRGBColorSpace = [NSColorSpace extendedSRGBColorSpace];

    NSUInteger entryCount;
    const OANamedColorEntry *entries = _combinedColorEntries(&entryCount);
    
    if (entryCount == 0) {
	// Avoid crasher below if something goes wrong in building the entries
	OBASSERT_NOT_REACHED("No color entries found");
	return @"";
    }
    
    OANamedColorEntry colorEntry;
    memset(&colorEntry, 0, sizeof(colorEntry));
    NSColor *rgbColor = [self colorUsingColorSpace:sRGBColorSpace];
    [rgbColor getHue:&colorEntry.h saturation:&colorEntry.s brightness:&colorEntry.v alpha:&colorEntry.a];
    [rgbColor getRed:&colorEntry.r green:&colorEntry.g blue:&colorEntry.B alpha:&colorEntry.a];

    const OANamedColorEntry *closestEntry = &entries[0];
    CGFloat closestEntryDistance = CGFLOAT_MAX;

    // Entries at the end of the array have higher precedence; loop backwards
    NSUInteger entryIndex = entryCount;
    while (entryIndex--) {
	const OANamedColorEntry *entry = &entries[entryIndex];
	CGFloat distance = _colorCloseness(&colorEntry, entry);
	if (distance < closestEntryDistance) {
	    closestEntryDistance = distance;
	    closestEntry = entry;
	}
    }

    CGFloat brightnessDifference = colorEntry.v - closestEntry->v;
    NSString *brightnessString = nil;
    if (brightnessDifference < -.1 && colorEntry.v < .1)
        brightnessString =  NSLocalizedStringFromTableInBundle(@"Near-black", @"OmniAppKit", OMNI_BUNDLE, "word comparing color brightnesss");
    else if (brightnessDifference < -.2)
        brightnessString =  NSLocalizedStringFromTableInBundle(@"Dark", @"OmniAppKit", OMNI_BUNDLE, "word comparing color brightnesss");
    else if (brightnessDifference < -.1)
        brightnessString =  NSLocalizedStringFromTableInBundle(@"Smokey", @"OmniAppKit", OMNI_BUNDLE, "word comparing color brightnesss");
    else if (brightnessDifference > .1 && colorEntry.v > .9)
        brightnessString =  NSLocalizedStringFromTableInBundle(@"Off-white", @"OmniAppKit", OMNI_BUNDLE, "word comparing color brightnesss");
    else if (brightnessDifference > .2)
        brightnessString =  NSLocalizedStringFromTableInBundle(@"Bright", @"OmniAppKit", OMNI_BUNDLE, "word comparing color brightnesss");
    else if (brightnessDifference > .1)
        brightnessString =  NSLocalizedStringFromTableInBundle(@"Light", @"OmniAppKit", OMNI_BUNDLE, "word comparing color brightnesss");

    // Input saturation less than some value means that the saturation is irrelevant.
    NSString *saturationString = nil;
    if (colorEntry.s > 0.01) {
	CGFloat saturationDifference = colorEntry.s - closestEntry->s;
	if (saturationDifference < -0.3)
	    saturationString =  NSLocalizedStringFromTableInBundle(@"Washed-out", @"OmniAppKit", OMNI_BUNDLE, "word comparing color saturations");
	else if (saturationDifference < -.2)
	    saturationString =  NSLocalizedStringFromTableInBundle(@"Faded", @"OmniAppKit", OMNI_BUNDLE, "word comparing color saturations");
	else if (saturationDifference < -.1)
	    saturationString =  NSLocalizedStringFromTableInBundle(@"Mild", @"OmniAppKit", OMNI_BUNDLE, "word comparing color saturations");
	else if (saturationDifference > -0.01 && saturationDifference < 0.01)
	    saturationString = nil;
	else if (saturationDifference < .1)
	    saturationString = nil;
	else if (saturationDifference < .2)
	    saturationString =  NSLocalizedStringFromTableInBundle(@"Rich", @"OmniAppKit", OMNI_BUNDLE, "word comparing color saturations");
	else if (saturationDifference < .3)
	    saturationString =  NSLocalizedStringFromTableInBundle(@"Deep", @"OmniAppKit", OMNI_BUNDLE, "word comparing color saturations");
	else
	    saturationString =  NSLocalizedStringFromTableInBundle(@"Intense", @"OmniAppKit", OMNI_BUNDLE, "word comparing color saturations");
    }
    
    NSString *closestColorDescription = nil;
    if (saturationString != nil && brightnessString != nil)
        closestColorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@, %@ %@", @"OmniAppKit", OMNI_BUNDLE, "format string for color with saturation and brightness descriptions (brightness, saturation, color name)"), brightnessString, saturationString, closestEntry->name];
    else if (saturationString != nil)
        closestColorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ %@", @"OmniAppKit", OMNI_BUNDLE, "format string for color with saturation description (saturation, color name)"), saturationString, closestEntry->name];
    else if (brightnessString != nil)
        closestColorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ %@", @"OmniAppKit", OMNI_BUNDLE, "format string for color with brightness description (brightness, color name)"), brightnessString, closestEntry->name];
    else
        closestColorDescription = closestEntry->name;

    if (colorEntry.a <= 0.001)
        return NSLocalizedStringFromTableInBundle(@"Clear", @"OmniAppKit", OMNI_BUNDLE, "name of completely transparent color");
    else if (colorEntry.a < .999)
        return [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%d%% %@", @"OmniAppKit", OMNI_BUNDLE, "alpha with color description"), (int)(colorEntry.a * 100), closestColorDescription];
    else
        return closestColorDescription;
}

+ (NSColor *)_adjustColor:(NSColor *)aColor withAdjective:(NSString *)adjective;
{
    NSColorSpace *sRGBColorSpace = [NSColorSpace extendedSRGBColorSpace];
    CGFloat hue, saturation, brightness, alpha;
    [[aColor colorUsingColorSpace:sRGBColorSpace] getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

    if ([adjective isEqualToString:@"Near-black"]) {
        brightness = MIN(brightness, 0.05f);
    } else if ([adjective isEqualToString:@"Dark"]) {
        brightness = MAX(0.0f, brightness - 0.25f);
    } else if ([adjective isEqualToString:@"Smokey"]) {
        brightness = MAX(0.0f, brightness - 0.15f);
    } else if ([adjective isEqualToString:@"Off-white"]) {
        brightness = MAX(brightness, 0.95f);
    } else if ([adjective isEqualToString:@"Bright"]) {
        brightness = MIN(1.0f, brightness + 0.25f);
    } else if ([adjective isEqualToString:@"Light"]) {
        brightness = MIN(1.0f, brightness + 0.15f);
    } else if ([adjective isEqualToString:@"Washed-out"]) {
        saturation = MAX(0.0f, saturation - 0.35f);
    } else if ([adjective isEqualToString:@"Faded"]) {
        saturation = MAX(0.0f, saturation - 0.25f);
    } else if ([adjective isEqualToString:@"Mild"]) {
        saturation = MAX(0.0f, saturation - 0.15f);
    } else if ([adjective isEqualToString:@"Rich"]) {
        saturation = MIN(1.0f, saturation + 0.15f);
    } else if ([adjective isEqualToString:@"Deep"]) {
        saturation = MIN(1.0f, saturation + 0.25f);
    } else if ([adjective isEqualToString:@"Intense"]) {
        saturation = MIN(1.0f, saturation + 0.35f);
    }

    return [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

+ (NSColor *)colorWithSimilarName:(NSString *)aName;
{
    // special case clear
    if ([aName isEqualToString:@"Clear"] || [aName isEqualToString:NSLocalizedStringFromTableInBundle(@"Clear", @"OmniAppKit", OMNI_BUNDLE, "name of completely transparent color")])
        return [NSColor clearColor];
    
    NSUInteger entryCount;
    const OANamedColorEntry *entries = _combinedColorEntries(&entryCount);
    
    if (entryCount == 0) {
	// Avoid crasher below if something goes wrong in building the entries
	OBASSERT_NOT_REACHED("No color entries found");
	return nil;
    }

    // Entries at the end of the array have higher precedence; loop backwards
    NSUInteger entryIndex = entryCount;

    NSColor *baseColor = nil;
    NSUInteger longestMatch = 0;
    
    // find base color
    while (entryIndex--) {
	const OANamedColorEntry *entry = &entries[entryIndex];
        NSString *colorKey = entry->name;
        NSUInteger length;
        
        if ([aName hasSuffix:colorKey] && (length = [colorKey length]) > longestMatch) {
            baseColor = entry->color;
            longestMatch = length;
        }
    }
    if (baseColor == nil)
        return nil;
    if ([aName length] == longestMatch)
        return baseColor;
    aName = [aName substringToIndex:([aName length] - longestMatch) - 1];
    
    // get alpha percentage
    NSRange percentRange = [aName rangeOfString:@"%"];
    if (percentRange.length == 1) {
        baseColor = [baseColor colorWithAlphaComponent:([aName cgFloatValue] / 100.0f)];
        if (NSMaxRange(percentRange) + 1 >= [aName length])
            return baseColor;
        aName = [aName substringFromIndex:NSMaxRange(percentRange) + 1];
    }
    
    // adjust by adjectives
    NSRange commaRange = [aName rangeOfString:@", "];
    if (commaRange.length == 2) {
        baseColor = [self _adjustColor:baseColor withAdjective:[aName substringToIndex:commaRange.location]];
        aName = [aName substringFromIndex:NSMaxRange(commaRange)];
    }
    return [self _adjustColor:baseColor withAdjective:aName];
}

static CGColorRef _CreateCGColorRefWithComponentsOfColor(NSColor *color, CGColorSpaceRef destinationColorSpace)
{
    size_t componentCount = CGColorSpaceGetNumberOfComponents(destinationColorSpace);
    OBASSERT(componentCount > 0);
    
    CGFloat *components = malloc((componentCount + 1) * sizeof(CGFloat));
    [color getComponents:components];
    
    CGColorRef result = CGColorCreate(destinationColorSpace, components);
    free(components);
    
    OBPOSTCONDITION(result);
    return result;
}

- (CGColorRef)newCGColor;
{
    CGColorSpaceRef destinationColorSpace = self.colorSpace.CGColorSpace;
    if (destinationColorSpace)
        return _CreateCGColorRefWithComponentsOfColor(self, destinationColorSpace);
    else
        return nil;
}

- (CGColorRef)newCGColorWithCGColorSpace:(CGColorSpaceRef)destinationColorSpace;
{
    OBPRECONDITION(destinationColorSpace);

    CGColorRef cgColor = self.CGColor;
    if (destinationColorSpace == CGColorGetColorSpace(cgColor)) {
        return CGColorRetain(cgColor);
    }

    NSColorSpace *wrappedColorSpace = [[[NSColorSpace alloc] initWithCGColorSpace:destinationColorSpace] autorelease];
    NSColor *convertedColor = [self colorUsingColorSpace:wrappedColorSpace];
    if (convertedColor)
        return _CreateCGColorRefWithComponentsOfColor(convertedColor, destinationColorSpace);
    else
        return nil;
}

+ (NSColor *)colorFromCGColor:(CGColorRef)colorRef;
{
    NSColorSpace *colorSpace = [[NSColorSpace alloc] initWithCGColorSpace:CGColorGetColorSpace(colorRef)];
    const CGFloat *components = CGColorGetComponents(colorRef);
    
    NSColor *result = [NSColor colorWithColorSpace:colorSpace components:components count:[colorSpace numberOfColorComponents] + 1];
    
    [colorSpace release];
    
    OBPOSTCONDITION(result);
    return result;
}

#pragma mark -
#pragma mark XML Archiving

static NSString *XMLElementName = @"color";

+ (NSString *)xmlElementName;
{
    return XMLElementName;
}

static void _xmlComponentAdder(id container, NSString *key, double component)
{
    OBPRECONDITION([container isKindOfClass:[OFXMLDocument class]]);
    [container setAttribute:key real:(float)component];
}

static void _xmlStringAdder(id container, NSString *key, NSString *string)
{
    OBPRECONDITION([container isKindOfClass:[OFXMLDocument class]]);
    [container setAttribute:key string:string];
}

static void _xmlDataAdder(id container, NSString *key, NSData *data)
{
    OBPRECONDITION([container isKindOfClass:[OFXMLDocument class]]);
    [container setAttribute:key string:[data base64EncodedStringWithOptions:0]];
}


- (void) appendXML:(OFXMLDocument *)doc;
{
    [doc pushElement: XMLElementName];
    {
        OAColorAdders adders = {
            .component = _xmlComponentAdder,
            .string = _xmlStringAdder,
            .data = _xmlDataAdder
        };

        // Allow convertion to a color space for the external file format. In particular, some consumers might not be able to handle catalog/named colors and might want a sRGB tuple instead.
        NSColor *externalColor;
        NSValueTransformer *colorTransformer = [doc userObjectForKey:OAColorExternalRepresentationTransformerUserKey];
        if (colorTransformer) {
            externalColor = [colorTransformer transformedValue:self];
            if (externalColor == nil) {
                externalColor = self;
            }
        } else {
            externalColor = self;
        }

        [externalColor _addComponentsToContainer:doc adders:adders omittingDefaultValues:YES withColorSpaceManager:nil];
    }
    [doc popElement];
}

static BOOL _xmlCursorComponentGetter(void *container, NSString *key, CGFloat *outComponent)
{
    NSString *attribute = [(OFXMLCursor *)container attributeNamed:key];
    if (!attribute)
        return NO;
    *outComponent = [attribute cgFloatValue];
    return YES;
}

static NSString *_xmlCursorStringGetter(void *container, NSString *key)
{
    return [(OFXMLCursor *)container attributeNamed:key];
}

static NSData *_xmlCursorDataGetter(void *container, NSString *key)
{
    NSString *string = [(OFXMLCursor *)container attributeNamed:key];
    if (!string)
        return nil;
    return [[[NSData alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters] autorelease];
}

+ (NSColor *)colorFromXML:(OFXMLCursor *)cursor;
{
    OBPRECONDITION([[cursor name] isEqualToString: XMLElementName]);

    OAColorGetters getters = {
        .component = _xmlCursorComponentGetter,
        .string = _xmlCursorStringGetter,
        .data = _xmlCursorDataGetter
    };
    return [NSColor _colorFromContainer:cursor getters:getters withColorSpaceManager:nil shouldDefaultToGenericSpace:YES];
}

@end


// Value transformers

NSString * const OAColorToPropertyListTransformerName = @"OAColorToPropertyList";

@interface OAColorToPropertyList : NSValueTransformer
@end

@implementation OAColorToPropertyList

OBDidLoad(^{
    OAColorToPropertyList *instance = [[OAColorToPropertyList alloc] init];
    [NSValueTransformer setValueTransformer:instance forName:OAColorToPropertyListTransformerName];
    [instance release];
});

+ (Class)transformedValueClass;
{
    return [NSDictionary class];
}

+ (BOOL)allowsReverseTransformation;
{
    return YES;
}

- (id)transformedValue:(id)value;
{
    if ([value isKindOfClass:[NSColor class]])
	return [(NSColor *)value propertyListRepresentation];
    return nil;
}

- (id)reverseTransformedValue:(id)value;
{
    if ([value isKindOfClass:[NSDictionary class]])
	return [NSColor colorFromPropertyListRepresentation:value];
    return nil;
}

@end

// Converts a BOOL to either +controlTextColor or +disabledControlTextColor
NSString * const OABooleanToControlColorTransformerName = @"OABooleanToControlColor";
NSString * const OANegateBooleanToControlColorTransformerName = @"OANegateBooleanToControlColor";

@interface OABooleanToControlColor : NSValueTransformer
{
    BOOL _negate;
}
@end

@implementation OABooleanToControlColor

OBDidLoad(^{
    OABooleanToControlColor *normal = [[OABooleanToControlColor alloc] init];
    [NSValueTransformer setValueTransformer:normal forName:OABooleanToControlColorTransformerName];
    [normal release];
    
    OABooleanToControlColor *negate = [[OABooleanToControlColor alloc] init];
    negate->_negate = YES;
    [NSValueTransformer setValueTransformer:negate forName:OANegateBooleanToControlColorTransformerName];
    [negate release];
});

+ (Class)transformedValueClass;
{
    return [NSColor class];
}

- (id)transformedValue:(id)value;
{
    if ([value isKindOfClass:[NSNumber class]]) {
        if ([value boolValue] ^ _negate)
            return [NSColor controlTextColor];
        return [NSColor disabledControlTextColor];
    }
    
    OBASSERT_NOT_REACHED("Invalid value for transformer");
    return [NSColor controlTextColor];
}

@end

