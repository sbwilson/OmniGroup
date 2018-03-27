// Copyright 2007-2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFTestCase.h"

#import <OmniBase/OmniBase.h>
#import <OmniFoundation/NSData-OFExtensions.h>
#import <OmniFoundation/NSDictionary-OFExtensions.h>
#import <OmniFoundation/NSMutableData-OFExtensions.h>
#import <OmniFoundation/NSString-OFExtensions.h>
#import <OmniFoundation/OFErrors.h>
#import <OmniFoundation/OFFilterProcess.h>
#import <OmniFoundation/OFScratchFile.h>
#import <OmniFoundation/OFVersionNumber.h>

RCS_ID("$Id$");

@interface OFDataTest : OFTestCase
{
}


@end


@implementation OFDataTest

- (void)testPipe
{
    NSData *smallData   = [NSData dataWithBytes:"Just remember ... wherever you go ... there you are." length:52];
    NSData *smallData13 = [NSData dataWithBytes:"Whfg erzrzore ... jurerire lbh tb ... gurer lbh ner." length:52];
    NSError *uniqueErrorObject = [NSError errorWithDomain:@"blah" code:42 userInfo:[NSDictionary dictionary]];
    NSError *err = uniqueErrorObject;
    
    XCTAssertEqualObjects(([smallData filterDataThroughCommandAtPath:@"/usr/bin/tr" withArguments:[NSArray arrayWithObjects:@"A-Za-z", @"N-ZA-Mn-za-m", nil] error:&err]),
                         smallData13, @"Piping through rot13");
    XCTAssertTrue(err == uniqueErrorObject, @"should not have modified *error (is now %@)", err);
    
    int mediumSize = 67890;
    NSData *mediumData = [NSData randomDataOfLength:mediumSize];
    NSData *mediumR = [mediumData filterDataThroughCommandAtPath:@"/usr/bin/wc" withArguments:[NSArray arrayWithObject:@"-c"] error:NULL];
    XCTAssertTrue(mediumSize == atoi([mediumR bytes]), @"Piping through wc");
    
    err = uniqueErrorObject;
    XCTAssertEqualObjects(([mediumData filterDataThroughCommandAtPath:@"/bin/cat" withArguments:[NSArray array] error:NULL]),
                         mediumData, @"");
    XCTAssertTrue(err == uniqueErrorObject, @"should not have modified *error (is now %@)", err);
    
    err = nil;
    OFScratchFile *scratch = [OFScratchFile scratchFileNamed:@"ofdatatest" error:&err];
    XCTAssertNotNil(scratch, @"scratch file");
    if (!scratch)
        return;
    
    [mediumData writeToURL:scratch.fileURL atomically:NO];
    
    err = uniqueErrorObject;
    XCTAssertEqualObjects(([[NSData data] filterDataThroughCommandAtPath:@"/bin/cat" withArguments:[NSArray arrayWithObject:[[scratch fileURL] path]] error:NULL]),
                         mediumData, @"");
    XCTAssertTrue(err == uniqueErrorObject, @"should not have modified *error (is now %@)", err);
}

- (void)testPipeLarge
{
    if (![[self class] shouldRunSlowUnitTests]) {
        NSLog(@"*** SKIPPING slow test [%@ %@]", [self class], NSStringFromSelector(_cmd));
        return;
    }
    
    /* Make a big random plist */
    NSData *pldata;
    {
        @autoreleasepool {
            NSMutableArray *a = [NSMutableArray array];
            int i;
            for(i = 0; i < 300; i++) {
                NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
                int j;
                for(j = 0; j < 250; j++) {
                    NSString *s = [[NSData randomDataOfLength:15] lowercaseHexString];
                    [d setObject:[NSData randomDataOfLength:72] forKey:s];
                }
                [a addObject:d];
            }
            pldata = CFBridgingRelease(CFPropertyListCreateData(kCFAllocatorDefault, (__bridge CFPropertyListRef)a, kCFPropertyListXMLFormat_v1_0, 0, NULL));
        }
    }
    
    NSData *bzipme = [pldata filterDataThroughCommandAtPath:@"/usr/bin/bzip2" withArguments:[NSArray arrayWithObject:@"--compress"] error:NULL];
    NSData *unzipt = [bzipme filterDataThroughCommandAtPath:@"/usr/bin/bzip2" withArguments:[NSArray arrayWithObject:@"--decompress"] error:NULL];
    XCTAssertEqualObjects(pldata, unzipt, @"bzip+bunzip");
    
    NSData *gzipme  = [pldata filterDataThroughCommandAtPath:@"/usr/bin/gzip" withArguments:[NSArray arrayWithObject:@"-cf9"] error:NULL];
    NSData *ungzipt = [gzipme filterDataThroughCommandAtPath:@"/usr/bin/gzip" withArguments:[NSArray arrayWithObject:@"-cd"] error:NULL];
    XCTAssertEqualObjects(pldata, ungzipt, @"gzip+gunzip");
    
}

