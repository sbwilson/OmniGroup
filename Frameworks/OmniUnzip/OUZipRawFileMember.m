// Copyright 2008-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUnzip/OUZipRawFileMember.h>

#import <OmniUnzip/OUZipArchive.h>
#import <OmniUnzip/OUUnzipEntry.h>
#import <OmniUnzip/OUUnzipArchive.h>
#import <OmniUnzip/OUErrors.h>

RCS_ID("$Id$");

NS_ASSUME_NONNULL_BEGIN

@implementation OUZipRawFileMember

- (instancetype)initWithName:(NSString *)name entry:(OUUnzipEntry *)entry archive:(OUUnzipArchive *)archive;
{
    OBPRECONDITION(![NSString isEmptyString:name]);
    OBPRECONDITION(entry);
    OBPRECONDITION(archive);
    
    // TODO: OUUnzipEntry should have the date available.
    if (!(self = [super initWithName:name date:[NSDate date]]))
        return nil;
    
    _entry = entry;
    _archive = archive;
    
    return self;
}

- (instancetype)initWithEntry:(OUUnzipEntry *)entry archive:(OUUnzipArchive *)archive;
{
    return [self initWithName:[entry name] entry:entry archive:archive];
}

#pragma mark -
#pragma mark OUZipMember subclass

- (BOOL)appendToZipArchive:(OUZipArchive *)zip fileNamePrefix:(NSString * _Nullable)fileNamePrefix error:(NSError **)outError;
{
    BOOL result;
    NSError *resultError = nil;

    @autoreleasepool {
        __autoreleasing NSError *error;
        NSData *rawData = [_archive dataForEntry:_entry raw:YES error:&error];
        if (!rawData) {
            resultError = error; // strong-ify the error
            result = NO;
        } else {
            OBASSERT([rawData length] == [_entry compressedSize]);
            
            // TODO: propagate the data from the source zip file
            error = nil;
            result = [zip appendEntryNamed:[self name] fileType:[_entry fileType] contents:rawData raw:YES compressionMethod:[_entry compressionMethod] uncompressedSize:[_entry uncompressedSize] crc:[_entry crc] date:[_entry date] error:&error];
            if (!result) {
                resultError = error; // strong-ify the error
            }
        }
    }

    if (!result && outError)
        *outError = resultError;
    return result;
}

@end

NS_ASSUME_NONNULL_END
