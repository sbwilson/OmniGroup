// Copyright 2005-2011 The Omni Group. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <AppKit/NSAnimation.h>

@class OQTargetAnimation; // Since we use it in the defn of _imp before the class is finished being declared

@interface OQTargetAnimation : NSAnimation
{
    id _target;
    SEL _selector;
    void (*_imp)(id target, SEL sel, NSAnimationProgress progress, OQTargetAnimation *animation, void *userInfo);
    void *_userInfo;
}

- (id)initWithTarget:(id)target selector:(SEL)selector;

- (void)setUserInfo:(void *)userInfo;
- (void *)userInfo;

@end

// The target/selector pair must have this signature
@interface NSObject (OQTargetAnimationTarget)
- (void)setProgress:(NSAnimationProgress)progress forAnimation:(OQTargetAnimation *)animation userInfo:(void *)userInfo;
@end