- (void)testPipeRunloop
{
    NSLog(@"Starting %@ %@", OBShortObjectDescription(self), NSStringFromSelector(_cmd));
    
    /* Make a moderately-large random plist */
    NSData *pldata;
    {
        @autoreleasepool {
            NSMutableArray *a = [NSMutableArray array];
            int i;
            for(i = 0; i < 100; i++) {
                NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
                int j;
                for(j = 0; j < 100; j++) {
                    NSString *s = [[NSData randomDataOfLength:15] lowercaseHexString];
                    [d setObject:[NSData randomDataOfLength:72] forKey:s];
                }
                [a addObject:d];
            }
            pldata = CFBridgingRelease(CFPropertyListCreateData(kCFAllocatorDefault, (__bridge CFPropertyListRef)a, kCFPropertyListXMLFormat_v1_0, 0, NULL));
        }
    }
    

    NSRunLoop *l = [NSRunLoop currentRunLoop];
    
    NSOutputStream *resultStream1 = [NSOutputStream outputStreamToMemory];
    OFFilterProcess *bzip = [[OFFilterProcess alloc] initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                         @"/usr/bin/bzip2", OFFilterProcessCommandPathKey,
                                                                         [NSArray arrayWithObject:@"--compress"], OFFilterProcessArgumentsKey,
                                                                         pldata, OFFilterProcessInputDataKey,
                                                                         @"NO", OFFilterProcessDetachTTYKey,
                                                                         nil]
                                                         standardOutput:resultStream1
                                                          standardError:nil];
    [bzip scheduleInRunLoop:l forMode:NSRunLoopCommonModes];
    
    NSOutputStream *resultStream2 = [NSOutputStream outputStreamToMemory];
    OFFilterProcess *gzip = [[OFFilterProcess alloc] initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                         @"/usr/bin/gzip", OFFilterProcessCommandPathKey,
                                                                         [NSArray arrayWithObject:@"-cf7"], OFFilterProcessArgumentsKey,
                                                                         pldata, OFFilterProcessInputDataKey,
                                                                         @"NO", OFFilterProcessDetachTTYKey,
                                                                         nil]
                                                         standardOutput:resultStream2
                                                          standardError:nil];
    [gzip scheduleInRunLoop:l forMode:NSRunLoopCommonModes];
    
    OFFilterProcess *bunzip = nil, *gunzip = nil;
    NSOutputStream *resultStream3 = nil, *resultStream4 = nil;
    
    for(;;) {
        [l runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        
        if (bzip && ![bzip isRunning]) {
            resultStream3 = [NSOutputStream outputStreamToMemory];
            bunzip = [[OFFilterProcess alloc] initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                  @"/usr/bin/bzip2", OFFilterProcessCommandPathKey,
                                                                  [NSArray arrayWithObject:@"--decompress"], OFFilterProcessArgumentsKey,
                                                                  [resultStream1 propertyForKey:NSStreamDataWrittenToMemoryStreamKey], OFFilterProcessInputDataKey,
                                                                  @"NO", OFFilterProcessDetachTTYKey,
                                                                  nil]
                                                  standardOutput:resultStream3
                                                   standardError:nil];
            [bunzip scheduleInRunLoop:l forMode:NSRunLoopCommonModes];
            bzip = nil;
        }
        
        if (gzip && ![gzip isRunning]) {
            resultStream4 = [NSOutputStream outputStreamToMemory];
            gunzip = [[OFFilterProcess alloc] initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                   @"/usr/bin/gzip", OFFilterProcessCommandPathKey,
                                                                   [NSArray arrayWithObject:@"-cd"], OFFilterProcessArgumentsKey,
                                                                   [resultStream2 propertyForKey:NSStreamDataWrittenToMemoryStreamKey], OFFilterProcessInputDataKey,
                                                                   @"NO", OFFilterProcessDetachTTYKey,
                                                                   nil]
                                                   standardOutput:resultStream4
                                                    standardError:nil];
            [gunzip scheduleInRunLoop:l forMode:NSRunLoopCommonModes];
            [gzip removeFromRunLoop:l forMode:NSRunLoopCommonModes];
            gzip = nil;
        }
        
        if ((!bzip && bunzip && ![bunzip isRunning]) &&
            (!gzip && gunzip && ![gunzip isRunning]))
            break;
    }
    
        
    XCTAssertEqualObjects(pldata, [resultStream3 propertyForKey:NSStreamDataWrittenToMemoryStreamKey], @"bzip+unbzip");
    XCTAssertEqualObjects(pldata, [resultStream4 propertyForKey:NSStreamDataWrittenToMemoryStreamKey], @"gzip+gunzip");
    
}

