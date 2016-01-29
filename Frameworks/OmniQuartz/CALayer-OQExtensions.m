// Copyright 2008-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniQuartz/CALayer-OQExtensions.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniFoundation/NSFileManager-OFExtensions.h>
#endif

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>

#import "OQDrawing.h"

RCS_ID("$Id$");

#if 0 && defined(DEBUG)
#define LOG_CONTENT_FILLING
#endif

#if 0 && defined(DEBUG)
    #define LOG_DRAW_IN_CONTEXT_TIME
#endif
#if 0 && defined(DEBUG)
    #define LOG_RENDER_IN_CONTEXT_TIME
#endif

#if 0 && defined(DEBUG)
#define WARN_OF_MIXING_ANIMATED_AND_IMMEDIATE_DISPLAY
#endif

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    #define NSStringFromPoint NSStringFromCGPoint
    #define NSStringFromSize NSStringFromCGSize
    #define NSStringFromRect NSStringFromCGRect
    #import <UIKit/UIGeometry.h>
#endif

@implementation CALayer (OQExtensions)

#if defined(OMNI_ASSERTIONS_ON)

// Conversions only work w/in the same tree, but CALayer will just bail.
#define DEFINE_CONVERT_CHECK(name, type, dir) \
static type (*original_convert ## name ## dir ## Layer)(CALayer *self, SEL _cmd, type p, CALayer *otherLayer) = NULL; \
static type replacement_convert ## name ## dir ## Layer(CALayer *self, SEL _cmd, type p, CALayer *otherLayer) \
{ \
    OBASSERT_IF(otherLayer != nil, [self rootLayer] == [otherLayer rootLayer]); \
    return original_convert ## name ## dir ## Layer(self, _cmd, p, otherLayer); \
} \

DEFINE_CONVERT_CHECK(Point, CGPoint, from);
DEFINE_CONVERT_CHECK(Point, CGPoint, to);
DEFINE_CONVERT_CHECK(Rect, CGRect, from);
DEFINE_CONVERT_CHECK(Rect, CGRect, to);
DEFINE_CONVERT_CHECK(Time, CFTimeInterval, from);
DEFINE_CONVERT_CHECK(Time, CFTimeInterval, to);

#define INSTALL_CONVERT_CHECK(name, dir) \
original_convert ## name ## dir ## Layer = (typeof(original_convert ## name ## dir ## Layer))OBReplaceMethodImplementation(self, @selector(convert##name:dir##Layer:), (IMP)replacement_convert ## name ## dir ## Layer)


#endif
#if defined(WARN_OF_MIXING_ANIMATED_AND_IMMEDIATE_DISPLAY)
static void (*original_setNeedsDisplay)(CALayer *self, SEL _cmd) = NULL;
static void replacement_setNeedsDisplay(CALayer *self, SEL _cmd)
{
    // If animation is disabled, doing a delayed display can cause some delayed animations to happen mixed with some immediate animations
    OBPRECONDITION([[CATransaction valueForKey:kCATransactionDisableActions] boolValue] == NO);
    original_setNeedsDisplay(self, _cmd);
}
static void (*original_setNeedsDisplayInRect)(CALayer *self, SEL _cmd, CGRect r) = NULL;
static void replacement_setNeedsDisplayInRect(CALayer *self, SEL _cmd, CGRect frame)
{
    // If animation is disabled, doing a delayed display can cause some delayed animations to happen mixed with some immediate animations
    OBPRECONDITION([[CATransaction valueForKey:kCATransactionDisableActions] boolValue] == NO);
    original_setNeedsDisplayInRect(self, _cmd, frame);
}
#endif

#if defined(OQ_ANIMATION_LOGGING_ENABLED)

static NSString * const OQAnimationLoggingEnabled = @"OQAnimationLoggingEnabled";

// We never remove the key, but always set a boolean. This could allow you to turn this on for a parent layer, but off for individual subtrees
void OQSetAnimationLoggingEnabledForLayer(CALayer *layer, BOOL enabled)
{
    // Not that an animation would ever be set up for this key, but let's just avoid even asking.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [layer setValue:enabled ? (id)kCFBooleanTrue : (id)kCFBooleanFalse forKey:OQAnimationLoggingEnabled];
    [CATransaction commit];
}

// Right now this doesn't consider the key, but we could make the annotation specify a dictionary of key->BOOL with a default value (so you can enable animations by default but turn off some keys). Haven't needed this yet.
static BOOL OQIsAnimationLoggingEnabledForLayer(CALayer *layer, NSString *key)
{
#ifdef OQ_LOG_ALL_ANIMATIONS
    return YES;
#else
    while (layer) {
        NSNumber *enabled = [layer valueForKey:OQAnimationLoggingEnabled];
        if (enabled)
            return [enabled boolValue];
        layer = layer.superlayer;
    }
    return NO;
#endif
}

static void logAnimation(CALayer *self, CAAnimation *animation, NSString *key)
{
    NSLog(@"%@=%@ delegate:%@ addAnimation:%@ forKey:%@", self.name, [self shortDescription], [self.delegate shortDescription], animation, key);
    
    CAMediaTimingFunction *function = animation.timingFunction;
    if (function) {
        NSString *desc = @"";
        
        if (function == [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear])
            desc = @"linear";
        else if (function == [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn])
            desc = @"ease-in";
        else if (function == [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut])
            desc = @"ease-out";
        else if (function == [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut])
            desc = @"ease-both";
        
        NSMutableString *timing = [NSMutableString stringWithString:desc];
        
        for (unsigned int i = 0; i < 4; i++) {
            float pt[2];
            [function getControlPointAtIndex:i values:pt];
            if ([timing length] != 0)
                [timing appendString:@", "];
            [timing appendFormat:@"(%g,%g)", pt[0], pt[1]];
            desc = timing;
        }
        NSLog(@"  timing:%@ %@", function, desc);
    }
    
    NSLog(@"  beginTime:%g duration:%g speed:%g timeOffset:%g repeatCount:%g repeatDuration:%g autoreverses:%d fillMode:%@", animation.beginTime, animation.duration, animation.speed, animation.timeOffset, animation.repeatCount, animation.repeatDuration, animation.autoreverses, animation.fillMode);
    NSLog(@"  removedOnCompletion:%d", animation.removedOnCompletion);
    
    if ([animation isKindOfClass:[CAPropertyAnimation class]]) {
        CAPropertyAnimation *prop = (CAPropertyAnimation *)animation;
        NSLog(@"  keyPath:%@ additive:%d cumulative:%d valueFunction:%@", prop.keyPath, prop.additive, prop.cumulative, prop.valueFunction);
    }
    if ([animation isKindOfClass:[CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *)animation;
        NSLog(@"  from:%@ to:%@ by:%@", basic.fromValue, basic.toValue, basic.byValue);
    }
    if ([animation isKindOfClass:[CATransition class]]) {
        CATransition *trans = (CATransition *)animation;
        NSLog(@"  type:%@ subtype:%@ start:%g end:%g filter:%@", trans.type, trans.subtype, trans.startProgress, trans.endProgress, trans.filter);
    }
}
static void (*original_addAnimation)(CALayer *self, SEL _cmd, CAAnimation *animation, NSString *key) = NULL;
static void replacement_addAnimation(CALayer *self, SEL _cmd, CAAnimation *animation, NSString *key)
{
    if (OQIsAnimationLoggingEnabledForLayer(self, key))
        logAnimation(self, animation, key);
    original_addAnimation(self, _cmd, animation, key);
}
#endif

#if defined(LOG_CONTENT_FILLING)
static void (*original_drawInContext)(CALayer *self, SEL _cmd, CGContextRef ctx) = NULL;
static void replacement_drawInContext(CALayer *self, SEL _cmd, CGContextRef ctx)
{
    NSLog(@"%@=%@ drawInContext:%p delegate:%@", self.name, [self shortDescription], ctx, [[self delegate] shortDescription]);
    original_drawInContext(self, _cmd, ctx);
}
#endif

#if defined(LOG_RENDER_IN_CONTEXT_TIME)
static void (*original_renderInContext)(CALayer *self, SEL _cmd, CGContextRef ctx) = NULL;
static void replacement_renderInContext(CALayer *self, SEL _cmd, CGContextRef ctx)
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    original_renderInContext(self, _cmd, ctx);
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();

    NSLog(@"%@=%@ renderInContext:%p delegate:%@ %f", self.name, [self shortDescription], ctx, [[self delegate] shortDescription], end - start);
}
#endif

#if defined(LOG_DRAW_IN_CONTEXT_TIME)
static void (*original_drawInContext)(CALayer *self, SEL _cmd, CGContextRef ctx) = NULL;
static void replacement_drawInContext(CALayer *self, SEL _cmd, CGContextRef ctx)
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    original_drawInContext(self, _cmd, ctx);
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    
    NSLog(@"%@=%@ drawInContext:%p delegate:%@ %f", self.name, [self shortDescription], ctx, [[self delegate] shortDescription], end - start);
}
#endif

