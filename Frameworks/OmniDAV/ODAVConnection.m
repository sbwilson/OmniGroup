// Copyright 2008-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniDAV/ODAVConnection.h>

#import <OmniDAV/ODAVErrors.h>
#import <OmniDAV/ODAVFileInfo.h>
#import <OmniFoundation/NSString-OFConversion.h>
#import <OmniFoundation/NSString-OFURLEncoding.h>
#import <OmniFoundation/NSURL-OFExtensions.h>
#import <OmniFoundation/OFCredentials.h>
#import <OmniFoundation/OFPreference.h>
#import <OmniFoundation/OFVersionNumber.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLString.h>
#import <OmniBase/OmniBase.h>

#import "ODAVOperation-Internal.h"
#import "ODAVConnection-Subclass.h"

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniFoundation/NSProcessInfo-OFExtensions.h>
#import <OmniFoundation/OFUtilities.h>
#endif
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#import <UIKit/UIDevice.h>
#endif

#import <sys/sysctl.h>

RCS_ID("$Id$")

OFDeclareDebugLogLevel(ODAVConnectionDebug);
OFDeclareDebugLogLevel(ODAVConnectionTaskDebug)

#define COMPLETE_AND_RETURN(...) do { \
    if (completionHandler) \
        completionHandler(__VA_ARGS__); \
    return; \
} while(0)

@implementation ODAVMultipleFileInfoResult
@end
@implementation ODAVSingleFileInfoResult
@end
@implementation ODAVURLResult
@end
@implementation ODAVURLAndDataResult
@end

@implementation ODAVConnectionConfiguration

#if TARGET_IPHONE_SIMULATOR
    #define DEFAULT_HARDWARE_MODEL @"iPhone Simulator"
#elif TARGET_OS_IPHONE
    #define DEFAULT_HARDWARE_MODEL @"iPhone"
#else
    #define DEFAULT_HARDWARE_MODEL @"Mac"
#endif

static NSString *ODAVHardwareModel(void)
{
    int name[] = {CTL_HW, HW_MODEL};
    const int nameCount = sizeof(name) / sizeof(*name);
    size_t bufSize = 0;
    
    // Passing a null pointer just says we want to get the size out
    if (sysctl(name, nameCount, NULL, &bufSize, NULL, 0) < 0) {
        perror("sysctl");
        return DEFAULT_HARDWARE_MODEL;
    }
    
    char *value = calloc(1, bufSize + 1);
    
    if (sysctl(name, nameCount, value, &bufSize, NULL, 0) < 0) {
        // Not expecting any errors now!
        free(value);
        perror("sysctl");
        return DEFAULT_HARDWARE_MODEL;
    }
    
    return CFBridgingRelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, value, kCFStringEncodingUTF8, kCFAllocatorMalloc));
}

static NSString *ClientComputerName(void)
{
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    return OFHostName();
#else
    return [[UIDevice currentDevice] name];
#endif
}

static NSString *StandardUserAgentString;

+ (void)initialize;
{
    OBINITIALIZE;
    
    StandardUserAgentString = [self userAgentStringByAddingComponents:nil];
}

+ (NSString *)userAgentStringByAddingComponents:(NSArray *)components;
{
    NSString *osVersionString = [[OFVersionNumber userVisibleOperatingSystemVersionNumber] originalVersionString];
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    
    NSString *appName = [bundleInfo objectForKey:@"ODAVUserAgentBasename"];
    if ([NSString isEmptyString:appName])
        appName = [bundleInfo objectForKey:(NSString *)kCFBundleNameKey]; // use bundle name

    if ([NSString isEmptyString:appName])
        appName = [[NSProcessInfo processInfo] processName]; // command line tool?

    NSString *appInfo = appName;
    NSString *appVersionString = [bundleInfo objectForKey:(NSString *)kCFBundleVersionKey];
    if (![NSString isEmptyString:appVersionString]) {
        NSString *marketingVersionString = [bundleInfo objectForKey:@"CFBundleShortVersionString"];
        if (![NSString isEmptyString:marketingVersionString]) {
            marketingVersionString = [marketingVersionString stringByReplacingOccurrencesOfString:@" " withString:@"-"];
            appVersionString = [appVersionString stringByAppendingFormat:@"/v%@", marketingVersionString];
        }
        
        appInfo = [appInfo stringByAppendingFormat:@"/%@", appVersionString];
    }
    
    NSString *hardwareModel = [NSString encodeURLString:ODAVHardwareModel() asQuery:NO leaveSlashes:YES leaveColons:YES];
    NSString *clientName = [NSString encodeURLString:ClientComputerName() asQuery:NO leaveSlashes:YES leaveColons:YES];
    
    NSString *extraComponents;
    if ([components count] > 0) {
        extraComponents = [NSString stringWithFormat:@" %@ ", [components componentsJoinedByString:@" "]];
    } else {
        extraComponents = @" ";
    }
    
    return [[NSString alloc] initWithFormat:@"%@%@Darwin/%@ (%@) (%@)", appInfo, extraComponents, osVersionString, hardwareModel, clientName];
}

- init;
{
    if (!(self = [super init]))
        return nil;
    
    _userAgent = [StandardUserAgentString copy];
    
    return self;
}

@end

@interface ODAVConnection (Subclass) <ODAVConnectionSubclass>
@end

@implementation ODAVConnection
{
    NSArray *_redirects;
    NSURL *_redirectedBaseURL;
}

+ (void)initialize;
{
    OBINITIALIZE;
    
#if defined(OMNI_ASSERTIONS_ON) && (!defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE)
    if ([[NSProcessInfo processInfo] isSandboxed]) {
        // Sandboxed Mac applications cannot talk to the network by default. Give a better hint about why stuff is failing than the default (NSPOSIXErrorDomain+EPERM).
        
        NSDictionary *entitlements = [[NSProcessInfo processInfo] codeSigningEntitlements];
        OBASSERT([entitlements[@"com.apple.security.network.client"] boolValue]);
    }
#endif
}

- init;
{
    OBRejectUnusedImplementation(self, _cmd);
}

- initWithSessionConfiguration:(ODAVConnectionConfiguration *)configuration baseURL:(NSURL *)baseURL;
{
    OBPRECONDITION(baseURL);
    
    if ([self class] == [ODAVConnection class]) {
        NSString *className = [[OFPreference preferenceForKey:@"ODAVConnectionClass"] stringValue];
        OBASSERT(![NSString isEmptyString:className]);
        
        Class cls = NSClassFromString(className);
        assert(OBClassIsSubclassOfClass(cls, [ODAVConnection class]));
        assert(cls != [ODAVConnection class]);
        assert([cls conformsToProtocol:@protocol(ODAVConnectionSubclass)]);
        
        return [[cls alloc] initWithSessionConfiguration:configuration baseURL:baseURL];
    }
    
    if (!(self = [super init]))
        return nil;

    if (!configuration)
        configuration = [ODAVConnectionConfiguration new];
    
    _configuration = configuration;
    _originalBaseURL = [baseURL copy];

    return self;
}

- (NSURL *)baseURL;
{
    if (_redirectedBaseURL)
        return _redirectedBaseURL;
    return _originalBaseURL;
}

- (void)updateBaseURLWithRedirects:(NSArray *)redirects;
{
    if (_redirects) {
        _redirects = [_redirects arrayByAddingObjectsFromArray:redirects];
    } else {
        _redirects = [redirects copy];
    }
    
    // We could maybe keep the previous redirected URL if we had one, but presumably that led to getting another redirection.
    _redirectedBaseURL = [self suggestRedirectedURLForURL:self.baseURL];
}

- (NSURL *)suggestRedirectedURLForURL:(NSURL *)url;
{
    NSURL *redirectedURL = [ODAVRedirect suggestAlternateURLForURL:url withRedirects:_redirects];
    if (redirectedURL)
        return redirectedURL;
    return url;
}

- (void)deleteURL:(NSURL *)url withETag:(NSString *)ETag completionHandler:(ODAVConnectionBasicCompletionHandler)completionHandler;
{
    DEBUG_DAV(1, @"operation: DELETE %@", url);
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"DELETE"];
    
    if (![NSString isEmptyString:ETag])
        [request setValue:ETag forHTTPHeaderField:@"If-Match"];
    
    completionHandler = [completionHandler copy];
    
    [self _runRequestExpectingEmptyResultData:request completionHandler:^(ODAVURLResult *result, NSError *errorOrNil) {
        if (!result) {
            if ([errorOrNil hasUnderlyingErrorDomain:ODAVHTTPErrorDomain code:ODAV_HTTP_NOT_FOUND]) {
                NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"No such file \"%@\".", @"OmniDAV", OMNI_BUNDLE, @"error reason"), [url absoluteString]];
                __autoreleasing NSError *error = errorOrNil;
                ODAVError(&error, ODAVNoSuchFile, NSLocalizedStringFromTableInBundle(@"Unable to delete file.", @"OmniDAV", OMNI_BUNDLE, @"error description"), reason);
                errorOrNil = error;
            }
        }
        COMPLETE_AND_RETURN(errorOrNil);
    }];
}

