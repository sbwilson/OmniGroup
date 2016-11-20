// Copyright 2004-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFTestCase.h"

#import <OmniFoundation/OFAlias.h>

#import <OmniBase/rcsid.h>

#import <OmniFoundation/NSData-OFExtensions.h>
#import <OmniFoundation/NSFileManager-OFExtensions.h>

RCS_ID("$Id$")

@interface OFAliasTest : OFTestCase
{
}
@end

@implementation OFAliasTest

- (void)testAlias
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [fileManager tempFilenameFromHashesTemplate:@"/tmp/OFAliasTest-######"];
    XCTAssertTrue(path != nil);
    if (!path)
        return;
    
    XCTAssertTrue([[NSData data] writeToFile:path options:0 error:NULL]);
    
    OFAlias *originalAlias = [[OFAlias alloc] initWithPath:path];
    NSString *resolvedPath = [originalAlias path];
    
    XCTAssertEqualObjects([path stringByStandardizingPath], [resolvedPath stringByStandardizingPath]);
    
    NSData *aliasData = [originalAlias data];
    OFAlias *restoredAlias = [[OFAlias alloc] initWithData:aliasData];
    
    NSString *moveToPath1 = [fileManager tempFilenameFromHashesTemplate:@"/tmp/OFAliasTest-######"];
    XCTAssertTrue([fileManager moveItemAtPath:path toPath:moveToPath1 error:NULL]);
    
    NSString *resolvedMovedPath = [restoredAlias path];
    
    XCTAssertEqualObjects([moveToPath1 stringByStandardizingPath], [resolvedMovedPath stringByStandardizingPath]);
    
    NSString *moveToPath2 = [fileManager tempFilenameFromHashesTemplate:@"/tmp/OFAliasTest-######"];
    XCTAssertTrue([fileManager moveItemAtPath:moveToPath1 toPath:moveToPath2 error:NULL]);
    
    NSData *movedAliasData = [[NSData alloc] initWithASCII85String:[[restoredAlias data] ascii85String]];
    OFAlias *movedAliasFromData = [[OFAlias alloc] initWithData:movedAliasData];
    XCTAssertTrue([movedAliasFromData path] != nil);
    
    XCTAssertTrue([fileManager removeItemAtPath:moveToPath2 error:NULL]);
    
}

@end