// No OBPostLoader on our iPhone OS builds, so splitting this out.
static void OQEnableAnimationLogging(void) __attribute__((constructor));
static void OQEnableAnimationLogging(void)
{
#if defined(OQ_ANIMATION_LOGGING_ENABLED)
    if (original_addAnimation)
        return;
    original_addAnimation = (typeof(original_addAnimation))OBReplaceMethodImplementation([CALayer class], @selector(addAnimation:forKey:), (IMP)replacement_addAnimation);
#endif
}

static void OQEnableRenderInContextLogging(void) __attribute__((constructor));
static void OQEnableRenderInContextLogging(void)
{
#if defined(LOG_RENDER_IN_CONTEXT_TIME)
    if (original_renderInContext)
        return;
    original_renderInContext = (typeof(original_renderInContext))OBReplaceMethodImplementation([CALayer class], @selector(renderInContext:), (IMP)replacement_renderInContext);
#endif
}

static void OQEnableDrawInContextLogging(void) __attribute__((constructor));
static void OQEnableDrawInContextLogging(void)
{
#if defined(LOG_DRAW_IN_CONTEXT_TIME)
    if (original_drawInContext)
        return;
    original_drawInContext = (typeof(original_drawInContext))OBReplaceMethodImplementation([CALayer class], @selector(drawInContext:), (IMP)replacement_drawInContext);
#endif
}