- (void)makeCollectionAtURL:(NSURL *)url completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    DEBUG_DAV(1, @"operation: MKCOL %@", url);
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"MKCOL"];
    
    completionHandler = [completionHandler copy];

    [self _runRequestExpectingEmptyResultData:request completionHandler:^(ODAVURLResult *result, NSError *errorOrNil) {
        COMPLETE_AND_RETURN(result, errorOrNil);
    }];
}

- (void)makeCollectionAtURLIfMissing:(NSURL *)requestedDirectoryURL baseURL:(NSURL *)baseURL completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];

    // Assume it exists...
    [self fileInfoAtURL:requestedDirectoryURL ETag:nil completionHandler:^(ODAVSingleFileInfoResult *result, NSError *fileInfoError) {
        if (result) {
            ODAVFileInfo *directoryInfo = result.fileInfo;
            if (directoryInfo.exists && directoryInfo.isDirectory) { // If there is a flat file, fall through to the MKCOL to get a 409 Conflict filled in
                ODAVURLResult *urlResult = [ODAVURLResult new];
                urlResult.URL = directoryInfo.originalURL;
                urlResult.redirects = result.redirects;
                COMPLETE_AND_RETURN(urlResult, nil);
            }
        }
        
        if (result == nil && ([fileInfoError causedByUnreachableHost] || [fileInfoError causedByPermissionFailure])) {
            COMPLETE_AND_RETURN(nil, fileInfoError);  // If we're not connected to the Internet, then no other error is particularly relevant
        }
        
        if (OFURLEqualToURLIgnoringTrailingSlash(requestedDirectoryURL, baseURL)) {
            __autoreleasing NSError *baseError;
            ODAVErrorWithInfo(&baseError, ODAVCannotCreateDirectory,
                             @"Unable to create remote directory for container",
                             ([NSString stringWithFormat:@"Account base URL doesn't exist at %@", baseURL]), nil);
            COMPLETE_AND_RETURN(nil, baseError);
        }
        
        [self makeCollectionAtURLIfMissing:[requestedDirectoryURL URLByDeletingLastPathComponent] baseURL:baseURL completionHandler:^(ODAVURLResult *parentResult, NSError *errorOrNil) {
            if (!parentResult) {
                COMPLETE_AND_RETURN(nil, errorOrNil);
            }
            
            // Try to avoid extra redirects
            NSURL *attemptedCreateDirectoryURL = [parentResult.URL URLByAppendingPathComponent:[requestedDirectoryURL lastPathComponent] isDirectory:YES];
            
            [self makeCollectionAtURL:attemptedCreateDirectoryURL completionHandler:^(ODAVURLResult *createdDirectoryResult, NSError *makeCollectionError) {
                if (createdDirectoryResult) {
                    COMPLETE_AND_RETURN(createdDirectoryResult, nil);
                }
                    
                // Might have been racing against another creator.
                if (![makeCollectionError hasUnderlyingErrorDomain:ODAVHTTPErrorDomain code:ODAV_HTTP_METHOD_NOT_ALLOWED] &&
                    ![makeCollectionError hasUnderlyingErrorDomain:ODAVHTTPErrorDomain code:ODAV_HTTP_CONFLICT]) {
                    COMPLETE_AND_RETURN(nil, makeCollectionError);
                }
                
                // Looks like we were racing -- double-check and get the redirected final URL.
                [self fileInfoAtURL:requestedDirectoryURL ETag:nil completionHandler:^(ODAVSingleFileInfoResult *finalResult, NSError *finalError) {
                    ODAVURLResult *urlResult = [ODAVURLResult new];
                    urlResult.URL = finalResult.fileInfo.originalURL;
                    urlResult.redirects = finalResult.redirects;
                    COMPLETE_AND_RETURN(urlResult, finalError);
                }];
            }];
        }];
    }];
}

static NSString * const DAVNamespaceString = @"DAV:";

static NSString *ODAVDepthName(ODAVDepth depth)
{
    NSString *depthString = nil;
    switch (depth) {
        case ODAVDepthLocal: /* local; returns file */
            depthString = @"0";
            break;
        case ODAVDepthChildren: /* children; returns direct descendants */
            depthString = @"1";
            break;
        case ODAVDepthInfinite: /* all; deep, recursive descendants */
            depthString = @"infinity";
            break;
        default:
            OBASSERT_NOT_REACHED("Bad depth specified");
            depthString = @"0";
            break;
    }
    return depthString;
}

