// Copyright 1998-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFQueueProcessor.h>

@class NSPort, NSPortMessage, NSArray;

#import <OmniFoundation/OFMessageQueueDelegateProtocol.h>

@interface OFRunLoopQueueProcessor : OFQueueProcessor <OFMessageQueueDelegate>
{
    NSPort *notificationPort;
    NSPortMessage *portMessage;
    unsigned int disableCount;
}

+ (NSArray *)mainThreadRunLoopModes;

+ (OFRunLoopQueueProcessor *)mainThreadProcessor;
+ (void)disableMainThreadQueueProcessing;
+ (void)reenableMainThreadQueueProcessing;

- (id)initForQueue:(OFMessageQueue *)aQueue;
- (void)runFromCurrentRunLoopInModes:(NSArray *)modes;
- (void)enable;
- (void)disable;

@end