#if defined(OQ_ANIMATION_LOGGING_ENABLED) || defined(LOG_CONTENT_FILLING) || defined(LOG_DRAW_IN_CONTEXT_TIME) || defined(LOG_RENDER_IN_CONTEXT_TIME) || defined(OMNI_ASSERTIONS_ON)
+ (void)performPosing;
{
#if defined(OMNI_ASSERTIONS_ON)
    INSTALL_CONVERT_CHECK(Point, from);
    INSTALL_CONVERT_CHECK(Point, to);
    INSTALL_CONVERT_CHECK(Rect, from);
    INSTALL_CONVERT_CHECK(Rect, to);
    INSTALL_CONVERT_CHECK(Time, from);
    INSTALL_CONVERT_CHECK(Time, to);
#endif
#if defined(WARN_OF_MIXING_ANIMATED_AND_IMMEDIATE_DISPLAY)
    original_setNeedsDisplay = (typeof(original_setNeedsDisplay))OBReplaceMethodImplementation(self, @selector(setNeedsDisplay), (IMP)replacement_setNeedsDisplay);
    original_setNeedsDisplayInRect = (typeof(original_setNeedsDisplayInRect))OBReplaceMethodImplementation(self, @selector(setNeedsDisplayInRect:), (IMP)replacement_setNeedsDisplayInRect);
#endif
#if defined(OQ_ANIMATION_LOGGING_ENABLED)
    OQEnableAnimationLogging();
#endif
#if defined(LOG_CONTENT_FILLING)
    original_drawInContext = (typeof(original_drawInContext))OBReplaceMethodImplementation(self, @selector(drawInContext:), (IMP)replacement_drawInContext);
#endif
#if defined(LOG_DRAW_IN_CONTEXT_TIME)
    OQEnableDrawInContextLogging();
#endif
#if defined(LOG_RENDER_IN_CONTEXT_TIME)
    OQEnableRenderInContextLogging();
#endif
}
#endif

- (CALayer *)rootLayer;
{
    CALayer *parent = self, *layer;
    do {
        layer = parent;
        parent = parent.superlayer;
    } while (parent);
    return layer;
}

- (BOOL)isSublayerOfLayer:(CALayer *)layer;
{
    CALayer *ancestor = self.superlayer;
    while (ancestor) {
        if (ancestor == layer)
            return YES;
        ancestor = ancestor.superlayer;
    }
    return NO;
}

- (id)sublayerNamed:(NSString *)name;
{
    for (CALayer *sublayer in self.sublayers)
        if ([sublayer.name isEqualToString:name])
            return sublayer;
    return nil;
}

- (NSArray *)sublayersNamed:(NSString *)name;
{
    NSMutableArray *layers = [NSMutableArray array];
    for (CALayer *sublayer in self.sublayers)
        if ([sublayer.name isEqualToString:name])
            [layers addObject:sublayer];
    return layers;
}

#if 0
- (void)hideLayersBasedOnPotentiallyVisibleRect:(CGRect)potentiallyVisibleRect;
{
    CGRect bounds = self.bounds;
    
    BOOL shouldBeHidden;
    if (CGRectEqualToRect(bounds, CGRectZero))
        shouldBeHidden = NO; // We assume that this is just a positioning layer.  Could check whether it masks, but it would be pointless if it did.
    else
        shouldBeHidden = self.masksToBounds && !CGRectIntersectsRect(potentiallyVisibleRect, self.bounds);
    
    //    if (self.hidden ^ shouldBeHidden) {
    //        NSLog(@"%@=%@ %@ hidden = %d (vis:%@ b:%@)", self.name, [self shortDescription], [self.delegate shortDescription], shouldBeHidden, NSStringFromRect(potentiallyVisibleRect), NSStringFromRect(self.bounds));
    //    }
    self.hidden = shouldBeHidden;
    //    NSLog(@"%@=%@ %@ hidden = %d (vis:%@ b:%@)", self.name, [self shortDescription], [self.delegate shortDescription], shouldBeHidden, NSStringFromRect(potentiallyVisibleRect), NSStringFromRect(self.bounds));
    
    if (shouldBeHidden)
        return;
    
    for (CALayer *layer in self.sublayers) {
        CGRect childRect = [self convertRect:potentiallyVisibleRect toLayer:layer];
        //        NSLog(@"  pot:%@ -> %@", NSStringFromRect(potentiallyVisibleRect), NSStringFromRect(childRect));
        [layer hideLayersBasedOnPotentiallyVisibleRect:childRect];
    }
}
#endif

- (NSUInteger)countLayers;
{
    NSUInteger count = 1; // self;
    for (CALayer *sublayer in self.sublayers)
        count += [sublayer countLayers];
    return count;
}