- (void)fileInfosAtURL:(NSURL *)url ETag:(NSString *)predicateETag depth:(ODAVDepth)depth completionHandler:(ODAVConnectionMultipleFileInfoCompletionHandler)completionHandler;
{
    OBPRECONDITION(url);
    
    NSString *depthName = ODAVDepthName(depth);

    DEBUG_DAV(1, @"operation: PROPFIND ETag:%@ depth=%@ %@", predicateETag, depthName, url);
    
    url = [url absoluteURL];
    
    // Build the propfind request.  Can do this dynamically but for now we have a static request...
    NSData *requestXML;
    {
        __autoreleasing NSError *error;
        OFXMLDocument *requestDocument = [[OFXMLDocument alloc] initWithRootElementName:@"propfind"
                                                                           namespaceURL:[NSURL URLWithString:DAVNamespaceString]
                                                                     whitespaceBehavior:[OFXMLWhitespaceBehavior ignoreWhitespaceBehavior]
                                                                         stringEncoding:kCFStringEncodingUTF8
                                                                                  error:&error];
        if (!requestDocument) {
            COMPLETE_AND_RETURN(nil, error);
        }
        
        //[[requestDocument topElement] setAttribute:@"xmlns" string:DAVNamespaceString];
        [requestDocument pushElement:@"prop"];
        {
            [requestDocument pushElement:@"resourcetype"];
            [requestDocument popElement];
            [requestDocument pushElement:@"getcontentlength"];
            [requestDocument popElement];
            [requestDocument pushElement:@"getlastmodified"];
            [requestDocument popElement];
            [requestDocument pushElement:@"getetag"];
            [requestDocument popElement];
        }
        [requestDocument popElement];
        
        requestXML = [requestDocument xmlData:&error];
        
        DEBUG_DAV(3, @"requestXML = %@", [NSString stringWithData:requestXML encoding:NSUTF8StringEncoding]);
        
        
        if (!requestXML)
            COMPLETE_AND_RETURN(nil, error);
        
        //NSData *requestXML = [@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<propfind xmlns=\"DAV:\"><prop>\n<resourcetype xmlns=\"DAV:\"/>\n</prop></propfind>" dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    {
        [request setHTTPMethod:@"PROPFIND"];
        [request setHTTPBody:requestXML];
        [request setValue:depthName forHTTPHeaderField:@"Depth"];
        
        if (![NSString isEmptyString:predicateETag])
            [request setValue:predicateETag forHTTPHeaderField:@"If-Match"];
        
        // Specify that we are sending XML
        [request setValue:@"text/xml; charset=\"utf-8\"" forHTTPHeaderField:@"Content-Type"];
        
        // ... and that we want XML back
        [request setValue:@"text/xml,application/xml" forHTTPHeaderField:@"Accept"];
    }
    
    completionHandler = [completionHandler copy];
    
    [self _runRequestExpectingDocument:request completionHandler:^(OFXMLDocument *doc, ODAVOperation *op, NSError *errorOrNil){
        DEBUG_DAV(2, @"PROPFIND doc = %@", doc);
        if (!doc) {
            OBASSERT(errorOrNil);
            COMPLETE_AND_RETURN(nil, errorOrNil);
        }
        
        ODAVMultipleFileInfoResult *result = [ODAVMultipleFileInfoResult new];
        
        // If we followed redirects while doing the PROPFIND, it's important to interpret the result URLs relative to the URL of the request we actually got them from, instead of from some earlier request which may have been to a different scheme/host/whatever.
        NSURL *resultsBaseURL = url;
        {
            NSArray *redirs = op.redirects;
            if ([redirs count]) {
                result.redirects = redirs;
                ODAVRedirect *lastRedirect = [redirs lastObject];
                resultsBaseURL = lastRedirect.to;
            }
        }
        
        NSMutableArray *fileInfos = [NSMutableArray array];
        
        // We'll get back a <multistatus> with multiple <response> elements, each having <href> and <propstat>
        OFXMLCursor *cursor = [doc cursor];
        if (![[cursor name] isEqualToString:@"multistatus"]) {
            __autoreleasing NSError *error;
            NSString *reason = [NSString stringWithFormat:@"Expected “multistatus” but found “%@” in PROPFIND result from %@.", cursor.name, [request shortDescription]];
            ODAVError(&error, ODAVOperationInvalidMultiStatusResponse, @"Expected “multistatus” element missing in PROPFIND result.", reason);
            COMPLETE_AND_RETURN(nil, error);
        }
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss 'GMT'"];   /* rfc 1123 */
        /* reference: http://developer.apple.com/library/ios/#qa/qa2010/qa1480.html */
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        
        // Date header
        {
            // We could avoid parsing the Date header unless it is requested, but for now I'd like to get assertion failures when a server doesn't return it.
            NSString *dateHeader = [op valueForResponseHeader:@"Date"];
            OBASSERT(![NSString isEmptyString:dateHeader]);
            
            result.serverDate = [dateFormatter dateFromString:dateHeader];
            OBASSERT(result.serverDate);
        }
        
        while ([cursor openNextChildElementNamed:@"response"]) {
            
            OBASSERT([[cursor name] isEqualToString:@"response"]);
            {
                if (![cursor openNextChildElementNamed:@"href"]) {
                    OBRequestConcreteImplementation(self, _cmd);
                    break;
                }
                
                NSString *responsePath = OFCharacterDataFromElement([cursor currentElement]);
                [cursor closeElement]; // href
                //NSLog(@"responsePath = %@", responsePath);
                
                // There will one propstat element per status.  If there is a directory, for example, we'll get one for the resource type with status200 and one for the getcontentlength with status=404.
                // For files, there should be one propstat with both in the same <prop>.
                
                BOOL exists = NO;
                BOOL directory = NO;
                BOOL hasPropstat = NO;
                off_t size = 0;
                NSDate *dateModified = nil;
                NSString *ETag = nil;
                NSMutableArray *unexpectedPropstatElements = nil;
                
                while ([cursor openNextChildElementNamed:@"propstat"]) {
                    hasPropstat = YES;
                    
                    OFXMLElement *anElement;
                    while( (anElement = [cursor nextChild]) != nil ) {
                        NSString *childName = [anElement name];
                        if ([childName isEqualToString:@"prop"]) {
                            OFXMLElement *propElement;
                            if ([anElement firstChildAtPath:@"resourcetype/collection"])
                                directory = YES;
                            else if ( (propElement = [anElement firstChildNamed:@"getcontentlength"]) != nil ) {
                                NSString *sizeString = OFCharacterDataFromElement(propElement);
                                size = [sizeString unsignedLongLongValue];
                            }
                            
                            if ( (propElement = [anElement firstChildNamed:@"getlastmodified"]) != nil ) {
                                NSString *lastModified = OFCharacterDataFromElement(propElement);
                                dateModified = [dateFormatter dateFromString:lastModified];
                            }
                            
                            if ( (propElement = [anElement firstChildNamed:@"getetag"]) != nil ) {
                                ETag = OFCharacterDataFromElement(propElement);
                            }
                        } else if ([childName isEqualToString:@"status"]) {
                            NSString *statusLine = OFCharacterDataFromElement(anElement);
                            // statusLine ~ "HTTP/1.1 200 OK we rule"
                            NSRange l = [statusLine rangeOfString:@" "];
                            if (l.length > 0 && [[statusLine substringWithRange:(NSRange){NSMaxRange(l), 1}] isEqualToString:@"2"])
                                exists = YES;
                            
                            // If we get a 404, or other error, that doesn't mean this resource doesn't exist: it just means this property doesn't exist on this resource.
                            // But every resource should have either a resourcetype or getcontentlength property, which will be returned to us with a 2xx status.
                        } else {
#ifdef OMNI_ASSERTIONS_ON
                            // Always log the unexpected element if assertions are enabled.
                            NSLog(@"Unexpected propstat element: %@", [anElement name]);
#endif
                            // Collect the unexpected propstat elements for logging later, if necessary.
                            if (unexpectedPropstatElements == nil)
                                unexpectedPropstatElements = [NSMutableArray array];
                            
                            [unexpectedPropstatElements addObject:anElement];
                            
                        }
                    }
                    [cursor closeElement]; // propstat
                }
                
                if (!hasPropstat) {
                    NSLog(@"No propstat element found for path '%@' of propfind of %@", responsePath, url);
                    if ([unexpectedPropstatElements count] > 0)
                        NSLog(@"Unexpected propstat elements: %@", [unexpectedPropstatElements valueForKey:@"name"]);
                        
                    continue;
                }
                
                // We used to remove the trailing slash here to normalize, but now we do that closer to where we need it.
                // If we make a request for this URL later, we should use the URL exactly as the server gave it to us, slash or not.
                
                NSURL *fullURL = [NSURL URLWithString:responsePath relativeToURL:resultsBaseURL];
                if (fullURL == nil) {
                    // If a PROPFIND result's path comes back unencoded (as with Apache/2.2.26 + svn/1.8.10) then let's try encoding it.
                    fullURL = [NSURL URLWithString:[NSString encodeURLString:responsePath asQuery:NO leaveSlashes:YES leaveColons:YES] relativeToURL:resultsBaseURL];
                    if (fullURL == nil) {
                        __autoreleasing NSError *error;
                        NSString *reason = [NSString stringWithFormat:@"Unable to parse path “%@” in PROPFIND result from %@.", responsePath, [request shortDescription]];
                        ODAVError(&error, ODAVOperationInvalidPath, @"Invalid path in PROPFIND result", reason);
                        COMPLETE_AND_RETURN(nil, error);
                    }
                }
                
                ODAVFileInfo *info = [[ODAVFileInfo alloc] initWithOriginalURL:fullURL name:nil exists:exists directory:directory size:size lastModifiedDate:dateModified ETag:ETag];
                [fileInfos addObject:info];
            }
            [cursor closeElement]; // response
        }
        
        
        if (ODAVConnectionDebug > 0) {
            NSLog(@"  Found %ld files", [fileInfos count]);
            for (ODAVFileInfo *fileInfo in fileInfos)
                NSLog(@"    %@", fileInfo.originalURL);
        }
        result.fileInfos = fileInfos;
        
        COMPLETE_AND_RETURN(result, nil);
    }];
}

- (void)fileInfoAtURL:(NSURL *)url ETag:(NSString *)predicateETag completionHandler:(void (^)(ODAVSingleFileInfoResult *result, NSError *error))completionHandler;
{
    OBPRECONDITION(url);

    completionHandler = [completionHandler copy];
    
    [self fileInfosAtURL:url ETag:predicateETag depth:ODAVDepthLocal completionHandler:^(ODAVMultipleFileInfoResult *result, NSError *errorOrNil) {
        if (!result) {
            if ([[errorOrNil domain] isEqualToString:ODAVHTTPErrorDomain]) {
                NSInteger code = [errorOrNil code];
                
                // A 406 Not Acceptable means that there is something possibly similar to what we asked for with a different content type than we specified in our Accepts header.
                // This is goofy since we didn't ASK for the resource contents, but its properties and our "text/xml" Accepts entry was for the format of the returned properties.
                // Apache does this on sync.omnigroup.com (at least with the current configuration as of this writing) if we do a PROPFIND for "Foo" and there is a "Foo.txt".
                if (code == ODAV_HTTP_NOT_FOUND || code == ODAV_HTTP_NOT_ACCEPTABLE) {
                    // The resource was legitimately not found.
                    ODAVSingleFileInfoResult *singleResult = [ODAVSingleFileInfoResult new];
                    singleResult.fileInfo = [[ODAVFileInfo alloc] initWithOriginalURL:url name:nil exists:NO directory:NO size:0 lastModifiedDate:nil];
                    singleResult.redirects = result.redirects;
                    singleResult.serverDate = result.serverDate;
                    COMPLETE_AND_RETURN(singleResult, nil);
                }
            }
            
            // Some other error; pass it up
            COMPLETE_AND_RETURN(nil, errorOrNil);
        }
        
        NSArray *fileInfos = result.fileInfos;
        if ([fileInfos count] == 0) {
            // This really doesn't make sense. But translate it to an error rather than raising an exception below.
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:[NSDictionary dictionaryWithObject:url forKey:ODAVURLErrorFailingURLErrorKey]];
            COMPLETE_AND_RETURN(nil, error);
        }
        
        OBASSERT([fileInfos count] == 1); // We asked for Depth=0, so we should only get one result.
        ODAVFileInfo *fileInfo = [fileInfos objectAtIndex:0];
#ifdef OMNI_ASSERTIONS_ON
        {
            NSURL *foundURL = [fileInfo originalURL];
            if (!OFURLEqualsURL(url, foundURL)) {
                // The URLs will legitimately not be equal if we got a redirect -- don't spuriously warn in that case.
                BOOL foundRedirect = NO;
                for (ODAVRedirect *redirect in result.redirects) {
                    if (OFURLEqualsURL(url, redirect.from) && OFURLEqualsURL(foundURL, redirect.to)) {
                        foundRedirect = YES;
                        break;
                    }
                }
                if (!foundRedirect) {
                    OBASSERT_NOT_REACHED("Any issues with encoding normalization or whatnot?");
                    NSLog(@"url: %@", url);
                    NSLog(@"foundURL: %@", foundURL);
                }
            }
        }
#endif
        
        ODAVSingleFileInfoResult *singleResult = [ODAVSingleFileInfoResult new];
        singleResult.fileInfo = fileInfo;
        singleResult.redirects = result.redirects;
        singleResult.serverDate = result.serverDate;
        COMPLETE_AND_RETURN(singleResult, nil);
    }];
}

