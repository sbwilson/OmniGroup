// Copyright 2005, 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-09-09/OmniGroup/Frameworks/OmniFoundation/XML/OFXMLBuffer.h 102862 2008-07-15 05:14:37Z bungi $

#import <Foundation/NSObject.h>
#import <CoreFoundation/CFString.h>

typedef struct _OFXMLBuffer *OFXMLBuffer;

extern OFXMLBuffer OFXMLBufferCreate(void);
extern void OFXMLBufferDestroy(OFXMLBuffer buf);

extern void OFXMLBufferAppendString(OFXMLBuffer buf, CFStringRef str);
extern void OFXMLBufferAppendASCIICString(OFXMLBuffer buf, const char *str);
extern void OFXMLBufferAppendSpaces(OFXMLBuffer buf, CFIndex count);

extern BOOL OFXMLBufferAppendUTF8Data(OFXMLBuffer buf, CFDataRef data, NSError **outError);

extern CFDataRef OFXMLBufferCopyData(OFXMLBuffer buf, CFStringEncoding encoding);