- (NSUInteger)countVisibleLayers;
{
    if (self.hidden)
        return 0;
    
    NSUInteger count = 1; // self;
    for (CALayer *sublayer in self.sublayers)
        count += [sublayer countVisibleLayers];
    return count;
}

static void _writeString(NSString *str)
{
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    fwrite([data bytes], [data length], 1, stderr);
    fputc('\n', stderr);
}

- (void)logGeometry;
{
    NSMutableString *str = [NSMutableString string];
    [self appendGeometry:str depth:0];
    _writeString(str);
}

- (void)logLocalGeometry;
{
    NSMutableString *str = [NSMutableString string];
    [self appendLocalGeometry:str];
    _writeString(str);
}

- (void)logAncestorGeometry;
{
    NSMutableString *str = [NSMutableString string];
    CALayer *layer = self;
    while (layer) {
        [layer appendLocalGeometry:str];
        [str appendString:@"\n"];
        layer = layer.superlayer;
    }
    _writeString(str);
}

- (void)appendGeometry:(NSMutableString *)str depth:(unsigned)depth;
{
    unsigned i;
    for (i = 0; i < depth; i++)
        [str appendString:@"  "];
    
    [self appendLocalGeometry:str];
    
    NSArray *sublayers = self.sublayers;
    if ([sublayers count] > 0) {
        [str appendString:@" {\n"];
        for (CALayer *l in sublayers)
            [l appendGeometry:str depth:depth+1];
        for (i = 0; i < depth; i++)
            [str appendString:@"  "];
        [str appendString:@"}\n"];
    } else {
        [str appendString:@"\n"];
        
    }
}

- (void)appendLocalGeometry:(NSMutableString *)str;
{    
    NSString *name = self.name;
    if ([name length] > 0)
        [str appendFormat:@"%@=", name];
    
    [str appendFormat:@"<%@:%p>", NSStringFromClass([self class]), self];
    id delegate = self.delegate;
    if (delegate) {
        [str appendFormat:@" %@", [delegate shortDescription]];
        
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
        if ([delegate isKindOfClass:[NSView class]]) {
            NSView *view = delegate;
            [str appendFormat:@" redraw:%ld", view.layerContentsRedrawPolicy];
            [str appendFormat:@" placement:%ld", view.layerContentsPlacement];
        }
#endif
    }
    
    [str appendFormat:@" b:%@", NSStringFromRect(self.bounds)];
    
    CGPoint p = self.anchorPoint;
    if (!CGPointEqualToPoint(p, CGPointZero))
        [str appendFormat:@" anchor:%@", NSStringFromPoint(p)];
    
    p = self.position;
    if (!CGPointEqualToPoint(p, CGPointZero))
        [str appendFormat:@" position:%@", NSStringFromPoint(p)];
    
    if (self.zPosition != 0.0)
        [str appendFormat:@" z:%g", self.zPosition];
    
    if (self.hidden)
        [str appendString:@" HIDDEN"];
    if (!self.isDoubleSided)
        [str appendString:@" SINGLE-SIDED"];
    if (self.masksToBounds)
        [str appendString:@" masks"];
    
    CALayer *mask = self.mask;
    if (mask)
        [str appendFormat:@" mask:%@", [mask shortDescription]];
    
    if (self.geometryFlipped)
        [str appendString:@" FLIPPED"];
    
    id contents = self.contents;
    if (contents) {
        [str appendFormat:@" contents:%@", contents];
        [str appendFormat:@" grav:%@", self.contentsGravity];
    }
    
    NSString *filter;
    if (![(filter = self.minificationFilter) isEqualToString:kCAFilterLinear])
        [str appendFormat:@" min-filter:%@", filter];
    if (![(filter = self.magnificationFilter) isEqualToString:kCAFilterLinear])
        [str appendFormat:@" mag-filter:%@", filter];
    
    if (self.opaque)
        [str appendString:@" opaque"];
    if (self.needsDisplayOnBoundsChange)
        [str appendFormat:@" needsDisplayOnBoundsChange"];
    if (self.edgeAntialiasingMask != 0)
        [str appendFormat:@" edge:%d", self.edgeAntialiasingMask];
    
    CGColorRef bg = self.backgroundColor;
    if (bg)
        [str appendFormat:@" bg:%@", [(id)CFCopyDescription(bg) autorelease]];
    
    if (self.cornerRadius != 0)
        [str appendFormat:@" corner:%g", self.cornerRadius];
    if (self.borderWidth != 0) {
        [str appendFormat:@" borderWidth:%g", self.borderWidth];
        if (self.borderColor != 0)
            [str appendFormat:@" borderColor:%@", [(id)CFCopyDescription(self.borderColor) autorelease]];
    }
    if (self.opacity != 1)
        [str appendFormat:@" opacity:%g", self.opacity];
    
    if (self.compositingFilter)
        [str appendFormat:@" compositingFilter:%@", self.compositingFilter];
    if ([self.filters count] > 0)
        [str appendFormat:@" filters:%@", self.filters];
    if ([self.backgroundFilters count] > 0)
        [str appendFormat:@" backgroundFilters:%@", self.backgroundFilters];
    
    if (self.shadowOpacity != 0) {
        [str appendFormat:@" shadowOpacity:%g", self.shadowOpacity];
        if (self.shadowColor)
            [str appendFormat:@" shadowColor:%@", [(id)CFCopyDescription(self.shadowColor) autorelease]];
        if (!CGSizeEqualToSize(self.shadowOffset, CGSizeMake(0,-3)))
            [str appendFormat:@" shadowOffset:%@", NSStringFromSize(self.shadowOffset)];
        if (self.shadowRadius != 3)
            [str appendFormat:@" shadowRadius:%g", self.shadowRadius];
    }
    
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    if (self.autoresizingMask != 0)
        [str appendFormat:@" autoresizingMask:%d", self.autoresizingMask];
    
    if (self.layoutManager)
        [str appendFormat:@" layout:%@", [self.layoutManager shortDescription]];
#endif
    
    CATransform3D transform = self.transform;
    if (!CATransform3DIsIdentity(transform)) {
        [str appendFormat:@" xform:[%g %g %g %g; %g %g %g %g; %g %g %g %g; %g %g %g %g]",
         transform.m11, transform.m12, transform.m13, transform.m14,
         transform.m21, transform.m22, transform.m23, transform.m24,
         transform.m31, transform.m32, transform.m33, transform.m34,
         transform.m41, transform.m42, transform.m43, transform.m44];
    }
    
    transform = self.sublayerTransform;
    if (!CATransform3DIsIdentity(transform)) {
        [str appendFormat:@" sublayer:[%g %g %g %g; %g %g %g %g; %g %g %g %g; %g %g %g %g]",
         transform.m11, transform.m12, transform.m13, transform.m14,
         transform.m21, transform.m22, transform.m23, transform.m24,
         transform.m31, transform.m32, transform.m33, transform.m34,
         transform.m41, transform.m42, transform.m43, transform.m44];
    }
}