- (void)testPipeRunloopEarlyExit
{
#ifndef DEBUG_wiml
    if ([OFVersionNumber isOperatingSystemSierraOrLater]) {
        NSLog(@"*** Skipping, see bug:///138077 (Frameworks-Mac Unassigned: OFFilterProcess hanging on 10.12) ***");
        return;
    }
#endif

    NSRunLoop *l = [NSRunLoop currentRunLoop];
    NSOutputStream *resultStream;
    OFFilterProcess *proc;
    
    resultStream = [NSOutputStream outputStreamToMemory];
    proc = [[OFFilterProcess alloc] initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        @"/bin/sh", OFFilterProcessCommandPathKey,
                                                        [NSArray arrayWithObjects:@"-c", @"echo okay", nil], OFFilterProcessArgumentsKey,
                                                        [NSData data], OFFilterProcessInputDataKey,
                                                        @"NO", OFFilterProcessDetachTTYKey,
                                                        nil]
                                        standardOutput:resultStream
                                         standardError:nil];
    
    /* Wait long enough for the subprocess to exit */
    usleep(250000);
    
    [proc scheduleInRunLoop:l forMode:NSRunLoopCommonModes];
    
    do {
        [l runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
    } while ([proc isRunning]);
    
    [proc removeFromRunLoop:l forMode:NSRunLoopCommonModes];
    
    XCTAssertNil(proc.error);
    XCTAssertEqualObjects([resultStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey], [NSData dataWithBytes:"okay\n" length:5]);
    
    resultStream = [NSOutputStream outputStreamToMemory];
    proc = [[OFFilterProcess alloc] initWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        @"/bin/sh", OFFilterProcessCommandPathKey,
                                                        [NSArray arrayWithObjects:@"-c", @"echo okay; exit 12", nil], OFFilterProcessArgumentsKey,
                                                        [NSData data], OFFilterProcessInputDataKey,
                                                        @"NO", OFFilterProcessDetachTTYKey,
                                                        nil]
                                        standardOutput:resultStream
                                         standardError:nil];
    
    /* Wait long enough for the subprocess to exit */
    usleep(250000);
    
    [proc scheduleInRunLoop:l forMode:NSRunLoopCommonModes];
    
    do {
        [l runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
    } while ([proc isRunning]);
    
    [proc removeFromRunLoop:l forMode:NSRunLoopCommonModes];
    
    XCTAssertNotNil(proc.error);
    XCTAssertEqual([proc.error.userInfo intForKey:OFProcessExitStatusErrorKey], 12);
    XCTAssertEqualObjects([resultStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey], [NSData dataWithBytes:"okay\n" length:5]);
}

