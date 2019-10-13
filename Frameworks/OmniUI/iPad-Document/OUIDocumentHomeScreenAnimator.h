// Copyright 2010-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIViewControllerTransitioning.h>
#import <UIKit/UINavigationController.h>
#import <OmniUIDocument/OUIDocumentPickerHomeScreenViewController.h>
#import <OmniUIDocument/OUIDocumentPickerViewController.h>

@interface OUIDocumentHomeScreenAnimator : NSObject  <UIViewControllerAnimatedTransitioning>

@property (nonatomic, getter=isPushing) BOOL pushing;

@end

@interface OUIDocumentPickerHomeScreenViewController (HomeScreenAnimatorSupport)
- (CGRect)frameOfCellForScope:(ODSScope *)scope inView:(UIView *)transitionContainerView;
@end