// Removes the directory URL itself and does some more error checking for non-directory cases.
- (void)directoryContentsAtURL:(NSURL *)url withETag:(NSString *)ETag completionHandler:(ODAVConnectionMultipleFileInfoCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    [self fileInfosAtURL:url ETag:ETag depth:ODAVDepthChildren completionHandler:^(ODAVMultipleFileInfoResult *properties, NSError *errorOrNil) {
        if (!properties) {
            if ([errorOrNil hasUnderlyingErrorDomain:ODAVHTTPErrorDomain code:ODAV_HTTP_NOT_FOUND]) {
                // The resource was legitimately not found.
                NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"No document exists at \"%@\".", @"OmniDAV", OMNI_BUNDLE, @"error reason - listing contents of a nonexistent directory"), url];
                NSString *description = NSLocalizedStringFromTableInBundle(@"Unable to read document.", @"OmniDAV", OMNI_BUNDLE, @"error description");
                __autoreleasing NSError *error = errorOrNil;
                ODAVError(&error, ODAVNoSuchDirectory, description, reason);
                COMPLETE_AND_RETURN(nil, error);
            }
            COMPLETE_AND_RETURN(nil, errorOrNil);
        }
        
        ODAVRedirect *lastRedirect = [properties.redirects lastObject];
        NSURL *expectedDirectoryURL = lastRedirect.to;
        if (!expectedDirectoryURL)
            expectedDirectoryURL = url;
        
        NSArray *fileInfos = properties.fileInfos;
        if ([fileInfos count] == 1) {
            // If we only got info about one resource, and it's not a collection, then we must have done a PROPFIND on a non-collection
            ODAVFileInfo *info = [fileInfos objectAtIndex:0];
            if (!info.isDirectory) {
                // Is there a better error code for this? Do any of our callers distinguish this case from general failure?
                NSError *returnError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTDIR userInfo:[NSDictionary dictionaryWithObject:url forKey:ODAVURLErrorFailingURLStringErrorKey]];
                COMPLETE_AND_RETURN(nil, returnError);
            }
            // Otherwise, it's just that the collection is empty.
        }
        
        NSMutableArray *contents = [NSMutableArray array];
        
        ODAVFileInfo *containerInfo = nil;
        
        for (ODAVFileInfo *info in fileInfos) {
            if (!info.exists) {
                OBASSERT_NOT_REACHED("Why would we list something that doesn't exist?"); // Maybe if a <prop> element comes back 404 or with some other error?  We aren't even looking at the per entry status yet.
                continue;
            }
            
            // The directory itself will be in the property results.
            // We don't necessarily know what its name will be, though.
            if (!containerInfo && OFURLEqualsURL(info.originalURL, expectedDirectoryURL)) {
                containerInfo = info;
                // Don't return the container itself in the results list.
                continue;
            }
            
            if ([info.name hasPrefix:@"._"]) {
                // Ignore split resource fork files; these presumably happen when moving between filesystems.
                continue;
            }
            
            [contents addObject:info];
        }
        
        NSMutableArray *redirections = [NSMutableArray array];
        
        if (!containerInfo && [contents count]) {
            // Somewhat unexpected: we never found the fileinfo corresponding to the container itself.
            // My reading of RFC4918 [5.2] is that all of the contained items MUST have URLs consisting of the container's URL plus one path component.
            // (The resources may be available at other URLs as well, but I *think* those URLs will not be returned in our multistatus.)
            // If so, and ignoring the possibility of resources with zero-length names, the container will be the item with the shortest path.
            
            NSUInteger shortestIndex = 0;
            NSUInteger shortestLength = [[[contents[shortestIndex] originalURL] path] length];
            for (NSUInteger infoIndex = 1; infoIndex < [contents count]; infoIndex ++) {
                ODAVFileInfo *contender = contents[infoIndex];
                NSUInteger contenderLength = [[contender.originalURL path] length];
                if (contenderLength < shortestLength) {
                    shortestIndex = infoIndex;
                    shortestLength = contenderLength;
                }
            }
            
            containerInfo = contents[shortestIndex];
            
            if (redirections) {
                DEBUG_DAV(1, @"PROPFIND rewrite <%@> -> <%@>", expectedDirectoryURL, containerInfo.originalURL);
                
                ODAVAddRedirectEntry(redirections, kODAVRedirectPROPFIND, expectedDirectoryURL, containerInfo.originalURL, nil /* PROPFIND is not cacheable */ );
            }
            
            [contents removeObjectAtIndex:shortestIndex];
        }
        
        // containerInfo is still in fileInfos, so it won't have been deallocated yet
        OBASSERT(containerInfo.isDirectory);
        
        [redirections addObjectsFromArray:properties.redirects];
        properties.redirects = redirections;
        properties.fileInfos = contents;
        
        COMPLETE_AND_RETURN(properties, nil);
    }];
}

- (void)getContentsOfURL:(NSURL *)url ETag:(NSString *)ETag completionHandler:(ODAVConnectionOperationCompletionHandler)completionHandler;
{
    DEBUG_DAV(1, @"operation: GET %@", url);
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    
    [request setHTTPMethod:@"GET"]; // really the default, but just for conformity with the others...
    
    if (![NSString isEmptyString:ETag])
        [request setValue:ETag forHTTPHeaderField:@"If-Match"];
    
    [self _runRequest:request completionHandler:completionHandler];
}

- (ODAVOperation *)asynchronousGetContentsOfURL:(NSURL *)url; // Returns an unstarted operation
{
    DEBUG_DAV(1, @"operation: GET %@", url);
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"GET"]; // really the default, but just for conformity with the others...
    
    // NOTE: If the caller never starts the task, we'll end up leaking it in our task->operation table
    ODAVOperation *operation = [self _makeOperationForRequest:request];
    
    // DO NOT launch the operation here. The caller should do this so it can assign it to an ivar or otherwise store it before it has to expect any callbacks.
    
    return operation;
}

- (void)postData:(NSData *)data toURL:(NSURL *)url completionHandler:(ODAVConnectionURLAndDataCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:data];
    
    [self _runRequestExpectingResultData:request completionHandler:^(ODAVURLAndDataResult *result, NSError *errorOrNil) {
        COMPLETE_AND_RETURN(result, errorOrNil);
    }];
}

// PUT is not atomic, so if you want an atomic replace, you should write to a temporary URL and the MOVE it into place.
- (void)putData:(NSData *)data toURL:(NSURL *)url completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:data];
    
    [self _runRequestExpectingEmptyResultData:request completionHandler:^(ODAVURLResult *result, NSError *errorOrNil) {
        COMPLETE_AND_RETURN(result, errorOrNil);
    }];
}

- (ODAVOperation *)asynchronousPutData:(NSData *)data toURL:(NSURL *)url;
{
    DEBUG_DAV(1, @"operation: PUT %@ (data of %ld bytes)", url, [data length]);
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:data];
    
    // NOTE: If the caller never starts the task, we'll end up leaking it in our task->operation table
    ODAVOperation *operation = [self _makeOperationForRequest:request];
    
    // DO NOT launch the operation here. The caller should do this so it can assign it to an ivar or otherwise store it before it has to expect any callbacks.
    
    return operation;
}

typedef void (^OFSAddPredicate)(NSMutableURLRequest *request, NSURL *sourceURL, NSURL *destURL);