- (void)testPipeFailure
{
    NSData *smallData   = [NSData dataWithBytes:"Just remember ... wherever you go ... there you are." length:52];
    NSError *errbuf;
    
    errbuf = nil;
    XCTAssertNil([smallData filterDataThroughCommandAtPath:@"/usr/bin/false" withArguments:[NSArray array] error:&errbuf], @"command should fail");
    XCTAssertNotNil(errbuf, @"");
    //NSLog(@"fail w/ exit status: %@", errbuf);
    
    errbuf = nil;
    XCTAssertNil([smallData filterDataThroughCommandAtPath:@"/bin/quux-nonexist" withArguments:[NSArray array] error:&errbuf], @"command should fail");
    XCTAssertNotNil(errbuf, @"");
    //NSLog(@"fail w/ exec failure: %@", errbuf);
    
    errbuf = nil;
    XCTAssertNil([smallData filterDataThroughCommandAtPath:@"/bin/sh" withArguments:([NSArray arrayWithObjects:@"-c", @"kill -USR1 $$", nil]) error:&errbuf], @"command should fail");
    XCTAssertNotNil(errbuf, @"");
    NSLog(@"fail w/ signal: %@", errbuf);
    XCTAssertEqual((int)[[[[errbuf userInfo] objectForKey:NSUnderlyingErrorKey] userInfo] intForKey:OFProcessExitSignalErrorKey], (int)SIGUSR1, @"properly collected exit status");
    
    errbuf = nil;
    XCTAssertEqualObjects([NSData data],
                         [smallData filterDataThroughCommandAtPath:@"/usr/bin/true" withArguments:[NSArray array] error:&errbuf], @"command should succeed without output");
    XCTAssertNil(errbuf, @"");
}

