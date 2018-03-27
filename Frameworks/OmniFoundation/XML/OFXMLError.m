// Copyright 2003-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFXMLError.h"

#import <OmniFoundation/OFErrors.h>

RCS_ID("$Id$");

NSError *OFXMLCreateError(xmlErrorPtr error)
{
    // When parsing WebDAV results, we get a hojillion complaints that 'DAV:' is not a valid URI.  Nothing we can do about this as that's what Apache sends (and what WebDAV requires).  Sorry!
    if (error->domain == XML_FROM_PARSER && error->code == XML_WAR_NS_URI)
        return nil;
    
#ifdef DEBUG_bungi
    // Go's WebDAV (experimental) can end up re-defining 'xmlns="DAV:"'. It would be nice to check if the two values are the same...n
    if (error->domain == XML_FROM_PARSER && error->code == XML_ERR_ATTRIBUTE_REDEFINED && (error->str1 && strcmp(error->str1, "xmlns") == 0))
        return nil;
#endif
    
    // libxml2 has its own notion of domain/code -- put those in the user info.
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     [NSNumber numberWithInt:error->domain], @"libxml_domain",
                                     [NSNumber numberWithInt:error->code], @"libxml_code",
                                     [NSString stringWithUTF8String:error->message], NSLocalizedFailureReasonErrorKey,
                                     NSLocalizedStringFromTableInBundle(@"Warning encountered while loading XML.", @"OmniFoundation", OMNI_BUNDLE, @"error description"), NSLocalizedDescriptionKey,
                                     nil];
    
    if (error->file) {
        [userInfo setObject:[NSString stringWithUTF8String:error->file] forKey:@"libxml_file"];
        [userInfo setObject:[NSNumber numberWithInt:error->line] forKey:@"libxml_file_line"];
    }
    if (error->str1)
        [userInfo setObject:[NSString stringWithUTF8String:error->str1] forKey:@"libxml_str1"];
    if (error->str2)
        [userInfo setObject:[NSString stringWithUTF8String:error->str1] forKey:@"libxml_str2"];
    if (error->str3)
        [userInfo setObject:[NSString stringWithUTF8String:error->str1] forKey:@"libxml_str3"];
    if (error->int1)
        [userInfo setObject:[NSNumber numberWithInt:error->int1] forKey:@"libxml_int1"];
    if (error->int2)
        [userInfo setObject:[NSNumber numberWithInt:error->int2] forKey:@"libxml_int2"];
    
    NSError *errorObject = [[NSError alloc] initWithDomain:OFErrorDomain code:OFXMLLibraryError userInfo:userInfo];
    [userInfo release];
    
    return errorObject;
}
