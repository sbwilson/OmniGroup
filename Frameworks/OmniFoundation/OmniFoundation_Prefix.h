// Copyright 2003-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

// The '-H' compiler flag is good for figuring out this list.
#import <CoreFoundation/CoreFoundation.h>
#import <unistd.h>
#import <pthread.h>

#ifdef __OBJC__
    // <Foundation/NSAppleEventDescriptor.h> ends up importing *everything* under the sun, up to and including QuickdrawText.h
    //#import <Foundation/Foundation.h>
    #import <Foundation/FoundationErrors.h>
    #import <Foundation/NSArray.h>
    #import <Foundation/NSByteOrder.h>
    #import <Foundation/NSCalendar.h>
    #import <Foundation/NSCharacterSet.h>

    #import <Foundation/NSData.h>
    #import <Foundation/NSDate.h>
    #import <Foundation/NSDictionary.h>
    #import <Foundation/NSError.h>
    #import <Foundation/NSExpression.h>
    #import <Foundation/NSFileManager.h>
    #import <Foundation/NSIndexSet.h>
    #import <Foundation/NSInvocation.h>
    #import <Foundation/NSKeyValueCoding.h>
    #import <Foundation/NSKeyValueObserving.h>
    #import <Foundation/NSLocale.h>
    #import <Foundation/NSLock.h>
    #import <Foundation/NSMethodSignature.h>
    #import <Foundation/NSNotification.h>
    #import <Foundation/NSNull.h>
    #import <Foundation/NSPathUtilities.h>
    #import <Foundation/NSPredicate.h>
    #import <Foundation/NSProcessInfo.h>
    #import <Foundation/NSRunLoop.h>
    #import <Foundation/NSScanner.h>
    #import <Foundation/NSSet.h>
    #import <Foundation/NSSortDescriptor.h>
    #import <Foundation/NSTimeZone.h>
    #import <Foundation/NSThread.h>
    #import <Foundation/NSURL.h>
    #import <Foundation/NSUserDefaults.h>

    #import <OmniBase/OmniBase.h>
    #import <OmniBase/system.h>
        
    // Finally, pick up some very common used but infrequently changed headers from OmniFoundation itself
    #import <OmniFoundation/OFByte.h>
    #import <OmniFoundation/OFNull.h>
    #import <OmniFoundation/OFObject.h>
    #import <OmniFoundation/OFStringScanner.h>
    #import <OmniFoundation/OFUtilities.h>
    #import <OmniFoundation/NSArray-OFExtensions.h>
    #import <OmniFoundation/NSObject-OFExtensions.h>
    #import <OmniFoundation/NSString-OFSimpleMatching.h>
    #if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
        #import <OmniFoundation/OFMessageQueue.h>
        #import <OmniFoundation/OFSimpleLock.h>
        #import <OmniFoundation/OFScheduler.h>
        #import <OmniFoundation/OFScheduledEvent.h>
        #import <OmniFoundation/NSBundle-OFExtensions.h>
        #import <OmniFoundation/NSString-OFExtensions.h>
        #import <OmniFoundation/NSThread-OFExtensions.h>
    #endif

    #if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
        #import <Foundation/NSClassDescription.h>
    #endif


#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
// +[UIApplication sharedApplication] is not available in application extensions. This works around that for APIs in this framework, but those APIs should not be called w/in app extensions (and should be marked with NS_EXTENSION_UNAVAILABLE_IOS("message...") like +sharedApplication is).
@class UIApplication;
UIApplication *OFSharedApplication(void) OB_HIDDEN;
#endif

#endif