/* This is really a test of OFFilterProcess, but the main use of that class is for filtering NSDatas, so it's here */
- (void)testFilterEnv
{
    BOOL ok;
    NSData *outBuf, *errBuf;
    NSError *err;
    
    
    /* Invoke printenv, and make sure it sees the additional environment variables we set */
    outBuf = nil;
    errBuf = nil;
    err = nil;
    ok = [OFFilterProcess runWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin/printenv", OFFilterProcessCommandPathKey,
                                             [NSArray array], OFFilterProcessArgumentsKey,
                                             [NSData data], OFFilterProcessInputDataKey,
                                             [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"BAR",
                                              [NSData dataWithBytes:"spoon" length:5], [NSData dataWithBytes:"TICK" length:4],
                                              nil], OFFilterProcessAdditionalEnvironmentKey,
                                             nil]
                                     inMode:nil standardOutput:&outBuf standardError:&errBuf error:&err];
    XCTAssertTrue(ok, @"running process 'printenv'");
    XCTAssertEqualObjects(errBuf, [NSData data], @"should produce no output on stderr");
    if (err) NSLog(@"error: %@", err);
    XCTAssertNil(err);
    NSString *outStr = [NSString stringWithData:outBuf encoding:NSASCIIStringEncoding];
    XCTAssertTrue([[outStr componentsSeparatedByString:@"\n"] containsObject:@"BAR=bar"], @"process environment contains string");
    XCTAssertTrue([[outStr componentsSeparatedByString:@"\n"] containsObject:@"TICK=spoon"], @"process environment contains string generated from NSData");
    
    /* Invoke printenv via the shell, with a $PATH that doesn't include printenv: case 1, replace entire environment */
    outBuf = nil;
    errBuf = nil;
    err = nil;
    ok = [OFFilterProcess runWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", OFFilterProcessCommandPathKey,
                                             [NSArray arrayWithObjects:@"-c", @"printenv", nil], OFFilterProcessArgumentsKey,
                                             [NSData data], OFFilterProcessInputDataKey,
                                             [NSDictionary dictionaryWithObjectsAndKeys:@"/tmp:/", @"PATH",
                                              nil], OFFilterProcessReplacementEnvironmentKey,
                                             nil]
                                     inMode:nil standardOutput:&outBuf standardError:&errBuf error:&err];
    XCTAssertFalse(ok, @"running process 'printenv'");
    // if (err) NSLog(@"error: %@", err);
    XCTAssertNotNil(err, @"should have returned an error to us");
    if(err) {
        XCTAssertEqualObjects([err domain], @"com.omnigroup.framework.OmniFoundation.ErrorDomain");
        XCTAssertEqual([err code], (NSInteger)OFFilterDataCommandReturnedErrorCodeError);
        XCTAssertTrue([[[err userInfo] objectForKey:OFProcessExitStatusErrorKey] intValue] > 0, @"should indicate process had nonzero exit");
    }
    XCTAssertFalse([errBuf isEqual:[NSData data]], @"captured stderr should be nonempty");
    
    
    /* Invoke printenv via the shell, using OFFilterProcessAdditionalPathEntryKey to ensure $PATH contains its path */
    outBuf = nil;
    errBuf = nil;
    err = nil;
    ok = [OFFilterProcess runWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", OFFilterProcessCommandPathKey,
                                             [NSArray arrayWithObjects:@"-c", @"printenv", nil], OFFilterProcessArgumentsKey,
                                             [NSData data], OFFilterProcessInputDataKey,
                                             [NSDictionary dictionaryWithObjectsAndKeys:@"/tmp:/", @"PATH",
                                              nil], OFFilterProcessReplacementEnvironmentKey,
                                             @"/usr/bin", OFFilterProcessAdditionalPathEntryKey,
                                             nil]
                                     inMode:nil standardOutput:&outBuf standardError:&errBuf error:&err];
    XCTAssertTrue(ok, @"running process 'printenv'");
    if (err) NSLog(@"error: %@", err);
    XCTAssertNil(err);
    XCTAssertEqualObjects(errBuf, [NSData data], @"should produce no output on stderr");
    outStr = [NSString stringWithData:outBuf encoding:NSASCIIStringEncoding];
    XCTAssertTrue([[outStr componentsSeparatedByString:@"\n"] containsObject:@"PATH=/tmp:/:/usr/bin"], @"process environment $PATH value");
    
    /* Invoke printenv via the shell, with a $PATH that doesn't include printenv: case 2, just override $PATH */
    outBuf = nil;
    errBuf = nil;
    err = nil;
    ok = [OFFilterProcess runWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", OFFilterProcessCommandPathKey,
                                             [NSArray arrayWithObjects:@"-c", @"printenv", nil], OFFilterProcessArgumentsKey,
                                             [NSData data], OFFilterProcessInputDataKey,
                                             [NSDictionary dictionaryWithObjectsAndKeys:@"/tmp:/", @"PATH",
                                              nil], OFFilterProcessAdditionalEnvironmentKey,
                                             nil]
                                     inMode:nil standardOutput:&outBuf standardError:&errBuf error:&err];
    XCTAssertFalse(ok, @"running process 'printenv'");
    // if (err) NSLog(@"error: %@", err);
    XCTAssertNotNil(err, @"should have returned an error to us");
    XCTAssertFalse([errBuf isEqual:[NSData data]], @"captured stderr should be nonempty");
    
    /* Invoke printenv via the shell, using OFFilterProcessAdditionalPathEntryKey to ensure $PATH contains its path: case 2 */
    outBuf = nil;
    errBuf = nil;
    err = nil;
    ok = [OFFilterProcess runWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", OFFilterProcessCommandPathKey,
                                             [NSArray arrayWithObjects:@"-c", @"printenv", nil], OFFilterProcessArgumentsKey,
                                             [NSData data], OFFilterProcessInputDataKey,
                                             [NSDictionary dictionaryWithObjectsAndKeys:@"/tmp:/", @"PATH",
                                              nil], OFFilterProcessAdditionalEnvironmentKey,
                                             @"/usr/bin", OFFilterProcessAdditionalPathEntryKey,
                                             nil]
                                     inMode:nil standardOutput:&outBuf standardError:&errBuf error:&err];
    XCTAssertTrue(ok, @"running process 'printenv'");
    if (err) NSLog(@"error: %@", err);
    XCTAssertNil(err);
    XCTAssertEqualObjects(errBuf, [NSData data], @"should produce no output on stderr");
    outStr = [NSString stringWithData:outBuf encoding:NSASCIIStringEncoding];
    XCTAssertTrue([[outStr componentsSeparatedByString:@"\n"] containsObject:@"PATH=/tmp:/:/usr/bin"], @"process environment $PATH value");
    
    /* Make sure that a redundant OFFilterProcessAdditionalPathEntryKey doesn't screw anything up */
    outBuf = nil;
    errBuf = nil;
    err = nil;
    ok = [OFFilterProcess runWithParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin/printenv", OFFilterProcessCommandPathKey,
                                             [NSArray array], OFFilterProcessArgumentsKey,
                                             [NSData data], OFFilterProcessInputDataKey,
                                             [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/tmp:/sbin:/usr/local/bin", @"PATH",
                                              nil], OFFilterProcessAdditionalEnvironmentKey,
                                             @"/tmp", OFFilterProcessAdditionalPathEntryKey,
                                             nil]
                                     inMode:nil standardOutput:&outBuf standardError:&errBuf error:&err];
    XCTAssertTrue(ok, @"running process 'printenv'");
    if (err) NSLog(@"error: %@", err);
    XCTAssertNil(err);
    XCTAssertEqualObjects(errBuf, [NSData data], @"should produce no output on stderr");
    outStr = [NSString stringWithData:outBuf encoding:NSASCIIStringEncoding];
    XCTAssertTrue([[outStr componentsSeparatedByString:@"\n"] containsObject:@"PATH=/usr/bin:/bin:/tmp:/sbin:/usr/local/bin"], @"process environment $PATH value");
}

