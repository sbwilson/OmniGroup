// Copyright 2010-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

@interface UIFontDescriptor (OUIExtensions)

- (UIFontDescriptor *)fontDescriptorByAddingProportionalNumberAttributes;
- (UIFontDescriptor *)fontDescriptorByAddingMonospacedNumberAttributes;
- (UIFontDescriptor *)fontDescriptorByAddingTimeAttributes;

@end
