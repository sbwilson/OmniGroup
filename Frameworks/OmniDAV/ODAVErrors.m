// Copyright 2008-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniDAV/ODAVErrors.h>

RCS_ID("$Id$");

NSString * const ODAVErrorDomain = @"com.omnigroup.frameworks.OmniDAV.ErrorDomain";

NSString * const ODAVHTTPErrorDomain = @"com.omnigroup.frameworks.OmniDAV.DAVHTTP.ErrorDomain";
NSString * const ODAVHTTPErrorDataKey = @"errorData";
NSString * const ODAVHTTPErrorDataContentTypeKey = @"errorDataContentType";
NSString * const ODAVHTTPErrorStringKey = @"errorString";

// using the same values as those found in NSURLErrorFailingURLStringErrorKey and NSURLErrorFailingURLErrorKey
NSString * const ODAVURLErrorFailingURLErrorKey = @"NSErrorFailingURLKey";
NSString * const ODAVURLErrorFailingURLStringErrorKey = @"NSErrorFailingURLStringKey";

BOOL ODAVShouldOfferToReportError(NSError *error)
{
    if (error == nil)
        return NO; // There isn't an error, so don't report one

    if ([error causedByUnreachableHost])
        return NO; // Unreachable hosts cannot be solved by the app

    NSError *httpError = [error underlyingErrorWithDomain:ODAVHTTPErrorDomain];
    if (httpError != nil) {
        NSUInteger httpErrorCode = [httpError code];
        if (httpErrorCode >= 400 && httpErrorCode < 500)
            return NO; // Authorization issues cannot be resolved by the app
        if (httpErrorCode == ODAV_HTTP_INSUFFICIENT_STORAGE)
            return NO; // Storage space issues cannot be resolved by the app
        if (httpErrorCode == ODAV_HTTP_SERVICE_UNAVAILABLE && ![[[[httpError userInfo] objectForKey:ODAVURLErrorFailingURLErrorKey] host] containsString:@"omnigroup.com"])
            return NO; // Service unavailable issue for some server that isn't ours
    }

    if ([error hasUnderlyingErrorDomain:NSPOSIXErrorDomain code:ENOSPC]) {
        // Local filesystem is out of space.
        return NO;
    }
    
    return YES; // Let's report everything else
}

@implementation NSError (ODAVExtensions)

+ (NSError *)certificateTrustErrorForChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    // This error has no localized strings since it is intended to be caught and cause localized UI to be presented to the user to evaluate trust and possibly restart the operation.
    __autoreleasing NSError *error;
    ODAVErrorWithInfo(&error, ODAVCertificateNotTrusted, @"Untrusted certificate", @"Present UI to let the user pick", ODAVCertificateTrustChallengeErrorKey, challenge, nil);
    return error;
}

- (BOOL)causedByPermissionFailure;
{
    if ([self hasUnderlyingErrorDomain:ODAVHTTPErrorDomain code:ODAV_HTTP_UNAUTHORIZED])
        return YES;
    if ([self hasUnderlyingErrorDomain:ODAVErrorDomain code:ODAVCertificateNotTrusted])
        return YES;
    
    return NO;
}

@end
