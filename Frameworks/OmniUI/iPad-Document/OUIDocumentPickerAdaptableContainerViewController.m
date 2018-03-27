// Copyright 2010-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.


#import "OUIDocumentPickerAdaptableContainerViewController.h"

#import <OmniUI/OUIAppController.h>
#import <OmniUI/UIView-OUIExtensions.h>
#import <OmniUIDocument/OUIDocumentPickerHomeScreenViewController.h>

RCS_ID("$Id$")

#pragma mark -

@interface OUIDocumentPickerAdaptableContainerViewController () <UINavigationControllerDelegate>
@property (weak, readwrite, nonatomic) IBOutlet UIImageView *backgroundView;
@end

@implementation OUIDocumentPickerAdaptableContainerViewController
{
    NSArray *_stolenBarItems;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    OBPRECONDITION(nibNameOrNil == nil);
    OBPRECONDITION(nibBundleOrNil == nil);
    
    if ((self = [super initWithNibName:@"OUIDocumentPickerAdaptableContainerViewController" bundle:OMNI_BUNDLE])) {
        self.definesPresentationContext = YES;
        self.providesPresentationContextTransitionStyle = YES;
    }
    
    UINavigationController *navController = [[UINavigationController alloc] init];
    navController.delegate = self;
    self.wrappedViewController = navController;
    
    return self;
}

- (void)viewDidLoad;
{
    // Clip the corners of the container view
    CALayer *layer = self.containerView.layer;
    layer.cornerRadius = 8.0f;
    layer.masksToBounds = YES;
    
    [super viewDidLoad];
}

#pragma mark - API

#if 0 && defined(DEBUG_shannon)
- (NSString*)description{
    __block NSString *usefulDescription = [super description];
    usefulDescription = [usefulDescription stringByAppendingFormat:@" with wrappedViewController: %@ {", self.wrappedViewController];
    UINavigationController *wrappedNavController = [self.wrappedViewController isKindOfClass:[UINavigationController class]] ? (UINavigationController*)self.wrappedViewController : nil;
    if (wrappedNavController.viewControllers.count) {
        [wrappedNavController.viewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            usefulDescription  = [usefulDescription stringByAppendingFormat:@"\n\t\t\t[%lu]%@", (unsigned long)idx, obj];
        }];
    } else {
        usefulDescription = [usefulDescription stringByAppendingFormat:@"\n\t\t\tno view controllers"];
    }
    usefulDescription = [usefulDescription stringByAppendingString:@"\n\t\t}"];
    return usefulDescription;
}
#endif

- (UIImageView *)backgroundView;
{
    (void)[self view];
    return _backgroundView;
}

- (void)pushViewControllersForTransitionToRegularSizeClass:(NSArray *)viewControllersToAdd;
{
    [(UINavigationController *)self.wrappedViewController setViewControllers:viewControllersToAdd];
    
    // Steal the home screen view controller's bar items for our own.
    OUIDocumentPickerHomeScreenViewController *home = OB_CHECKED_CAST(OUIDocumentPickerHomeScreenViewController, viewControllersToAdd[0]);
    self.navigationItem.title = home.navigationItem.title;
    _stolenBarItems = home.navigationItem.rightBarButtonItems;
    home.navigationItem.rightBarButtonItems = nil;
    [self _updateBarButtonItemsForTopViewControllerAnimated:NO];
}

- (NSArray *)popViewControllersForTransitionToCompactSizeClass;
{
    UINavigationController *wrappedNav = (UINavigationController *)self.wrappedViewController;
    NSArray *viewControllers = [NSArray arrayWithArray:wrappedNav.viewControllers];
    
    // Give the bar button items back to the home screen.
    if (viewControllers.count > 0) {
        OUIDocumentPickerHomeScreenViewController *home = OB_CHECKED_CAST(OUIDocumentPickerHomeScreenViewController, viewControllers[0]);
        home.navigationItem.rightBarButtonItems = _stolenBarItems;
    }
    
    self.navigationItem.rightBarButtonItems = nil;
    _stolenBarItems = nil;
    self.navigationItem.title = nil;
    
    [wrappedNav setViewControllers:[NSArray array]];
    return viewControllers;
}

- (void)showUnembeddedViewController:(UIViewController *)viewController sender:(id)sender;
{
    [self.parentViewController showViewController:viewController sender:sender];
}

- (NSArray*)displayedBarButtonItems
{
    return _stolenBarItems;
}

- (void)resetBarButtonItems:(NSArray *)rightBarButtonItems
{
    UIViewController *topViewController = ((UINavigationController *)self.wrappedViewController).topViewController;
    if ([topViewController isKindOfClass:[OUIDocumentPickerHomeScreenViewController class]]) {
        _stolenBarItems = rightBarButtonItems;
        [self _updateBarButtonItemsForTopViewControllerAnimated:YES];
    }
}

#pragma mark - UINavigationControllerDelegate

- (void)_updateBarButtonItemsForTopViewControllerAnimated:(BOOL)animated;
{
    UIViewController *topViewController = ((UINavigationController *)self.wrappedViewController).topViewController;
    NSArray *items = [topViewController isKindOfClass:[OUIDocumentPickerHomeScreenViewController class]] ? _stolenBarItems : nil;
    [self.navigationItem setRightBarButtonItems:items animated:animated];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
{
    NSArray *viewControllers = navigationController.viewControllers;
    if (viewControllers.count > 0) {
        BOOL isHomeScreen = (viewController == navigationController.viewControllers[0]);
        [navigationController setNavigationBarHidden:isHomeScreen animated:animated];
    }
    
    [self _updateBarButtonItemsForTopViewControllerAnimated:animated];
}

@end

@implementation UIViewController (OUIDocumentPickerAdaptableContainerEmbeddedPresentation)

- (void)showUnembeddedViewController:(UIViewController *)viewController sender:(id)sender;
{
    UIViewController *target = [self targetViewControllerForAction:_cmd sender:sender];
    if (target == self || target == nil)
        [self showViewController:viewController sender:sender];
    else
        [target showUnembeddedViewController:viewController sender:sender];
}

@end



@implementation UIViewController (OUIDocumentPickerAdaptableContainerViewControllerAdditions)

+ (OUIDocumentPickerAdaptableContainerViewController *)adaptableContainerControllerForController:(UIViewController*)controller;
{
    UIViewController *parentVC = controller.parentViewController;
    while (parentVC != nil) {
        if ([parentVC isKindOfClass:[OUIDocumentPickerAdaptableContainerViewController class]]) {
            break;
        }
        
        parentVC = parentVC.parentViewController;
    }
    
    OBASSERT_IF(parentVC != nil, [parentVC isKindOfClass:[OUIDocumentPickerAdaptableContainerViewController class]]);
    return (OUIDocumentPickerAdaptableContainerViewController *)parentVC;
}

@end