// COPY supports Depth=0 as well, but we haven't neede that yet.
- (void)_moveOrCopy:(NSString *)method sourceURL:(NSURL *)sourceURL toURL:(NSURL *)destURL overwrite:(BOOL)overwrite predicate:(OFSAddPredicate)predicate completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];

    DEBUG_DAV(1, @"operation: %@ %@ to %@, overwrite:%d", method, sourceURL, destURL, overwrite);
    
    NSMutableURLRequest *request = [self _requestForURL:sourceURL];
    [request setHTTPMethod:method];
    
    // .Mac WebDAV accepts the just path the portion as the Destination, but normal OSXS doesn't.  It'll give a 400 Bad Request if we try that.  So, we send the full URL as the Destination.
    NSString *destination = [destURL absoluteString];
    [request setValue:destination forHTTPHeaderField:@"Destination"];
    [request setValue:overwrite ? @"T" : @"F" forHTTPHeaderField:@"Overwrite"];
    
    if (predicate)
        predicate(request, sourceURL, destURL);
    
    [self _runRequestExpectingEmptyResultData:request completionHandler:^(ODAVURLResult *result, NSError *errorOrNil) {
        if (result) {
            COMPLETE_AND_RETURN(result, nil);
        }
    
        // Work around for <bug://bugs/48303> (Some https servers incorrectly return Bad Gateway (502) for a MOVE to a destination with an https URL [bingodisk])
        if ([errorOrNil hasUnderlyingErrorDomain:ODAVHTTPErrorDomain code:ODAV_HTTP_BAD_GATEWAY] && [destination hasPrefix:@"https"]) {
            // Try again with an http destination instead
            NSString *updatedDestination = [@"http" stringByAppendingString:[destination stringByRemovingPrefix:@"https"]];
            [request setValue:updatedDestination forHTTPHeaderField:@"Destination"];
            
            if (predicate) {
                NSURL *updatedDestURL = [NSURL URLWithString:updatedDestination];
                predicate(request, sourceURL, updatedDestURL);
            }
            
            [self _runRequestExpectingEmptyResultData:request completionHandler:^(ODAVURLResult *workaroundResult, NSError *workaroundErrorOrNil){
                if (workaroundResult)
                    COMPLETE_AND_RETURN(workaroundResult, nil);
                else
                    COMPLETE_AND_RETURN(nil, workaroundErrorOrNil);
            }];
        } else {
            COMPLETE_AND_RETURN(nil, errorOrNil);
        }
    }];
}

static void OFSAddIfPredicateForURLAndETag(NSMutableURLRequest *request, NSURL *url, NSString *ETag)
{
    if (![NSString isEmptyString:ETag]) {
        NSString *ifValue = [NSString stringWithFormat:@"<%@> ([%@])", [url absoluteString], ETag];
        [request setValue:ifValue forHTTPHeaderField:@"If"];
    }
}
static void OFSAddIfPredicateForURLAndLockToken(NSMutableURLRequest *request, NSURL *url, NSString *lockToken)
{
    if (![NSString isEmptyString:lockToken]) {
        NSString *ifValue = [NSString stringWithFormat:@"<%@> (%@)", [url absoluteString], lockToken];
        [request setValue:ifValue forHTTPHeaderField:@"If"];
    }
}

- (void)copyURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceETag:(NSString *)ETag overwrite:(BOOL)overwrite completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    // TODO: COPY can return ODAV_HTTP_MULTI_STATUS if there is an error copying a sub-resource
    [self _moveOrCopy:@"COPY" sourceURL:sourceURL toURL:destURL overwrite:overwrite predicate:^(NSMutableURLRequest *request, NSURL *copySourceURL, NSURL *copyDestURL) {
        OFSAddIfPredicateForURLAndETag(request, copySourceURL, ETag);
    } completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:YES predicate:nil completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceETag:(NSString *)ETag overwrite:(BOOL)overwrite completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:overwrite predicate:^(NSMutableURLRequest *request, NSURL *moveSourceURL, NSURL *moveDestURL) {
        OFSAddIfPredicateForURLAndETag(request, moveSourceURL, ETag);
    } completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withDestinationETag:(NSString *)ETag overwrite:(BOOL)overwrite completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:overwrite predicate:^(NSMutableURLRequest *request, NSURL *moveSourceURL, NSURL *moveDestURL) {
        OFSAddIfPredicateForURLAndETag(request, moveDestURL, ETag);
    } completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceLock:(NSString *)lock overwrite:(BOOL)overwrite completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:overwrite predicate:^(NSMutableURLRequest *request, NSURL *moveSourceURL, NSURL *moveDestURL) {
        // The untagged list approach is supposed to use the source URI, but Apache 2.4.3 screws up and returns ODAV_HTTP_PRECONDITION_FAILED in that case.
        // If we explicitly give the source URL, it works. It may be that Apache is checking based on the path? Anyway, it is no pain to be specific about which resource we think has the lock.
        OFSAddIfPredicateForURLAndLockToken(request, moveSourceURL, lock);
    } completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withDestinationLock:(NSString *)lock overwrite:(BOOL)overwrite completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:overwrite predicate:^(NSMutableURLRequest *request, NSURL *moveSourceURL, NSURL *moveDestURL) {
        OFSAddIfPredicateForURLAndLockToken(request, moveDestURL, lock);
    } completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toMissingURL:(NSURL *)destURL completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    // No predicate needed. The default for Overwrite: F is to return a precondition failure if the destination exists
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:NO predicate:nil completionHandler:completionHandler];
}

- (void)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL ifURLExists:(NSURL *)tagURL completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    [self _moveOrCopy:@"MOVE" sourceURL:sourceURL toURL:destURL overwrite:NO predicate:^(NSMutableURLRequest *request, NSURL *moveSourceURL, NSURL *moveDestURL) {
        // If-Match applies to teh URL in the command, but we want to be able to check an arbitrary header (not even the one in the Destination header). We can write this as a tagged condition list with the "If" header.
        NSString *ifValue = [NSString stringWithFormat:@"<%@> ([*])", [tagURL absoluteString]];
        [request setValue:ifValue forHTTPHeaderField:@"If"];
    } completionHandler:completionHandler];
}

- (void)lockURL:(NSURL *)url completionHandler:(ODAVConnectionStringCompletionHandler)completionHandler;
{
    DEBUG_DAV(1, @"DAV operation: LOCK %@", url);
    
    completionHandler = [completionHandler copy];
    
    NSData *requestXML;
    {
        __autoreleasing NSError *error;
        OFXMLDocument *requestDocument = [[OFXMLDocument alloc] initWithRootElementName:@"lockinfo"
                                                                           namespaceURL:[NSURL URLWithString:DAVNamespaceString]
                                                                     whitespaceBehavior:[OFXMLWhitespaceBehavior ignoreWhitespaceBehavior]
                                                                         stringEncoding:kCFStringEncodingUTF8
                                                                                  error:&error];
        if (!requestDocument)
            COMPLETE_AND_RETURN(nil, error);
        
        __weak OFXMLDocument *doc = requestDocument; // Avoid capture warnings inside the blocks
        
        //[[requestDocument topElement] setAttribute:@"xmlns" string:DAVNamespaceString];
        [requestDocument addElement:@"locktype" childBlock:^{
            [doc appendElement:@"write"];
        }];
        [requestDocument addElement:@"lockscope" childBlock:^{
            [doc appendElement:@"exclusive"];
        }];
        [requestDocument addElement:@"owner" childBlock:^{
            OBFinishPortingLater("Add actual href for owner");
            [doc appendElement:@"href" containingString:@"http://example.com"];
        }];
        
        requestXML = [requestDocument xmlData:&error];
        
        DEBUG_DAV(3, @"requestXML = %@", [NSString stringWithData:requestXML encoding:NSUTF8StringEncoding]);
        if (!requestXML)
            COMPLETE_AND_RETURN(nil, error);
    }
    
    NSMutableURLRequest *request;
    {
        request = [self _requestForURL:url];
        [request setHTTPMethod:@"LOCK"];
        [request setHTTPBody:requestXML];
        [request setValue:ODAVDepthName(ODAVDepthInfinite) forHTTPHeaderField:@"Depth"];
        
        // Specify that we are sending XML
        [request setValue:@"text/xml; charset=\"utf-8\"" forHTTPHeaderField:@"Content-Type"];
        
        // ... and that we want XML back
        [request setValue:@"text/xml,application/xml" forHTTPHeaderField:@"Accept"];
        
        // TODO: Add a Timeout header?
        // If we add refreshing of locks, the refresh request should have an empty body. Depth is ignored on refresh.
    }
    
    [self _runRequestExpectingDocument:request completionHandler:^(OFXMLDocument *doc, ODAVOperation *op, NSError *errorOrNil) {
        DEBUG_DAV(2, @"LOCK doc = %@", doc);
        
        if (!doc)
            COMPLETE_AND_RETURN(nil, errorOrNil);
        
        // Lock-Token header is in result
        // "If the lock cannot be granted to all resources, the server must return a Multi-Status response with a 'response' element for at least one resource that prevented the lock from being granted, along with a suitable status code for that failure (e.g., 403 (Forbidden) or 423 (Locked)). Additionally, if the resource causing the failure was not the resource requested, then the server should include a 'response' element for the Request-URI as well, with a 'status' element containing 424 Failed Dependency."
        
        NSString *token = [op valueForResponseHeader:@"Lock-Token"];
        DEBUG_DAV(2, @"  --> token %@", token);
        
        // OBFinishPorting: Handle bad response from the server that doesn't contain a lock token.
        OBASSERT(![NSString isEmptyString:token]);
        
        COMPLETE_AND_RETURN(token, errorOrNil);
    }];
}