- (BOOL)ancestorHasAnimationForKey:(NSString *)key;
{
    // Start at our parent, not self!
    CALayer *layer = self.superlayer;
    while (layer) {
        if ([layer animationForKey:key])
            return YES;
        layer = layer.superlayer;
    }
    return NO;
}

- (void)recursivelyRemoveAnimationForKey:(NSString *)key;
{
    [self removeAnimationForKey:key];
    [self.sublayers makeObjectsPerformSelector:_cmd withObject:key];
}

- (void)recursivelyRemoveAllAnimations;
{
    [self removeAllAnimations];
    [self.sublayers makeObjectsPerformSelector:_cmd];
}

- (void)sortSublayersByZOrder;
{
    NSArray *sortedSublayers = [[self sublayers] sortedArrayUsingComparator:^(id layer1, id layer2) {
        if ([layer1 zPosition] > [layer2 zPosition]) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if ([layer1 zPosition] < [layer2 zPosition]) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    for (CALayer *layer in sortedSublayers)
        [self addSublayer:layer];
}

- (BOOL)isModelLayer;
{
    return self == self.modelLayer;
}

- (BOOL)drawInVectorContext:(CGContextRef)ctx;
{
    return NO;
}

- (void)renderInContextIgnoringCache:(CGContextRef)ctx;
{
    [self renderInContextIgnoringCache:ctx useAnimatedValues:YES];
}

#if 0 && defined(DEBUG)
#define DEBUG_RENDER(format, ...) NSLog((format), ## __VA_ARGS__)
#define DEBUG_RENDER_ON 1
#else
#define DEBUG_RENDER(format, ...)
#define DEBUG_RENDER_ON 0
#endif
// Assumes the caller has set up our transform as it wants.
- (void)renderInContextIgnoringCache:(CGContextRef)ctx useAnimatedValues:(BOOL)useAnimatedValues;
{
    if (self.hidden)
        return;
    [self renderInContextIgnoringHiddenIgnoringCache:ctx useAnimatedValues:useAnimatedValues];
}

- (void)renderInContextIgnoringHiddenIgnoringCache:(CGContextRef)ctx useAnimatedValues:(BOOL)useAnimatedValues;
{
    [self layoutIfNeeded];
    
#define GET_VALUE(x) (useAnimatedValues ? OQCurrentAnimationValue(x) : self.x)
    
    // OOFlippedLayerView is flipped, so don't assert this
    //OBASSERT(GET_VALUE(geometryFlipped) == NO); // Need to flip the CTM ourselves for this property added in 10.6
    OBASSERT(GET_VALUE(isDoubleSided)); // Not handling back face culling.
    OBASSERT(GET_VALUE(mask) == nil); // Not handling mask layers or any filters
    OBASSERT(CGRectEqualToRect(GET_VALUE(contentsRect), CGRectMake(0, 0, 1, 1))); // Should be showing the full content
    OBASSERT(GET_VALUE(compositingFilter) == nil);
    OBASSERT([GET_VALUE(filters) count] == 0);
    OBASSERT([GET_VALUE(backgroundFilters) count] == 0);
    OBASSERT(GET_VALUE(shadowOpacity) == 0.0);
    OBASSERT(CATransform3DIsAffine(GET_VALUE(transform)));
    OBASSERT(CATransform3DIsAffine(GET_VALUE(sublayerTransform)));
    
    
    DEBUG_RENDER(@"  render %@ %@ anim:%d", self.name, [self shortDescription], useAnimatedValues);
    CGContextSaveGState(ctx);
    {
        CGFloat opacity = GET_VALUE(opacity);
        if (opacity < 1.0) {
            CGContextSetAlpha(ctx, opacity);
            CGContextBeginTransparencyLayer(ctx, NULL);
        }
        
        CGRect localBounds = self.bounds;
        DEBUG_RENDER(@"    bounds %@", NSStringFromRect(localBounds));
#if DEBUG_RENDER_ON
        CGRect frame = self.frame;
        DEBUG_RENDER(@"    frame %@", NSStringFromRect(frame));
#endif
        if (self.masksToBounds) {
            CGContextAddRect(ctx, localBounds);
            CGContextClip(ctx);
            DEBUG_RENDER(@"  mask to bounds");
        }
        
        CGColorRef backgroundColor = GET_VALUE(backgroundColor);
        if ([self isKindOfClass:[CAShapeLayer class]]) {
#define SHAPE_LAYER_GET_VALUE(x) (((CAShapeLayer *)self).x)

            OBASSERT(!useAnimatedValues);
            OBASSERT([SHAPE_LAYER_GET_VALUE(lineCap) isEqualToString:kCALineCapButt]);
            OBASSERT([SHAPE_LAYER_GET_VALUE(lineJoin) isEqualToString:kCALineJoinMiter]);
            OBASSERT(SHAPE_LAYER_GET_VALUE(lineDashPhase) == 0.0);
            OBASSERT(SHAPE_LAYER_GET_VALUE(lineDashPattern) == nil);
            
            CGColorRef fillColor = SHAPE_LAYER_GET_VALUE(fillColor);
            CGColorRef strokeColor = SHAPE_LAYER_GET_VALUE(strokeColor);
            
            if (fillColor != NULL) {
                CGContextSetFillColorWithColor(ctx, fillColor);
            }
            if (strokeColor != NULL) {
                CGContextSetStrokeColorWithColor(ctx, strokeColor);
                CGFloat lineWidth = SHAPE_LAYER_GET_VALUE(lineWidth);
                CGContextSetLineWidth(ctx, lineWidth);
            }
            
            if (fillColor || strokeColor) {
                CGPathRef path = SHAPE_LAYER_GET_VALUE(path);
                
                if (path)
                    CGContextAddPath(ctx, path);
                else if (self.cornerRadius != 0.0f) {
                    OQAppendRoundedRect(ctx, localBounds, SHAPE_LAYER_GET_VALUE(cornerRadius));
                } else
                    CGContextAddRect(ctx, localBounds);
                
                CGContextDrawPath(ctx, fillColor? (strokeColor? kCGPathFillStroke : kCGPathFill) : kCGPathStroke);
            }
        } else if (backgroundColor && CGColorGetAlpha(backgroundColor) != 0.0f) {
#if DEBUG_RENDER_ON
            {
                CGRect clip = CGContextGetClipBoundingBox(ctx);
                DEBUG_RENDER(@"    effective clip %@", NSStringFromRect(clip));
                CGRect inter = CGRectIntersection(clip, localBounds);
                DEBUG_RENDER(@"    inter %@", NSStringFromRect(inter));
                
                NSMutableString *colorString = [NSMutableString string];
                size_t componentCount = CGColorGetNumberOfComponents(backgroundColor);
                for (size_t componentIndex = 0; componentIndex < componentCount; componentIndex++)
                    [colorString appendFormat:@" %f", CGColorGetComponents(backgroundColor)[componentIndex]];
                
                DEBUG_RENDER(@"    fill %@ color:%@", NSStringFromRect(localBounds), colorString);
            }
#endif
            
            if (self.cornerRadius != 0.0f) {
                OQAppendRoundedRect(ctx, localBounds, self.cornerRadius);
            } else
                CGContextAddRect(ctx, localBounds);

            if (backgroundColor) {
                CGContextSetFillColorWithColor(ctx, backgroundColor);
                CGContextFillPath(ctx);
            }
        }
        
        // We require that the delegate implement the CGContextRef path, not just -displayLayer:.
        id delegate = self.delegate;
        BOOL didVectorDrawing = NO;
        if (delegate && [delegate respondsToSelector:@selector(drawLayer:inVectorContext:)]) {
            DEBUG_RENDER(@"  rendering %@ via vector delegate %@", [self shortDescription], [delegate shortDescription]);
            [delegate drawLayer:self inVectorContext:ctx];
            didVectorDrawing = YES;
        } else {
            didVectorDrawing = [self drawInVectorContext:ctx];
        }
        
        if (didVectorDrawing) {
            DEBUG_RENDER(@"  rendered %@ directly to vector", [self shortDescription]);
        } else {
            if (delegate && [delegate respondsToSelector:@selector(drawLayer:inContext:)]) {
                DEBUG_RENDER(@"  rendering %@ via bitmap delegate %@", [self shortDescription], [delegate shortDescription]);
                [delegate drawLayer:self inContext:ctx];
            } else {
                DEBUG_RENDER(@"  rendering %@ directly to bitmap", [self shortDescription]);
                [self drawInContext:ctx];
            }
        }
        
        if (![self isKindOfClass:[CAShapeLayer class]]) {
            CGColorRef borderColor = GET_VALUE(borderColor);
            if (self.borderWidth > 0.0 && borderColor && CGColorGetAlpha(borderColor) != 0.0f) {
                if (self.cornerRadius != 0.0f) {
                    OQAppendRoundedRect(ctx, localBounds, self.cornerRadius);
                } else
                    CGContextAddRect(ctx, localBounds);
                
                CGContextSetLineWidth(ctx, self.borderWidth);
                CGContextSetStrokeColorWithColor(ctx, borderColor);
                CGContextStrokePath(ctx);
            }
        }
        
        if ([self isKindOfClass:[CAGradientLayer class]]) {
            CAGradientLayer *gradientLayer = (CAGradientLayer *)self;
            OBASSERT(gradientLayer.locations == nil); // UNDONE: not handling custom locations for the gradient colors

            CGContextSaveGState(ctx);
            CGGradientRef gradient = CGGradientCreateWithColors(NULL, (CFArrayRef)gradientLayer.colors, NULL);
            CGPoint gradientStart = CGPointMake(CGRectGetMinX(localBounds) + gradientLayer.startPoint.x * CGRectGetWidth(localBounds), CGRectGetMinY(localBounds) + gradientLayer.startPoint.y * CGRectGetHeight(localBounds));
            CGPoint gradientEnd = CGPointMake(CGRectGetMinX(localBounds) + gradientLayer.endPoint.x * CGRectGetWidth(localBounds), CGRectGetMinY(localBounds) + gradientLayer.endPoint.y * CGRectGetHeight(localBounds));
            CGContextClipToRect(ctx, localBounds);
            CGContextDrawLinearGradient(ctx, gradient, gradientStart, gradientEnd, kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation);
            CGGradientRelease(gradient);
            CGContextRestoreGState(ctx);
        }
        
        NSArray *sublayers = self.sublayers;
        if ([sublayers count] > 0) {
            CATransform3D sublayerTransform = self.sublayerTransform;
            if (!CATransform3DIsIdentity(sublayerTransform)) {
                CGPoint localAnchorPoint = self.anchorPoint;
                CGSize localAnchorOffset = CGSizeMake(localBounds.origin.x + localAnchorPoint.x * localBounds.size.width, localBounds.origin.y + localAnchorPoint.y * localBounds.size.height);
                
                CGAffineTransform affineSublayerTransform = CATransform3DGetAffineTransform(sublayerTransform);
                
                CGContextTranslateCTM(ctx, localAnchorOffset.width, localAnchorOffset.height);
                CGContextConcatCTM(ctx, affineSublayerTransform);
                CGContextTranslateCTM(ctx, -localAnchorOffset.width, -localAnchorOffset.height);
            }
            
            NSArray *sortedSublayers = [[self sublayers] sortedArrayUsingComparator:^(id layer1, id layer2) {
                if ([layer1 zPosition] > [layer2 zPosition]) {
                    return (NSComparisonResult)NSOrderedDescending;
                }
                
                if ([layer1 zPosition] < [layer2 zPosition]) {
                    return (NSComparisonResult)NSOrderedAscending;
                }
                return (NSComparisonResult)NSOrderedSame;
            }];

            for (CALayer *sublayer in sortedSublayers) {            
                CGContextSaveGState(ctx);
                //OBASSERT(CGPointEqualToPoint(self.bounds.origin, CGPointMake(0, 0)));
                
                CGPoint subAnchorPoint = sublayer.anchorPoint; // 0-1 unit coordinate space with 0,0 being bottom left.
                CGRect subBounds = sublayer.bounds;
                
                CGPoint position = sublayer.position; // position is the coordinate in the superlayer that our anchor point should match.
                CGContextTranslateCTM(ctx, position.x, position.y);
                
                // Transform is applied relative to the anchor point.
                CATransform3D transform = sublayer.transform;
                if (!CATransform3DIsIdentity(transform)) {
                    CGAffineTransform affineTransform = CATransform3DGetAffineTransform(transform);
                    CGContextConcatCTM(ctx, affineTransform);
                } 
                
                CGContextTranslateCTM(ctx, -(subBounds.origin.x + subAnchorPoint.x * subBounds.size.width), -(subBounds.origin.y + subAnchorPoint.y * subBounds.size.height));
                
                [sublayer renderInContextIgnoringCache:ctx useAnimatedValues:useAnimatedValues]; // Will push/pop its own gsave
                CGContextRestoreGState(ctx);
            }
        }
        
        if (opacity < 1.0) {
            CGContextEndTransparencyLayer(ctx);
        }
    }
    CGContextRestoreGState(ctx);
}

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE

- (NSImage *)imageForRect:(NSRect)rect useAnimatedValues:(BOOL)useAnimatedValues;
{
    NSImage *image = [[[NSImage alloc] initWithSize:rect.size] autorelease];
    [image lockFocus];
    {
        CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(ctx);
        {
            CGContextTranslateCTM(ctx, -rect.origin.x, -rect.origin.y);
            [self renderInContextIgnoringCache:ctx useAnimatedValues:useAnimatedValues];
        }
        CGContextRestoreGState(ctx);
    }
    [image unlockFocus];
    
    return image;
}

// Can set these by hand in the debugger.  Looking them up in code is harder than just linking or dlsym since they are static.
static CFTypeID (*pCABackingStoreGetTypeID)(void) = NULL;
static CGImageRef (*pCABackingStoreGetCGImage)(void *backingStore) = NULL;

// Builds a directory of images for the receiving layer and all the parent layers.
- (void)writeImagesAndOpen;
{
    unsigned int layerIndex = 0;
    CALayer *layer = self;
    
    NSMutableArray *imageURLs = [NSMutableArray array];
    NSError *error = nil;
    NSString *dir = [[NSFileManager defaultManager] temporaryDirectoryForFileSystemContainingPath:@"/" error:&error];
    if (!dir) {
        NSLog(@"Unable to create temporary directory: %@", [error toPropertyList]);
        return;
    }
    
    while (layer) {
        if ([layer.contents isKindOfClass:[NSImage class]]) {
            NSData *data = [(NSImage *)layer.contents TIFFRepresentation];
            NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%03d-%p.png", layerIndex, layer]];
            
            if (![data writeToFile:path options:0 error:&error])
                NSLog(@"Unable to write %@: %@", path, [error toPropertyList]);

            continue;
        }
        
        CGImageRef image = (CGImageRef)layer.contents;
        
        if (image && CFGetTypeID(image) != CGImageGetTypeID()) {
            if (pCABackingStoreGetTypeID && pCABackingStoreGetCGImage && CFGetTypeID(image) == pCABackingStoreGetTypeID()) {
                image = pCABackingStoreGetCGImage(image);
            }
        }
        
        if (image && CFGetTypeID(image) == CGImageGetTypeID()) {
            NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%03d-%p.png", layerIndex, layer]];
            NSURL *url = [NSURL fileURLWithPath:path];
            CGImageDestinationRef imageDest = CGImageDestinationCreateWithURL((CFURLRef)url, kUTTypePNG, 1, NULL);
            if (!imageDest) {
                NSLog(@"Unable to create image destination for %@", path);
            } else {
                CGImageDestinationAddImage(imageDest, image, NULL);
                if (!CGImageDestinationFinalize(imageDest))
                    NSLog(@"Unable to finalize image destination for %@", path);
                else
                    [imageURLs addObject:url];
                CFRelease(imageDest);
            }
        } else {
            NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%03d-%p-empty", layerIndex, layer]];
            if (![[NSData data] writeToFile:path options:0 error:&error])
                NSLog(@"Unable to write %@: %@", path, [error toPropertyList]);
        }
        layerIndex++;
        layer = layer.superlayer;
    }
    
    if ([imageURLs count] > 0) {
        NSLog(@"opening %@", imageURLs);
        [[NSWorkspace sharedWorkspace] openURLs:imageURLs withAppBundleIdentifier:nil options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
    }
}

#endif // !TARGET_OS_IPHONE

@end

@implementation CAMediaTimingFunction (OQExtensions)

+ (id)functionCompatibleWithDefault;
{
    // Determined empircally.
    static CAMediaTimingFunction *function = nil;
    if (!function)
        function = [[self alloc] initWithControlPoints:0.25f :0.1f :0.25f :1.0f];
    return function;
    
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
+ (CAMediaTimingFunction *)mediaTimingFunctionForUIViewAnimationCurve:(UIViewAnimationCurve)uiViewAnimationCurve;
{
    NSString *mediaTimingFunctionName = nil;
    switch (uiViewAnimationCurve) {
        case UIViewAnimationCurveEaseInOut:
            mediaTimingFunctionName = kCAMediaTimingFunctionEaseInEaseOut;
            break;
        case UIViewAnimationCurveEaseIn:
            mediaTimingFunctionName = kCAMediaTimingFunctionEaseIn;
            break;
        case UIViewAnimationCurveEaseOut:
            mediaTimingFunctionName = kCAMediaTimingFunctionEaseOut;
            break;
        case UIViewAnimationCurveLinear:
            mediaTimingFunctionName = kCAMediaTimingFunctionLinear;
            break;
        default:
            OBASSERT_NOT_REACHED("Unknown curve");
            mediaTimingFunctionName = kCAMediaTimingFunctionLinear;
            break;
    }
    return [self functionWithName:mediaTimingFunctionName];
}
#endif

@end
