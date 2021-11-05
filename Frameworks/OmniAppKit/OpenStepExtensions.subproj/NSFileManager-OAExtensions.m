// Copyright 2002-2013 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/NSFileManager-OAExtensions.h>
#if defined(MAC_OS_VERSION_11_0) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_VERSION_11_0
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#endif

RCS_ID("$Id$")

@implementation NSFileManager (OAExtensions)

/*" Returns any entries in the given directory which conform to any of the UTIs specified in /someUTIs/. Returns nil on error. If /errOut/ is NULL, this routine will continue past errors inspecting individual files and will return any files which can be inspected. Otherwise, it will return nil upon encountering the first error. If /fullPath/ is YES, the returned paths will have /path/ prepended to them. "*/
- (NSArray *)directoryContentsAtPath:(NSString *)path ofTypes:(NSArray *)someUTIs deep:(BOOL)recurse fullPath:(BOOL)fullPath error:(NSError **)errOut;
{
    id <NSFastEnumeration> enumerable;
    NSMutableArray *filteredChildren;
    
    if (!recurse) {
        NSArray *children = [self contentsOfDirectoryAtPath:path error:errOut];
        if (!children)
            return nil;
        
        NSUInteger entries = [children count];
        if (entries == 0)
            return children;
    
        filteredChildren = [NSMutableArray arrayWithCapacity:entries];
        enumerable = children;
    } else {
        NSDirectoryEnumerator *children = [self enumeratorAtPath:path];
        if (!children)
            return nil;
        
        filteredChildren = [NSMutableArray array];
        enumerable = children;
    }
    
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    for (NSString *childName in enumerable) {
        NSString *childPath = [path stringByAppendingPathComponent:childName];
        
        NSString *childType;
        if (@available(macOS 11, *)) {
            NSURL *childURL = [NSURL fileURLWithPath:childPath];
            
            if (![childURL getResourceValue:&childType forKey:NSURLContentTypeKey error:errOut]) {
                if (errOut) // to match old behavior
                    return nil;
                else
                    continue;
            }
            
           // childType = [ws typeOfFile:childPath error:errOut];
           // -[NSURL getResourceValue:forKey:error:] with NSURLContentTypeKey instead.
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            childType = [ws typeOfFile:childPath error:errOut];
#pragma clang diagnostic pop
        }

        if (!childType) {
            if (errOut)
                return nil;
            else
                continue;
        }
        if (@available(macOS 11, *)) {
            UTType *childUTType = [UTType typeWithIdentifier: childType];
            for (NSString *someDesiredType in someUTIs) {
                if ([childUTType conformsToType:[UTType typeWithIdentifier:someDesiredType]]) {
                    [filteredChildren addObject:fullPath ? childPath : childName];
                    break;
                }
            }
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            for (NSString *someDesiredType in someUTIs) {
                if ([ws type:childType conformsToType:someDesiredType]) {
                    [filteredChildren addObject:fullPath ? childPath : childName];
                    break;
                }
            }
#pragma clang diagnostic pop
        }
    }
    
    return filteredChildren;
}

@end