- (void)unlockURL:(NSURL *)url token:(NSString *)lockToken completionHandler:(ODAVConnectionBasicCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    DEBUG_DAV(1, @"DAV operation: UNLOCK %@ token:%@", url, lockToken);
    
    NSMutableURLRequest *request = [self _requestForURL:url];
    [request setHTTPMethod:@"UNLOCK"];
    [request addValue:lockToken forHTTPHeaderField:@"Lock-Token"];
    
    [self _runRequestExpectingEmptyResultData:request completionHandler:^(ODAVURLResult *result, NSError *errorOrNil) {
        if (!result)
            COMPLETE_AND_RETURN(errorOrNil);
        else
            COMPLETE_AND_RETURN(nil);
    }];
}

#pragma mark - Private

- (NSMutableURLRequest *)_requestForURL:(NSURL *)url;
{
    static const NSURLRequestCachePolicy DefaultCachePolicy = NSURLRequestUseProtocolCachePolicy;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:DefaultCachePolicy timeoutInterval:[self _timeoutForURL:url]];
    
    NSString *userAgent = [NSString isEmptyString:_userAgent] ? [_configuration userAgent] : _userAgent;
    OBASSERT(![NSString isEmptyString:userAgent]);
    
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];

    if (_operationReason != nil)
        [request setValue:_operationReason forHTTPHeaderField:@"X-Caused-By"];

    // On iOS, this will be overridden by the user preference in Settings.app
    request.allowsCellularAccess = YES;
    
    return request;
}

- (NSTimeInterval)_timeoutForURL:(NSURL *)url;
{
    static const NSTimeInterval DefaultTimeoutInterval = 300.0;
    
    return DefaultTimeoutInterval;
}

- (void)_runRequest:(NSURLRequest *)request completionHandler:(void (^)(ODAVOperation *operation))completionHandler;
{
    NSTimeInterval start = 0;
    if (ODAVConnectionDebug > 1)
        start = [NSDate timeIntervalSinceReferenceDate];
    
    completionHandler = [completionHandler copy];
    ODAVOperation *operation = [self _makeOperationForRequest:request];
    
    operation.didFinish = ^(ODAVOperation *op, NSError *error) {
        OBINVARIANT(error == op.error);
        if (ODAVConnectionDebug > 1) {
            static NSTimeInterval totalWait = 0;
            NSTimeInterval operationWait = [NSDate timeIntervalSinceReferenceDate] - start;
            totalWait += operationWait;
            NSLog(@"  ... network: %gs (total %g)", operationWait, totalWait);
        }
        COMPLETE_AND_RETURN(op);
    };

    [operation startWithCallbackQueue:[NSOperationQueue currentQueue]];
}

- (NSURL *)_resultLocationForOperation:(ODAVOperation *)operation request:(NSURLRequest *)request;
{
    NSURL *resultLocation = nil;
    
    // If the response specified a Location header, use that (this will be set to the the Destination for COPY/MOVE, possibly already redirected).
    NSString *resultLocationString = [operation valueForResponseHeader:@"Location"];
    if (![NSString isEmptyString:resultLocationString]) {
        // See note below about Apache sending back unencoded URIs in the Location header.
        resultLocation = [NSURL URLWithString:resultLocationString];
    }
    if (resultLocation) {
        NSString *requestScheme = [request.URL.scheme lowercaseString];
        NSString *resultScheme = [resultLocation.scheme lowercaseString];
        if ([requestScheme isEqualToString:@"https"] && ![resultScheme isEqualToString:@"https"]) {
            // Work around a behavior in some servers where after doing a PUT with an https URI, will return an http URI in the Location of the response.
            // This can result in one of 2 undesirable behaviors:
            //  - it downgrades the connection to http, and surprisingly sends data in the clear
            //  - it fails on subsequent operations because the server doesn't actually support DAV over http
            // If the location would downgrade the connection, ignore it, falling back to the Destination header or request URI
            // See <bug:///90927>
            resultLocation = nil;
            DEBUG_DAV(2, @"Ignoring Location header in the response since it would downgrade the connection to http. Ignored value: %@", resultLocation);
        }
        
        if ([[resultLocation host] isEqualToString:@"localhost"] && ![[[request URL] host] isEqualToString:@"localhost"]) {
            // Work around a bug in OS X Server's WebDAV hosting on 10.8.3 where the proxying server passes back Location headers which are unreachable from the outside world rather than rewriting them into its own namespace.  (It doesn't ever make sense to redirect a WebDAV request to localhost from somewhere other than localhost.)  Hopefully the Location headers in question are always predictable!  Fixes <bug:///87276> (Syncs after initial sync fail on 10.8.3 WebDAV server (error -1004, kCFURLErrorCannotConnectToHost)).
            // We'll fall back to using the Destination header we specified, but we could also try to take the path from the result URL and tack it onto the scheme/host/port from the original.
            resultLocation = nil;
        }
    }
    
    // This fails so often on stock Apache that I'm turning it off.
    // Apache 2.4.3 doesn't properly URI encode the Location header <See https://issues.apache.org/bugzilla/show_bug.cgi?id=54611> (though our patched version does), but hopefully the location we *asked* to move it to will be valid. Note this won't help for PUT <https://issues.apache.org/bugzilla/show_bug.cgi?id=54367> since it doesn't have a destination header. But in this case we'll fall through and use the original URI.
    // OBASSERT(resultLocation, @"Location header couldn't be parsed as a URL, %@", resultLocationString);
    
    // If we couldn't parse the Location header, try the Destination header (for COPY/MOVE).
    if (!resultLocation) {
        NSString *destinationHeader = [request valueForHTTPHeaderField:@"Destination"];
        if (![NSString isEmptyString:destinationHeader]) {
            // Skip the protocol downgrade checks that we performed on the Location value.
            // We built the Destination header and grab it back out of the request headers here, so the server shouldn’t be able to muck it up.
            resultLocation = [NSURL URLWithString:destinationHeader];
        }
    }
    
    if (!resultLocation) {
        // Otherwise use the original URL (for MKCOL, for example), looking up any redirection that happened on it.
        resultLocation = request.URL;
        
        NSArray *redirects = operation.redirects;
        if ([redirects count]) {
            ODAVRedirect *lastRedirect = [redirects lastObject];
            NSURL *lastLocation = lastRedirect.to;
            if (![lastLocation isEqual:resultLocation])
                resultLocation = lastLocation;
        }
    }
    
    return resultLocation;
}

- (void)_runRequestExpectingResultData:(NSURLRequest *)request completionHandler:(ODAVConnectionURLAndDataCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    [self _runRequest:request completionHandler:^(ODAVOperation *operation) {
        if (operation.error)
            COMPLETE_AND_RETURN(nil, operation.error);
        
        ODAVURLAndDataResult *result = [ODAVURLAndDataResult new];
        result.URL = [self _resultLocationForOperation:operation request:request];
        result.responseData = operation.resultData;
        result.redirects = operation.redirects;
        COMPLETE_AND_RETURN(result, nil);
    }];
}

- (void)_runRequestExpectingEmptyResultData:(NSURLRequest *)request completionHandler:(ODAVConnectionURLCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    [self _runRequest:request completionHandler:^(ODAVOperation *operation) {
        if (operation.error)
            COMPLETE_AND_RETURN(nil, operation.error);

        NSData *responseData = operation.resultData;
        
        if (ODAVConnectionDebug > 1 && [responseData length] > 0) {
            NSString *xmlString = [NSString stringWithData:responseData encoding:NSUTF8StringEncoding];
            NSLog(@"Unused response data: %@", xmlString);
            // still, we didn't get an error code, so let it pass
        }
        
        ODAVURLResult *result = [ODAVURLResult new];
        result.URL = [self _resultLocationForOperation:operation request:request];
        result.redirects = operation.redirects;
        COMPLETE_AND_RETURN(result, nil);
    }];
}

typedef void (^ODAVConnectionDocumentCompletionHandler)(OFXMLDocument *document, ODAVOperation *op, NSError *errorOrNil);

- (void)_runRequestExpectingDocument:(NSURLRequest *)request completionHandler:(ODAVConnectionDocumentCompletionHandler)completionHandler;
{
    completionHandler = [completionHandler copy];
    
    [self _runRequest:request completionHandler:^(ODAVOperation *operation) {
        NSData *responseData = operation.resultData;
        if (operation.error)
            COMPLETE_AND_RETURN(nil, operation, operation.error);
        
        OFXMLDocument *doc = nil;
        NSError *documentError = nil;
        NSTimeInterval start = 0;
        @autoreleasepool {
            // It was found and we got data back.  Parse the response.
            DEBUG_DAV(2, @"xmlString: %@", [NSString stringWithData:responseData encoding:NSUTF8StringEncoding]);
            
            if (ODAVConnectionDebug > 1)
                start = [NSDate timeIntervalSinceReferenceDate];
            
            __autoreleasing NSError *error = nil;
            doc = [[OFXMLDocument alloc] initWithData:responseData whitespaceBehavior:[OFXMLWhitespaceBehavior ignoreWhitespaceBehavior] error:&error];
            if (!doc)
                documentError = error; // strongify this to live past the pool
        }
        
        if (ODAVConnectionDebug > 1) {
            static NSTimeInterval totalWait = 0;
            NSTimeInterval operationWait = [NSDate timeIntervalSinceReferenceDate] - start;
            totalWait += operationWait;
            NSLog(@"  ... xml: %gs (total %g)", operationWait, totalWait);
        }

        if (!doc) {
            NSLog(@"Unable to decode XML from WebDAV response: %@", [documentError toPropertyList]);
            COMPLETE_AND_RETURN(nil, nil, documentError);
        } else
            COMPLETE_AND_RETURN(doc, operation, nil);
    }];
}


