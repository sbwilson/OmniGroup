// Copyright 2010-2018 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniUI/OUIAbstractColorInspectorSlice.h>

NS_ASSUME_NONNULL_BEGIN

@class OUIColorAttributeInspectorWell;

@interface OUIColorAttributeInspectorSlice : OUIAbstractColorInspectorSlice

@property(nonatomic,strong) OUIColorAttributeInspectorWell *textWell;

- initWithLabel:(NSString *)label;
@end

NS_ASSUME_NONNULL_END

