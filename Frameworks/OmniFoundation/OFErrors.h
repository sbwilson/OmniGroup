// Copyright 2007-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSError.h> // NSLocalizedDescriptionKey

@class NSString;

enum {
    // Zero typically means no error
    OFCacheFileUnableToWriteError = 1,
    OFFilterDataCommandReturnedErrorCodeError,
    OFUnableToCreatePathError,
    OFUnableToSerializeLockFileDictionaryError,
    OFUnableToCreateLockFileError,
    OFCannotFindTemporaryDirectoryError,
    OFCannotExchangeFileError,
    OFCannotUniqueFileNameError,
    
    OFXMLLibraryError, // An error from libxml; might be a warning, might be fatal.
    OFXMLDocumentNoRootElementError,
    OFXMLCannotCreateStringFromUnparsedData,
    
    OFInvalidHexDigit,
    
    OFXMLReaderCannotCreateInputStream,
    OFXMLReaderCannotCreateXMLInputBuffer,
    OFXMLReaderCannotCreateXMLReader,
    OFXMLReaderUnexpectedNodeType,
    OFXMLReaderEndOfFile,

    OFUnableToCompressData,
    OFUnableToDecompressData,
    
    OFXMLSignatureValidationError,    // Signature information could not be parsed
    OFXMLSignatureValidationFailure,  // Signature information could be parsed, but did not validate
    OFXMLInvalidateInputError,        // Empty, nil, or otherwise invalid input to the XML parser
    OFASN1Error,                      // Problem parsing an ASN.1 BER or DER encoded value
    OFKeyNotAvailable,                // An encryption key or passphrase isn't available
    OFKeyNotApplicable,               // This encryption key (e.g. password) doesn't match the thing it's decrypting.
    OFUnsupportedCMSFeature,          // Some CMS identifier or version is unknown or not supported by us
    OFCMSFormatError,                 // CMS structure is wrong, somehow
    OFEncryptedDocumentFormatError,   // Omni document-based-app encrypted document structure or format is wrong somehow (often has a suberror)
    
    OFNetStateRegistrationCannotCreateSocket,
    
    OFSyncClientStateInvalidPropertyList,
    
    // OFLockFile
    OFLockInvalidated,
    OFLockUnavailable,
    OFCannotCreateLock,
    
    // NSFileManager(OFExtensions) - these are unused in builds targeting 10.10 and later
    OFCannotGetQuarantineProperties,
    OFCannotSetQuarantineProperties,
    
    // OFHandleChangeDebugLevelURL
    OFChangeDebugLevelURLError,
};


// This key holds the exit status of a process which has exited
#define OFProcessExitStatusErrorKey (@"OFExitStatus")
#define OFProcessExitSignalErrorKey (@"OFExitSignal")

extern NSString * const OFErrorDomain;

#define OFErrorWithInfoAndDomain(error, domain, code, description, suggestion, ...) _OBError(error, domain, code, __FILE__, __LINE__, NSLocalizedDescriptionKey, description, NSLocalizedRecoverySuggestionErrorKey, (suggestion), ## __VA_ARGS__)
#define OFErrorWithInfo(error, code, description, suggestion, ...) OFErrorWithInfoAndDomain(error, OFErrorDomain, code, description, (suggestion), ## __VA_ARGS__)
#define OFError(error, code, description, reason) OFErrorWithInfo((error), (code), (description), (reason), nil)
