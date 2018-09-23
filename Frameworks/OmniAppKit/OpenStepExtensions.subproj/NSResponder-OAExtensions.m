// Copyright 2008-2018 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/NSResponder-OAExtensions.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Id$")

@implementation NSResponder (OAExtensions)

- (void)noop_didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo;
{
    // Nothing
}

- (void)presentError:(NSError *)error modalForWindow:(NSWindow *)window;
{
    // If the caller doesn't care about the delegate, pass ourselves and a no-op selector.  The superclass method can crash trying to build an NSInvocation from this goop.
    [self presentError:error modalForWindow:window delegate:self didPresentSelector:@selector(noop_didPresentErrorWithRecovery:contextInfo:) contextInfo:NULL];
}

- (NSArray *)responderChain;
{
    NSMutableArray *responders = [NSMutableArray arrayWithObject:self];
    NSResponder *nextResponder = self.nextResponder;
    while (nextResponder != nil) {
        [responders addObject:nextResponder];
        nextResponder = nextResponder.nextResponder;
    }
    return responders;
}

- (NSString *)responderChainDescription;
{
    NSMutableString *desc = [[self shortDescription] mutableCopy];
    for (NSResponder *responder in [self.responderChain subarrayWithRange:NSMakeRange(1, self.responderChain.count - 1)]) {
        [desc appendFormat:@"\n%@", [responder shortDescription]];
    }
    return desc;
}

- (NSResponder *)nextResponderOfClass:(Class)cls;
{
    NSResponder *responder = self;
    while (responder != nil && ![responder isKindOfClass:cls])
        responder = responder.nextResponder;
    return responder;
}

@end
