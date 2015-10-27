// Copyright 2010-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

//ContentInsets

#import <OmniUI/OUISegmentedViewController.h>

RCS_ID("$Id$")

@interface OUISegmentedViewController () <UINavigationBarDelegate, UINavigationControllerDelegate>{
    BOOL _tempHidingDismissButton;
    BOOL _shouldShowDismissButton;
}

@property (nonatomic, strong) UINavigationBar *navigationBar;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

@property (nonatomic, weak) id<UINavigationControllerDelegate> originalNavDelegate;

@property (nonatomic, assign) CGSize selectedViewSizeAfterLayout;

@end

@implementation OUISegmentedViewController
{
    BOOL _invalidated;
}

- (void)awakeFromNib;
{
    [super awakeFromNib];
    
    [self _setupSegmentedControl];
}

- (void)viewDidLoad
{
    OBPRECONDITION(_invalidated == NO);

    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationBar = [[UINavigationBar alloc] init];
    self.navigationBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.navigationBar.delegate = self;
    [self.view addSubview:self.navigationBar];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(_navigationBar);
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_navigationBar]|" options:0 metrics:nil views:views]];
    
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.navigationBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.topLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0]];
}

- (void)viewDidDisappear:(BOOL)animated;
{
    [super viewDidDisappear:animated];

    if (_invalidated) {
        // If we do this in -oui_invalidate, we can be in the middle of an appearance transition. This can cause <bug:///121483> (Crasher: Crash (sometimes) tapping 'Documents' to close document) by removing the selected view controller from its parent while in the middle of an appearance transition.
        self.viewControllers = @[];
    }
}

#pragma mark - Public API

- (void)oui_invalidate;
{
    _invalidated = YES;

    [self.navigationBar popNavigationItemAnimated:NO];
    [self.navigationBar removeFromSuperview];
    self.navigationBar = nil;

    self.view = nil;
}

- (CGFloat)topLayoutLength;{
    return CGRectGetMaxY(self.navigationBar.frame);
}

- (void)setViewControllers:(NSArray *)viewControllers;
{
    if (_viewControllers == viewControllers) {
        return;
    }
    
    _viewControllers = [viewControllers copy];
    self.selectedViewController = [_viewControllers firstObject];

    if (_viewControllers)
        [self _setupSegmentedControl];
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController;
{
    OBPRECONDITION(!selectedViewController || [_viewControllers containsObject:selectedViewController]);

    if (_selectedViewController == selectedViewController) {
        return;
    }
    
    // Remove currently selected view controller.
    if (_selectedViewController) {
          // we used to try to only send appearance transitions if we were "on screen".  But that dropped some on the floor when this controller is in a splitview sidebar.  So now we send them always.  Which sometimes results in child view controllers getting doubled appearance messages.  So we deal with that.
        BOOL performTransition = [self isViewLoaded] && !_invalidated;

        [_selectedViewController willMoveToParentViewController:nil];

        if (performTransition)
            [_selectedViewController beginAppearanceTransition:NO animated:NO];
        
        if ([_selectedViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *selectedNavigationController = (UINavigationController *)_selectedViewController;
            selectedNavigationController.delegate = self.originalNavDelegate;
        }
        [_selectedViewController.view removeFromSuperview];
        
        [_selectedViewController removeFromParentViewController];
        if (performTransition)
            [_selectedViewController endAppearanceTransition];
        
        _selectedViewController = nil;
    }
    
    _selectedViewController = selectedViewController;

    if (_selectedViewController) {
        _selectedViewController.view.translatesAutoresizingMaskIntoConstraints = NO;

        // Move in new view controller/view. addChildViewController: automatically calls the childs willMoveToParentViewController: passing in the new parent. We shouldn't call that directly while adding the child VC.
        //    [_selectedViewController willMoveToParentViewController:self];
        [_selectedViewController beginAppearanceTransition:YES animated:NO];
        [self addChildViewController:_selectedViewController];

        [self.view addSubview:_selectedViewController.view];
    
        // Add constraints
        NSDictionary *views = @{ @"navigationBar" : _navigationBar, @"childView" : _selectedViewController.view };
    
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[childView]|"
                                                                          options:0
                                                                          metrics:nil
                                                                            views:views]];

        if ([_selectedViewController isKindOfClass:[UINavigationController class]]) {
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[navigationBar][childView]|"
                                                                              options:0
                                                                              metrics:nil
                                                                                views:views]];
            UINavigationController *selectedNavigationController = (UINavigationController *)_selectedViewController;
            self.originalNavDelegate = selectedNavigationController.delegate;
            selectedNavigationController.delegate = self;
        
        }
        else {
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[childView]|"
                                                                              options:0
                                                                              metrics:nil
                                                                                views:views]];
        }
    
        [_selectedViewController didMoveToParentViewController:self];
        [_selectedViewController endAppearanceTransition];
    
        // Ensure that the segmented control is showing the correctly selected segment.
        // Make sure to use the _selectedIndex ivar directly here because the setter will end up calling into this method and we don't want to create an infinite loop.
        _selectedIndex = [self.viewControllers indexOfObject:_selectedViewController];
        self.segmentedControl.selectedSegmentIndex = _selectedIndex;
    } else {
        _selectedIndex = NSNotFound;
    }

    if (self.isViewLoaded && !_invalidated)
        [self.view bringSubviewToFront:self.navigationBar];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex;
{
    if (_selectedIndex == selectedIndex) {
        return;
    }
    
    _selectedIndex = selectedIndex;
    
    UIViewController *viewControllerToSelect = self.viewControllers[selectedIndex];
    self.selectedViewController = viewControllerToSelect;
}