#pragma mark - Internal API for subclasses

// This should NEVER message the 'sender' of the challenge, though the NSURLConnection-based subclass will do that via the completion handler.
- (void)_handleChallenge:(NSURLAuthenticationChallenge *)challenge
               operation:(nullable ODAVOperation *)operation
       completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler;
{
    OBPRECONDITION(challenge);
    OBPRECONDITION(operation || [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]); // See commentary below where `operation` is used
    OBPRECONDITION(completionHandler);
    
    DEBUG_DAV(3, @"will send request for authentication challenge %@", challenge);
    
    NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
    NSString *challengeMethod = [protectionSpace authenticationMethod];
    if (ODAVConnectionDebug > 2) {
        NSLog(@"protection space %@ realm:%@ secure:%d proxy:%d host:%@ port:%ld proxyType:%@ protocol:%@ method:%@",
              protectionSpace,
              [protectionSpace realm],
              [protectionSpace receivesCredentialSecurely],
              [protectionSpace isProxy],
              [protectionSpace host],
              [protectionSpace port],
              [protectionSpace proxyType],
              [protectionSpace protocol],
              [protectionSpace authenticationMethod]);
        
        NSLog(@"proposed credential %@", [challenge proposedCredential]);
        NSLog(@"previous failure count %ld", [challenge previousFailureCount]);
        NSLog(@"failure response %@", [challenge failureResponse]);
        NSLog(@"error %@", [[challenge error] toPropertyList]);
    }
    
    // The +[NSURLCredentialStorage sharedCredentialStorage] doesn't have the .Mac password it in, sadly.
    //    NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
    //    NSLog(@"all credentials = %@", [storage allCredentials]);
    
    NSURLCredential *credential = nil;
    
    if ([challengeMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef trustRef;
        if ((trustRef = [protectionSpace serverTrust]) != NULL) {
            SecTrustResultType evaluationResult = kSecTrustResultOtherError;
            OSStatus oserr = SecTrustEvaluate(trustRef, &evaluationResult); // NB: May block for long periods (eg OCSP verification, etc)
            if (ODAVConnectionDebug > 2) {
                NSString *result; // TODO: Use OFSummarizeTrustResult() instead.
                if (oserr != noErr) {
                    result = [NSString stringWithFormat:@"error %ld", (long)oserr];
                } else {
                    result = [NSString stringWithFormat:@"condition %d", (int)evaluationResult];
                }
                NSLog(@"%@: SecTrustEvaluate returns %@", [self shortDescription], result);
            }
            if (oserr == noErr && evaluationResult == kSecTrustResultRecoverableTrustFailure) {
                // The situation we're interested in is "recoverable failure": this indicates that the evaluation failed, but might succeed if we prod it a little.
                BOOL hasTrust = OFHasTrustForChallenge(challenge);
                if (!hasTrust) {
                    // Our caller may choose to pop up UI or it might choose to immediately mark the certificate as trusted.
                    if (_validateCertificateForChallenge)
                        _validateCertificateForChallenge(challenge);
                    hasTrust = OFHasTrustForChallenge(challenge);
                }
                
                if (hasTrust) {
                    credential = [NSURLCredential credentialForTrust:trustRef];
                    DEBUG_DAV(3, @"credential = %@", credential);
                    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
                    return;
                } else {
                    // The delegate didn't opt to immediately mark the certificate trusted. It is presumably giving up or prompting the user and will retry the operation later.
                    // We'd prefer to cancel here, but if we do, we deadlock (in the NSOperationQueue-based scheduling).
                    //[[challenge sender] cancelAuthenticationChallenge:challenge];
                    
                    // These doesn't block the operation if, during this process, we've connected to the host, but the host has changed certificates since then.
                    //[[challenge sender] performDefaultHandlingForAuthenticationChallenge:challenge];
                    completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
                    
                    // This doesn't block the operation
                    //[[challenge sender] rejectProtectionSpaceAndContinueWithChallenge:challenge];
                    
                    //[[challenge sender] useCredential:nil forAuthenticationChallenge:challenge];
                    
                    return;
                }
            }
        }
        
        // If we "continue without credential", NSURLConnection will consult certificate trust roots and per-cert trust overrides in the normal way. If we cancel the "challenge", NSURLConnection will drop the connection, even if it would have succeeded without our meddling (that is, we can force failure as well as forcing success).
        completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
        return;
    }
    
    if (_findCredentialsForChallenge)
        credential = _findCredentialsForChallenge(challenge);
    
    DEBUG_DAV(3, @"credential = %@", credential);
    
    if (credential) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        // In the NSURLSession case, we get passed nil for the operation when we are getting a certificate challenge (it has both a whole-session and per-task challenge method and the per-task one is called for login credentials, while the per-session is called for certificate challenges). We are past the certificate challenge here, so we only need the operation in this case.
        // We could maybe split this into two methods do express the nullability of `operation` more cleanly.
        OBASSERT(operation); // ... or we'll lose the error info
        [operation _credentialsNotFoundForChallenge:challenge];
        
        // We'd prefer to cancel here, but if we do, we deadlock (in the NSOperationQueue-based scheduling).
        //[[challenge sender] cancelAuthenticationChallenge:challenge];
        completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
    }
}

@end

/*
 Helper to make ODAVConnection operations have blocking checkpoints. This can also serve as a search target for places we could increase parallelism and cancellability.
 */
void ODAVSyncOperation(const char *file, unsigned line, ODAVAddOperation op)
{
    NSConditionLock *doneLock = [[NSConditionLock alloc] initWithCondition:NO];
    
    op = [op copy];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    queue.name = [NSString stringWithFormat:@"com.omnigroup.OmniDAV.ODAVSyncOperation from %s:%d", file, line];
    
    [queue addOperationWithBlock:^{
        op(^{
            OBASSERT(queue == [NSOperationQueue currentQueue], "If this isn't true, we might deadlock (like if the operation invokes the done block on the original queue");
            [doneLock lock];
            OBASSERT([doneLock condition] == NO, "Called done block more than once?");
            [doneLock unlockWithCondition:YES];
        });
    }];
    
    [doneLock lockWhenCondition:YES];
    [doneLock unlock];
}

// Run some operations in parallel and wait for them all to finish.
void ODAVSyncOperations(const char *file, unsigned line, ODAVAddOperations addOperations)
{
    NSConditionLock *doneLock = [[NSConditionLock alloc] initWithCondition:YES]; // We are "done" if addOperations() doesn't add anything.
    __block NSUInteger runningOperations = 0;
    
    NSOperationQueue *workQueue = [[NSOperationQueue alloc] init];
    workQueue.name = [NSString stringWithFormat:@"com.omnigroup.OmniDAV.ODAVSyncOperations.workQueue from %s:%d", file, line];
    
    NSOperationQueue *completionQueue = [[NSOperationQueue alloc] init];
    completionQueue.maxConcurrentOperationCount = 1;
    completionQueue.name = [NSString stringWithFormat:@"com.omnigroup.OmniDAV.ODAVSyncOperations.completionQueue from %s:%d", file, line];
    
    ODAVFinishOperation finish = [^(ODAVFinishAction finishAction){
        finishAction = [finishAction copy];
        [completionQueue addOperationWithBlock:^{
            if (finishAction)
                finishAction();
            [doneLock lock];
            OBASSERT(runningOperations > 0);
            runningOperations--;
            [doneLock unlockWithCondition:(runningOperations == 0)];
        }];
    } copy];
    
    OFXStartOperation start = ^(ODAVStartAction backgrounAction){
        [doneLock lock];
        runningOperations++;
        [doneLock unlockWithCondition:NO];
        
        [workQueue addOperationWithBlock:^{
            backgrounAction(finish);
        }];
    };
    
    addOperations(start);
    
    [doneLock lockWhenCondition:YES];
    [doneLock unlock];
}

@implementation ODAVConnection (ODAVSyncExtensions)

- (BOOL)synchronousDeleteURL:(NSURL *)url withETag:(NSString *)ETag error:(NSError **)outError;
{
    OBPRECONDITION(url);
    
    __block NSError *error;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self deleteURL:url withETag:ETag completionHandler:^(NSError *deleteError){
            error = deleteError;
            done();
        }];
    });
    
    if (error && outError)
        *outError = error;
    return (error == nil);
}

