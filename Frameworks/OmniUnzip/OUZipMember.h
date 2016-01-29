// Copyright 2008-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <OmniFoundation/OFObject.h>

@class NSFileWrapper, NSFileManager;
@class OUZipArchive;

NS_ASSUME_NONNULL_BEGIN

@interface OUZipMember : OFObject

- (instancetype)initWithFileWrapper:(NSFileWrapper *)fileWrapper; // Returns an instance of the appropriate subclass
- (NSFileWrapper *)fileWrapperRepresentation; // Returns a new autoreleased file wrapper; won't return the same wrapper on multiple calls

- (instancetype)initWithPath:(NSString *)path fileManager:(NSFileManager *)fileManager;

- (instancetype)initWithName:(NSString *)name date:(NSDate *)date; // Assumes that you won't create a duplicate/bad name within a parent (case conflicts, embedded '/', etc.)

@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSDate *date;

- (BOOL)appendToZipArchive:(OUZipArchive *)zip fileNamePrefix:(NSString * _Nullable)fileNamePrefix error:(NSError **)outError;

- (NSComparisonResult)localizedCaseInsensitiveCompareByName:(OUZipMember *)otherMember;

@end

NS_ASSUME_NONNULL_END
