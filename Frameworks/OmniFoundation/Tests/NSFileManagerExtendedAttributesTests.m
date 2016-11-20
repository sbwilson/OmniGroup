// Copyright 2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFTestCase.h"

#import <OmniFoundation/NSFileManager-OFExtendedAttributes.h>

RCS_ID("$Id$");

static NSString * const TestXattrName = @"com.omnigroup.OmniFoundation.UnitTests.XattrName";

@interface NSFileManagerExtendedAttributesTests : XCTestCase
@property (nonatomic, copy) NSString *tempFilePath;
@end

@implementation NSFileManagerExtendedAttributesTests

- (void)setUp {
    [super setUp];
    self.tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"xattr_test"];
    XCTAssertTrue([[NSFileManager defaultManager] createFileAtPath:self.tempFilePath contents:[NSData data] attributes:nil]);
}

- (void)tearDown {
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:NULL]);
    self.tempFilePath = nil;
    [super tearDown];
}

#pragma mark Tests

- (void)testMissingFileReturnsError;
{
    NSError *error = nil;
    NSSet *xattrs = [[NSFileManager defaultManager] listExtendedAttributesForItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"missing"] error:&error];
    XCTAssertNil(xattrs);
    XCTAssertNotNil(error);
}

- (void)testNewFileHasNoXattrs;
{
    NSError *error = nil;
    NSSet *xattrs = [[NSFileManager defaultManager] listExtendedAttributesForItemAtPath:self.tempFilePath error:&error];
    XCTAssertEqualObjects(xattrs, [NSSet set]);
    XCTAssertNil(error);
}

- (void)testAddXattr;
{
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:[@"foo" dataUsingEncoding:NSUTF8StringEncoding] forItemAtPath:self.tempFilePath error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
}

- (void)testListAddedXattr;
{
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:[@"foo" dataUsingEncoding:NSUTF8StringEncoding] forItemAtPath:self.tempFilePath error:&error];
    XCTAssertTrue(success);
    
    NSSet *xattrs = [[NSFileManager defaultManager] listExtendedAttributesForItemAtPath:self.tempFilePath error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(xattrs, [NSSet setWithObject:TestXattrName]);
}

- (void)testReadAddedXattr;
{
    NSData *testValue = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:testValue forItemAtPath:self.tempFilePath error:&error];
    XCTAssertTrue(success);
    
    NSData *data = [[NSFileManager defaultManager] extendedAttribute:TestXattrName forItemAtPath:self.tempFilePath error:&error];
    XCTAssertEqualObjects(testValue, data);
    XCTAssertNil(error);
}

- (void)testListManyXattrs;
{
    NSUInteger xattrCount = 100;
    for (NSUInteger i = 0; i < xattrCount; i++) {
        NSString *xattr = [NSString stringWithFormat:@"%@%tu", TestXattrName, i];
        NSData *data = [NSData dataWithBytes:&i length:1];
        NSError *error = nil;
        XCTAssertTrue([[NSFileManager defaultManager] setExtendedAttribute:xattr data:data forItemAtPath:self.tempFilePath error:&error]);
    }
    
    NSError *error = nil;
    NSSet *xattrs = [[NSFileManager defaultManager] listExtendedAttributesForItemAtPath:self.tempFilePath error:&error];
    XCTAssertEqual([xattrs count], xattrCount);
    XCTAssertNil(error);
}

- (void)testAddAndRemoveXattr;
{
    NSData *data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:data forItemAtPath:self.tempFilePath error:&error]);
    
    BOOL success = [[NSFileManager defaultManager] removeExtendedAttribute:TestXattrName forItemAtPath:self.tempFilePath error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
}

- (void)testAddAndNilXattr;
{
    NSData *data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:data forItemAtPath:self.tempFilePath error:&error]);
    
    BOOL success = [[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:nil forItemAtPath:self.tempFilePath error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
}

- (void)testVeryLongXattrData;
{
    // pathconf(2) says that passing _PC_XATTR_SIZE_BITS will return the maximum number of bits that can be used to store xattr data size on the given file (e.g. 18 => max size is 256KB - 1). Try storing data just a bit larger and expect an error.
    const char * path = [self.tempFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    long maxSizeBits = pathconf(path, _PC_XATTR_SIZE_BITS);
    XCTAssert(maxSizeBits > 0);
    
    size_t size = pow(2, maxSizeBits);
    void *value = memset(malloc(size), 1, size);
    NSData *data = [NSData dataWithBytes:value length:size];
    
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] setExtendedAttribute:TestXattrName data:data forItemAtPath:self.tempFilePath error:&error];
    XCTAssertFalse(success);
    XCTAssertTrue([error hasUnderlyingErrorDomain:NSPOSIXErrorDomain code:E2BIG]);
    
    free(value);
}

@end