- (ODAVURLResult *)synchronousMakeCollectionAtURL:(NSURL *)url error:(NSError **)outError;
{
    OBPRECONDITION(url);

    __block NSError *resultError;
    __block ODAVURLResult *result;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self makeCollectionAtURL:url completionHandler:^(ODAVURLResult *createdResult, NSError *createError){
            OBASSERT(createdResult || createError);
            if (createdResult)
                result = createdResult;
            else
                resultError = createError;
            done();
        }];
    });
    
    if (!result && outError)
        *outError = resultError;
    return result;
}

- (ODAVFileInfo *)synchronousFileInfoAtURL:(NSURL *)url error:(NSError **)outError;
{
    return [self synchronousFileInfoAtURL:url serverDate:NULL error:outError];
}

- (ODAVFileInfo *)synchronousFileInfoAtURL:(NSURL *)url serverDate:(NSDate **)outServerDate error:(NSError **)outError;
{
    OBPRECONDITION(url);
    
    __block ODAVSingleFileInfoResult *returnResult;
    __block NSError *returnError;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self fileInfoAtURL:url ETag:nil completionHandler:^(ODAVSingleFileInfoResult *result, NSError *errorOrNil) {
            if (result)
                returnResult = result;
            else
                returnError = errorOrNil;
            done();
        }];
    });
    
    if (!returnResult && outError) {
        *outError = returnError;
        return nil;
    }
    
    if (outServerDate)
        *outServerDate = returnResult.serverDate;
    return returnResult.fileInfo;
}

- (ODAVMultipleFileInfoResult *)synchronousDirectoryContentsAtURL:(NSURL *)url withETag:(NSString *)ETag error:(NSError **)outError;
{
    OBPRECONDITION(url);

    __block ODAVMultipleFileInfoResult *returnResult;
    __block NSError *returnError;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self directoryContentsAtURL:url withETag:ETag completionHandler:^(ODAVMultipleFileInfoResult *properties, NSError *errorOrNil) {
            returnResult = properties;
            returnError = errorOrNil;
            done();
        }];
    });
    
    if (!returnResult && outError) {
        *outError = returnError;
        return nil;
    }

    return returnResult;
}

static NSURL *_returnURLOrError(NSURL *URL, NSError *error, NSError **outError)
{
    if (URL)
        return URL;
    if (outError)
        *outError = error;
    return nil;
}
                      
- (NSData *)synchronousGetContentsOfURL:(NSURL *)url ETag:(NSString *)ETag error:(NSError **)outError;
{
    OBPRECONDITION(url);
    
    __block ODAVOperation *operation;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self getContentsOfURL:url ETag:ETag completionHandler:^(ODAVOperation *op) {
            operation = op;
            done();
        }];
    });
    
    if (operation.error) {
        if (outError)
            *outError = operation.error;
        return nil;
    }
    
    return operation.resultData;
}

- (NSURL *)synchronousPutData:(NSData *)data toURL:(NSURL *)url error:(NSError **)outError;
{
    OBPRECONDITION(data, @"Pass an empty data if that's really what you want");
    OBPRECONDITION(url);
    
    __block ODAVURLResult *returnResult;
    __block NSError *returnError;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self putData:data toURL:url completionHandler:^(ODAVURLResult *result, NSError *errorOrNil) {
            if (result)
                returnResult = result;
            else
                returnError = errorOrNil;
            done();
        }];
    });
    
    if (!returnResult && outError)
        *outError = returnError;
    return returnResult.URL;
}

- (NSURL *)synchronousCopyURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceETag:(NSString *)sourceETag overwrite:(BOOL)overwrite error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block ODAVURLResult *result;
    __block NSError *error;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self copyURL:sourceURL toURL:destURL withSourceETag:sourceETag overwrite:overwrite completionHandler:^(ODAVURLResult *copiedResult, NSError *copyError) {
            result = copiedResult;
            error = copyError;
            done();
        }];
    });
    
    return _returnURLOrError(result.URL, error, outError);
}

- (NSURL *)synchronousMoveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withDestinationETag:(NSString *)ETag overwrite:(BOOL)overwrite error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block ODAVURLResult *result;
    __block NSError *error;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self moveURL:sourceURL toURL:destURL withDestinationETag:ETag overwrite:overwrite completionHandler:^(ODAVURLResult *moveResult, NSError *errorOrNil) {
            result = moveResult;
            error = errorOrNil;
            done();
        }];
    });
    
    return _returnURLOrError(result.URL, error, outError);
}

- (NSURL *)synchronousMoveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceLock:(NSString *)lock overwrite:(BOOL)overwrite error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block ODAVURLResult *result;
    __block NSError *error;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self moveURL:sourceURL toURL:destURL withSourceLock:lock overwrite:overwrite completionHandler:^(ODAVURLResult *moveResult, NSError *errorOrNil) {
            result = moveResult;
            error = errorOrNil;
            done();
        }];
    });
    
    return _returnURLOrError(result.URL, error, outError);
}

- (NSURL *)synchronousMoveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withDestinationLock:(NSString *)lock overwrite:(BOOL)overwrite error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block ODAVURLResult *result;
    __block NSError *error;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self moveURL:sourceURL toURL:destURL withDestinationLock:lock overwrite:overwrite completionHandler:^(ODAVURLResult *moveResult, NSError *errorOrNil) {
            result = moveResult;
            error = errorOrNil;
            done();
        }];
    });
    
    return _returnURLOrError(result.URL, error, outError);
}

- (NSURL *)synchronousMoveURL:(NSURL *)sourceURL toMissingURL:(NSURL *)destURL error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block ODAVURLResult *result;
    __block NSError *error;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self moveURL:sourceURL toMissingURL:destURL completionHandler:^(ODAVURLResult *moveResult, NSError *errorOrNil) {
            result = moveResult;
            error = errorOrNil;
            done();
        }];
    });
    
    return _returnURLOrError(result.URL, error, outError);
}

- (NSString *)synchronousLockURL:(NSURL *)url error:(NSError **)outError;
{
    OBPRECONDITION(url);
    
    __block NSString *returnToken;
    __block NSError *returnError;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self lockURL:url completionHandler:^(NSString *resultString, NSError *errorOrNil) {
            if (resultString)
                returnToken = resultString;
            else
                returnError = errorOrNil;
            done();
        }];
    });
    
    if (!returnToken && outError)
        *outError = returnError;
    return returnToken;
}

- (BOOL)synchronousUnlockURL:(NSURL *)url token:(NSString *)lockToken error:(NSError **)outError;
{
    OBPRECONDITION(url);
    
    __block NSError *returnError;
    
    ODAVSyncOperation(__FILE__, __LINE__, ^(ODAVOperationDone done){
        [self unlockURL:url token:lockToken completionHandler:^(NSError *errorOrNil) {
            returnError = errorOrNil;
            done();
        }];
    });
    
    if (returnError && outError)
        *outError = returnError;
    return returnError == nil;
}

#if 0

- (NSURL *)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block NSURL *URL;
    __block NSError *error;
    
    [self _performOperation:^(OperationDone done) {
        [_connection moveURL:sourceURL toURL:destURL completionHandler:^(NSURL *resultURL, NSError *errorOrNil) {
            URL = resultURL;
            error = errorOrNil;
            done();
        }];
    }];
    
    return _returnURLOrError(URL, error, outError);
}

- (NSURL *)copyURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceETag:(NSString *)ETag overwrite:(BOOL)overwrite error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block NSURL *URL;
    __block NSError *error;
    
    [self _performOperation:^(OperationDone done) {
        [_connection copyURL:sourceURL toURL:destURL withSourceETag:ETag overwrite:overwrite completionHandler:^(NSURL *resultURL, NSError *errorOrNil) {
            URL = resultURL;
            error = errorOrNil;
            done();
        }];
    }];
    
    return _returnURLOrError(URL, error, outError);
}

- (NSURL *)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL withSourceETag:(NSString *)ETag overwrite:(BOOL)overwrite error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block NSURL *URL;
    __block NSError *error;
    
    [self _performOperation:^(OperationDone done) {
        [_connection moveURL:sourceURL toURL:destURL withSourceETag:ETag overwrite:overwrite completionHandler:^(NSURL *resultURL, NSError *errorOrNil) {
            URL = resultURL;
            error = errorOrNil;
            done();
        }];
    }];
    
    return _returnURLOrError(URL, error, outError);
}

- (NSURL *)moveURL:(NSURL *)sourceURL toURL:(NSURL *)destURL ifURLExists:(NSURL *)tagURL error:(NSError **)outError;
{
    OBPRECONDITION(sourceURL);
    OBPRECONDITION(destURL);
    
    __block NSURL *URL;
    __block NSError *error;
    
    [self _performOperation:^(OperationDone done) {
        [_connection moveURL:sourceURL toURL:destURL ifURLExists:tagURL completionHandler:^(NSURL *resultURL, NSError *errorOrNil) {
            URL = resultURL;
            error = errorOrNil;
            done();
        }];
    }];
    
    return _returnURLOrError(URL, error, outError);
}

#endif

@end


