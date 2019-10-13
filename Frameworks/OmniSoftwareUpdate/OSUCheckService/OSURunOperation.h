// Copyright 2001-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

@class OSURunOperationParameters;
@protocol OSULookupCredential;

#if OSU_FULL
#import <OmniSoftwareUpdate/OSUReportKeys.h>
#elif defined(OMNI_BUILDING_FRAMEWORK_OR_BUNDLE)
#import <OmniSystemInfo/OSUReportKeys.h>
#else
#import "OSUReportKeys.h" // Non-framework import intentional. Building the OSUCheckService; hopefully avoids a dependency cycle in Xcode 10.
#endif

typedef void (^OSURunOperationCompletionHandler)(NSDictionary *result, NSError *error);
extern void OSURunOperation(OSURunOperationParameters *params, NSDictionary *runtimeStats, NSDictionary *probes, id <OSULookupCredential> lookupCredential, OSURunOperationCompletionHandler completionHandler);


// A local error domain for the check operation itself. In particular, there are no localized descriptions or suggestions here. The caller to OSURunOperation() should add these if it cares.
#define OSUCheckServiceErrorDomain @"com.omnigroup.OmniSoftwareUpdate.OSUCheckService"

enum {
    OSUCheckServiceNoError, // Zero means no error
    
    OSUCheckServiceServerError,
    OSUCheckServiceExceptionRaisedError,
};
