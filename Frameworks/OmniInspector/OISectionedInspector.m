// Copyright 2007-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniInspector/OISectionedInspector.h>

#import <AppKit/AppKit.h>
#import <OmniAppKit/OmniAppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniInspector/OIButtonMatrixBackgroundView.h>
#import <OmniInspector/OIInspectorController.h>
#import <OmniInspector/OIInspectorRegistry.h>
#import <OmniInspector/OIInspectorSection.h>
#import <OmniInspector/OIInspectorTabController.h>
#import <OmniInspector/OITabMatrix.h>
#import <OmniInspector/OITabbedInspector.h>
#import <OmniInspector/OITabCell.h>

RCS_ID("$Id$")

@interface OISectionedInspector (/*Private*/)
@property (strong, nonatomic) IBOutlet NSView *inspectionView;
- (void)_layoutSections;
@end

#pragma mark -

@implementation OISectionedInspector

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib;
{
    float inspectorWidth = [[OIInspectorRegistry inspectorRegistryForMainWindow] inspectorWidth];
    
    NSRect inspectionFrame = [inspectionView frame];
    OBASSERT(inspectionFrame.size.width <= inspectorWidth); // OK to make views from nibs wider, but probably indicates a problem if we are making them smaller.
    inspectionFrame.size.width = inspectorWidth;
    [inspectionView setFrame:inspectionFrame];
    
    
    [self _layoutSections];
}

#pragma mark -
#pragma mark OIInspector subclass

- initWithDictionary:(NSDictionary *)dict inspectorRegistry:(OIInspectorRegistry *)inspectorRegistry bundle:(NSBundle *)sourceBundle;
{
    if (!(self = [super initWithDictionary:dict inspectorRegistry:inspectorRegistry bundle:sourceBundle]))
	return nil;
    
    NSMutableArray <OIInspectorSection <OIConcreteInspector> *> *sectionInspectors = [[NSMutableArray alloc] init];
    
    // Read our sub-inspectors from the plist
    for (NSDictionary *sectionPlist in [dict objectForKey:@"sections"]) {
        NSDictionary *inspectorPlist = [sectionPlist objectForKey:@"inspector"];
        
        if (!inspectorPlist && [sectionPlist objectForKey:@"class"]) {
            inspectorPlist = sectionPlist;
        } else {
            if (!inspectorPlist) {
                OBASSERT_NOT_REACHED("No inspector specified for section");
                return nil;
            }
        }
        
        OIInspector <OIConcreteInspector> *inspector = [OIInspector inspectorWithDictionary:inspectorPlist inspectorRegistry:inspectorRegistry bundle:sourceBundle];
        if (!inspector)
            // Don't log an error; OIInspector should have already if it is an error (might just be an OS version check)
            continue;

        if (![inspector isKindOfClass:[OIInspectorSection class]]) {
            NSLog(@"%@ is not a subclass of OIInspectorSection.", inspector);
            continue;
        }
        OIInspectorSection <OIConcreteInspector> *section = (typeof(section))inspector;

        [sectionInspectors addObject:section];
    }
    
    _sectionInspectors = [[NSArray alloc] initWithArray:sectionInspectors];
    
    return self;
}

- (void)inspectorDidResize:(OIInspector *)resizedInspector;
{
    OBASSERT(resizedInspector != self); // Don't call us if we are the resized inspector, only on ancestors of that inspector
    NSView *resizedView = [resizedInspector view];
    OBASSERT([resizedView isDescendantOf:self.view]);
    for (OIInspectorSection *section in _sectionInspectors) {
        if ([resizedView isDescendantOf:[section view]]) {
            if (resizedInspector != section) {
                [section inspectorDidResize:resizedInspector];
            }
            break;
        }
    }
    [self _layoutSections];
}

- (void)setInspectorController:(OIInspectorController *)aController;
{
    [super setInspectorController:aController];

    // Set the controller on all of our child inspectors as well
    for (OIInspectorSection <OIConcreteInspector> *inspector in _sectionInspectors) {
        inspector.inspectorController = aController;
    }
}

