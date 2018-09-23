// Copyright 2010-2018 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <UIKit/UIImage.h>

extern UIImage *OUITableViewItemSelectionImage(UIControlState state);
extern UIImage *OUITableViewItemSelectionMixedImage(void);

extern UIImage *OUIStepperMinusImage(void);
extern UIImage *OUIStepperPlusImage(void);
extern UIImage *OUIToolbarUndoImage(void);
extern UIImage *OUIDisclosureIndicatorImage(void);

extern UIImage *OUIToolbarForwardImage(void);
extern UIImage *OUIToolbarBackImage(void);

@interface OUIImageLocation : NSObject

- initWithName:(NSString *)name bundle:(NSBundle *)bundle;
- initWithName:(NSString *)name bundle:(NSBundle *)bundle renderingMode:(UIImageRenderingMode)renderingMode;

@property(nonatomic,readonly) NSBundle *bundle;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) UIImageRenderingMode renderingMode;

@property(nonatomic,readonly) UIImage *image;

@end