#pragma mark - Private API

- (void)_setupSegmentedControl;
{
    NSMutableArray *segmentTitles = [NSMutableArray array];
    for (UIViewController *vc in self.viewControllers) {
        NSString *title = vc.title;
        OBASSERT(title);
        
        [segmentTitles addObject:title];
    }
    
    
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:segmentTitles];
    [self.segmentedControl setSelectedSegmentIndex:0];
    [self.segmentedControl addTarget:self action:@selector(_segmentValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.navigationItem.titleView = self.segmentedControl;
    if (self.leftBarButtonItem) {
        self.navigationItem.leftBarButtonItem = self.leftBarButtonItem;
    }
    [self.navigationBar pushNavigationItem:self.navigationItem animated:NO];
}

- (void)_segmentValueChanged:(id)sender;
{
    OBPRECONDITION([sender isKindOfClass:[UISegmentedControl class]]);
    
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    NSInteger selectedIndex = segmentedControl.selectedSegmentIndex;
    
    [self setSelectedIndex:selectedIndex];
}

- (void)_dismiss:(id)sender;
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)setShouldShowDismissButton:(BOOL)shouldShow;
{
    _shouldShowDismissButton = shouldShow;
    if (_shouldShowDismissButton && !_tempHidingDismissButton) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_dismiss:)];
    }
    else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)temporarilyHideDismissButton:(BOOL)hide;
{
    _tempHidingDismissButton = hide;
    [self setShouldShowDismissButton:_shouldShowDismissButton];
}

#pragma mark - UINavigationBarDelegate

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar;
{
    if (bar == self.navigationBar) {
        return UIBarPositionTopAttached;
    }

    return UIBarPositionAny;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
{
    if ([self.originalNavDelegate respondsToSelector:@selector(navigationController:willShowViewController:animated:)]) {
        [self.originalNavDelegate navigationController:navigationController willShowViewController:viewController animated:animated];
    }
    
    [viewController.navigationController setNavigationBarHidden:viewController.wantsHiddenNavigationBar animated:YES];
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
{
    if ([self.originalNavDelegate respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) {
        [self.originalNavDelegate navigationController:navigationController didShowViewController:viewController animated:animated];
    }
}

#if defined(__IPHONE_9_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController;
#else
- (NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController;
#endif
{
    if ([self.originalNavDelegate respondsToSelector:@selector(navigationControllerSupportedInterfaceOrientations:)]) {
        return [self.originalNavDelegate navigationControllerSupportedInterfaceOrientations:navigationController];
    }
    
    return UIInterfaceOrientationMaskAll;
}

- (UIInterfaceOrientation)navigationControllerPreferredInterfaceOrientationForPresentation:(UINavigationController *)navigationController;
{
    if ([self.originalNavDelegate respondsToSelector:@selector(navigationControllerPreferredInterfaceOrientationForPresentation:)]) {
        return [self.originalNavDelegate navigationControllerPreferredInterfaceOrientationForPresentation:navigationController];
    }
    
    return UIInterfaceOrientationPortrait;
}

- (id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                          interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>) animationController;
{
    if ([self.originalNavDelegate respondsToSelector:@selector(navigationController:interactionControllerForAnimationController:)]) {
        return [self.originalNavDelegate navigationController:navigationController interactionControllerForAnimationController:animationController];
    }
    
    return nil;
}

- (id <UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                   animationControllerForOperation:(UINavigationControllerOperation)operation
                                                fromViewController:(UIViewController *)fromVC
                                                  toViewController:(UIViewController *)toVC;
{
    if ([self.originalNavDelegate respondsToSelector:@selector(navigationController:animationControllerForOperation:fromViewController:toViewController:)]) {
        return [self.originalNavDelegate navigationController:navigationController animationControllerForOperation:operation fromViewController:fromVC toViewController:toVC];
    }
    
    return nil;
}

@end


@implementation UIViewController (OUISegmentedViewControllerExtras)
- (BOOL)wantsHiddenNavigationBar;
{
    return NO;
}

- (OUISegmentedViewController *)segmentedViewController;
{
    UIViewController *viewControllerToCheck = self;
    
    while (viewControllerToCheck) {
        if ([viewControllerToCheck isKindOfClass:[OUISegmentedViewController class]]) {
            return (OUISegmentedViewController *)viewControllerToCheck;
        }
        
        viewControllerToCheck = viewControllerToCheck.parentViewController;
    }
    
    return nil;
}

@end