#pragma mark -
#pragma mark OIConcreteInspector protocol

- (NSString *)nibName;
{
    return @"OISectionedInspector";
}

- (NSBundle *)nibBundle;
{
    return OMNI_BUNDLE;
}

- (NSPredicate *)inspectedObjectsPredicate;
{
    // Could either OR the predicates for the sub-inspectors or require that this class be subclassed to provide the overall predicate.
    //OBRequestConcreteImplementation(self, _cmd);
    
    static NSPredicate *truePredicate = nil;
    if (!truePredicate)
        truePredicate = [NSPredicate predicateWithValue:YES];
    return truePredicate;
}

- (void)inspectObjects:(NSArray *)list 
{
    for (OIInspectorSection <OIConcreteInspector> *inspector in _sectionInspectors)
        [inspector inspectObjects:[list filteredArrayUsingPredicate:[inspector inspectedObjectsPredicate]]];
}

#pragma mark -
#pragma mark NSObject (NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)item;
{
    OIInspectorController *inspectorController = self.inspectorController;
    BOOL isVisible = [inspectorController isExpanded] && [inspectorController isVisible];
    
    if  (!isVisible) {
        [item setState:NSOffState];
    }
    return YES;
}

#pragma mark -
#pragma mark Private

@synthesize inspectionView=inspectionView;

- (void)_layoutSections;
{
    OBPRECONDITION([_sectionInspectors count] > 0);
    OBPRECONDITION([inspectionView isFlipped]); // We use an OITabbedInspectorContentView in the nib to make layout easier.
    
    NSSize size = NSMakeSize([inspectionView frame].size.width, 0);
    
    NSUInteger sectionIndex, sectionCount = [_sectionInspectors count];
    
    NSView *veryFirstKeyView = nil;
    NSView *previousLastKeyView = nil;

    for (sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++) {
        OIInspectorSection *section = [_sectionInspectors objectAtIndex:sectionIndex];

        if (sectionIndex > 0) {
            NSRect dividerFrame = [inspectionView frame];
            dividerFrame.origin.y = size.height;
            dividerFrame.size.height = 1;
            
            NSBox *divider = [[NSBox alloc] initWithFrame:dividerFrame];
            [divider setBorderType:NSLineBorder];
            [divider setBoxType:NSBoxSeparator];
            
            [inspectionView addSubview:divider];
            
            size.height += 1;
	}
	
        NSView *view = [section view];
        NSRect viewFrame = [view frame];
	OBASSERT(viewFrame.size.width <= size.width); // make sure it'll fit
	
        viewFrame.origin.x = (CGFloat)floor((size.width - viewFrame.size.width) / 2.0);
        viewFrame.origin.y = size.height;
        viewFrame.size = [view frame].size;
        [view setFrame:viewFrame];
	[inspectionView addSubview:view];
	
        size.height += [view frame].size.height;
        
        // Stitch the key view loop together
        NSView *firstKeyView = [section firstKeyView];
        if (firstKeyView) {
            if (!veryFirstKeyView)
                veryFirstKeyView = firstKeyView;
            
            // Find the last key view in this section
            NSView *lastKeyView = firstKeyView;
            while ([lastKeyView nextKeyView])
                lastKeyView = [lastKeyView nextKeyView];
            
            if (previousLastKeyView) {
                OBASSERT([previousLastKeyView nextKeyView] == nil);
                [previousLastKeyView setNextKeyView:firstKeyView];
            }
            
            previousLastKeyView = lastKeyView;
            OBASSERT(previousLastKeyView);
            OBASSERT([previousLastKeyView nextKeyView] == nil);
        }
    }
    
    // Close the loop from bottom back to top
    [previousLastKeyView setNextKeyView:veryFirstKeyView];
    
    NSRect contentFrame = [inspectionView frame];
    contentFrame.size.height = size.height;
    [inspectionView setFrame:contentFrame];
    
    [inspectionView setNeedsDisplay:YES];
    [self.inspectorController prepareWindowForDisplay];
    
    
}

@end