- (void)testMergingStdoutAndStderr;
{
    NSError *error = nil;
    NSData *outputData = [[NSData data] filterDataThroughCommandAtPath:@"/bin/sh" withArguments:[NSArray arrayWithObjects:@"-c", @"echo foo; echo bar 1>&2", nil] includeErrorsInOutput:YES errorStream:nil error:&error];
    XCTAssertEqualObjects(outputData, [@"foo\nbar\n" dataUsingEncoding:NSUTF8StringEncoding], @"");
    XCTAssertTrue(error == nil, @"");
}

- (void)testSendingStderrToStream;
{
    // Errors go to the stream, output to the output data
    NSError *error = nil;
    NSOutputStream *errorStream = [NSOutputStream outputStreamToMemory];
    [errorStream open]; // Else, an error will result when writing to the stream
    
    NSData *outputData = [[NSData data] filterDataThroughCommandAtPath:@"/bin/sh" withArguments:[NSArray arrayWithObjects:@"-c", @"echo foo; echo bar 1>&2", nil] includeErrorsInOutput:NO errorStream:errorStream error:&error];
    
    XCTAssertEqualObjects(outputData, [@"foo\n" dataUsingEncoding:NSUTF8StringEncoding], @"");
    XCTAssertEqualObjects([errorStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey], [@"bar\n" dataUsingEncoding:NSUTF8StringEncoding], @"");
    XCTAssertTrue(error == nil, @"no error");
}

- (void)testAppendString
{
    NSData *d1 = [NSData dataWithBytesNoCopy:"foobar" length:6 freeWhenDone:NO];
    NSData *d2 = [NSData dataWithBytesNoCopy:"f\0o\0o\0\0b\0a\0r" length:12 freeWhenDone:NO];
    NSData *d3 = [NSData dataWithBytesNoCopy:"this\0that" length:9 freeWhenDone:NO];
    
    const unichar ch[5] = { 'i', 's', 0, 't', 'h' };
    NSString *st = [NSString stringWithCharacters:ch length:5];
    NSString *st2 = [NSString stringWithData:[st dataUsingEncoding:NSMacOSRomanStringEncoding] encoding:NSMacOSRomanStringEncoding];
    
    NSMutableData *buf;
    
    buf = [NSMutableData data];
    [buf appendString:@"foo" encoding:NSASCIIStringEncoding];
    [buf appendString:@"bar" encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(buf, d1, @"");
    
    buf = [NSMutableData data];
    [buf appendString:@"fo" encoding:NSISOLatin1StringEncoding];
    [buf appendString:@"obar" encoding:NSMacOSRomanStringEncoding];
    XCTAssertEqualObjects(buf, d1, @"");
    
    buf = [NSMutableData data];
    [buf appendString:@"foo" encoding:NSUTF16LittleEndianStringEncoding];
    [buf appendString:@"bar" encoding:NSUTF16BigEndianStringEncoding];
    XCTAssertEqualObjects(buf, d2, @"");
    
    buf = [NSMutableData data];
    [buf appendString:@"th" encoding:NSASCIIStringEncoding];
    [buf appendString:st encoding:NSASCIIStringEncoding];
    [buf appendString:@"at" encoding:NSASCIIStringEncoding];
    XCTAssertEqualObjects(buf, d3, @"");
    
    buf = [NSMutableData data];
    [buf appendString:@"th" encoding:NSASCIIStringEncoding];
    [buf appendString:st2 encoding:NSMacOSRomanStringEncoding];
    [buf appendString:@"at" encoding:NSASCIIStringEncoding];
    XCTAssertEqualObjects(buf, d3, @"");
    
}

@end
