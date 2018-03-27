// Copyright 1997-2010,2016 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <CoreFoundation/CFData.h>
#import <CoreFoundation/CFError.h>
#import <OmniBase/objc.h>

/// Compression container formats as might be found on disk.
/// Note that this does not include raw compressed streams like deflate, LZMA2, and LZ4, but does include files generated by compression utilities such as gzip, bzip2, and xz.
typedef CF_ENUM(unsigned int, OFCompressionContainerFormat) {
    OFCompression_None = 0,
    OFCompression_Gzip,      /// A deflate stream in an RFC1952 container
    OFCompression_Bzip2,     /// BZIP2
    OFCompression_XZ,        /// An LZMA2 stream inside an XZ container
};

// Compression
extern OFCompressionContainerFormat OFDataGuessCompressionContainer(CFDataRef data);
#define OFDataMightBeCompressed(data) (OFDataGuessCompressionContainer(data) != OFCompression_None)

extern CFDataRef OFDataCreateCompressedData(CFDataRef data, CFErrorRef *outError) CF_RETURNS_RETAINED;
extern CFDataRef OFDataCreateDecompressedData(CFAllocatorRef decompressedDataAllocator, CFDataRef data, CFErrorRef *outError) CF_RETURNS_RETAINED;

// Specific algorithms
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
extern CFDataRef OFDataCreateCompressedBzip2Data(CFDataRef data, CFErrorRef *outError) CF_RETURNS_RETAINED;
extern CFDataRef OFDataCreateDecompressedBzip2Data(CFAllocatorRef decompressedDataAllocator, CFDataRef data, CFErrorRef *outError) CF_RETURNS_RETAINED;
#endif

extern CFDataRef OFDataCreateCompressedGzipData(CFDataRef data, Boolean includeHeader, int level, CFErrorRef *outError) CF_RETURNS_RETAINED;
extern CFDataRef OFDataCreateDecompressedGzipData(CFAllocatorRef decompressedDataAllocator, CFDataRef data, Boolean expectHeader, CFErrorRef *outError) CF_RETURNS_RETAINED;
extern CFDataRef OFDataCreateDecompressedGzip2Data(CFAllocatorRef decompressedDataAllocator, CFDataRef data, CFErrorRef *outError) CF_RETURNS_RETAINED;
