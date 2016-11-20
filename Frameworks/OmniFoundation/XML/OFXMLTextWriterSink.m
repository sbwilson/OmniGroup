// Copyright 2009-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFXMLTextWriterSink.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#include <libxml/xmlwriter.h>

RCS_ID("$Id$");

static const xmlChar *getTerminatedStringBuf(NSString *nsstring, void **freeThis);
static void writeString(xmlTextWriter *writer, NSString *str);

static inline const xmlChar * __attribute__((const,always_inline)) castXmlChar(const char *s) 
{
    return (const xmlChar *)s;
}

@implementation OFXMLTextWriterSink
{
    xmlTextWriter *writer;
#ifdef DEBUG
    OFXMLMaker *currentElt;
#endif
}

// Init and dealloc

- initWithTextWriter:(struct _xmlTextWriter *)w freeWhenDone:(BOOL)shouldFree;
{
    if (!(self = [super init]))
        return nil;

    if (!w) {
        [self release];
        OBRejectInvalidCall(self, _cmd, @"NULL text writer passed to init");
    }
    
    writer = w;
    flags.freeWhenDone = shouldFree? 1 : 0;
#ifdef DEBUG
    currentElt = self;
#endif
    
    return self;
}

static int xmlOutToNSStream(void *ctxt, const char *buffer, int len)
{
    NSOutputStream *s = (NSOutputStream *)ctxt;
    return (int)[s write:(void *)buffer maxLength:len];
}
static int xmlOutToNSStreamEnd(void * ctxt)
{
    NSOutputStream *s = (NSOutputStream *)ctxt;
    [s close];
    [s release];
    return 0;
}

- (instancetype)initWithStream:(NSOutputStream *)outputStream;
{
    [outputStream open];
    void *ctxt = outputStream;
    xmlOutputBuffer *buf = xmlOutputBufferCreateIO(xmlOutToNSStream, xmlOutToNSStreamEnd, ctxt, xmlGetCharEncodingHandler(XML_CHAR_ENCODING_UTF8));
    [outputStream retain];
    xmlTextWriter *w = xmlNewTextWriter(buf);
    if (!(self = [self initWithTextWriter:w freeWhenDone:YES])) {
        xmlFreeTextWriter(w);
        return nil;
    }
    return self;
}

- (void)dealloc;
{
    if (writer && flags.freeWhenDone)
        xmlFreeTextWriter(writer);
    writer = nil;
    [super dealloc];
}

- (void)flush;
{
    xmlTextWriterFlush(writer);
}

/* XMLMaker API */

- (OFXMLMaker *)addEOL
{
    xmlTextWriterWriteString(writer, castXmlChar("\n"));
    return self;
}

- (void)close
{
    OBPRECONDITION(openChild == nil);
#ifdef DEBUG
    OBPRECONDITION(currentElt == self);
    currentElt = nil;
#endif

    xmlTextWriterEndDocument(writer);
    if (flags.freeWhenDone) {
        xmlFreeTextWriter(writer);
    }
    writer = nil;
}

/* XMLSink API */

- (void)addXMLDeclaration
{
    const char *encodingNameBuf;
    if (encodingName)
        encodingNameBuf = [encodingName cStringUsingEncoding:NSUTF8StringEncoding];
    else
        encodingNameBuf = NULL;

    /* xmlTextWriterStartDocument() both writes the <?xml ?> line *and* sets up the encoder on the output stream. */
    xmlTextWriterStartDocument(writer,
                               NULL,     /* XML version; leave at default of 1.0 */
                               encodingNameBuf,  /* output encoding to use and to declare */
                               flags.knowsStandalone? ( flags.isStandalone? "yes" : "no" ) : NULL);  /* optional standalone declaration */
}

- (void)addDoctype:(NSString *)rootElement identifiers:(NSString *)publicIdentifier :(NSString *)systemIdentifier;
{
    const xmlChar *rootElementBuf = castXmlChar([rootElement cStringUsingEncoding:NSUTF8StringEncoding]);
    const xmlChar *publicIdentifierBuf = castXmlChar([publicIdentifier cStringUsingEncoding:NSUTF8StringEncoding]);
    const xmlChar *systemIdentifierBuf = castXmlChar([systemIdentifier cStringUsingEncoding:NSUTF8StringEncoding]);
    
#if 0
    // Libxml versions before version 2.6.23 emit unparsable XML if you call xmlTextWriterWriteDTD().
    // Leopard is still using 2.6.16, released in 2004 (!) (see RADAR #6717520).
    xmlTextWriterWriteDTD(writer, rootElementBuf, publicIdentifierBuf, systemIdentifierBuf, NULL);
#else
    xmlTextWriterWriteRaw(writer, castXmlChar("<!DOCTYPE "));
    xmlTextWriterWriteRaw(writer, rootElementBuf);
    xmlTextWriterWriteRaw(writer, castXmlChar(" PUBLIC \""));
    xmlTextWriterWriteRaw(writer, publicIdentifierBuf);
    xmlTextWriterWriteRaw(writer, castXmlChar("\" \""));
    xmlTextWriterWriteRaw(writer, systemIdentifierBuf);
    xmlTextWriterWriteRaw(writer, castXmlChar("\">"));
#endif

    [self addEOL];
}

#ifdef DEBUG
- (void)beginOpenChild:(OFXMLMakerElement *)child of:(OFXMLMaker *)parent;
{
    OBPRECONDITION(currentElt == parent);
    currentElt = child;
    OBPOSTCONDITION(currentElt != nil);
}
#endif

- (void)finishOpenChild:(OFXMLMakerElement *)child attributes:(NSArray *)attributes values:(NSArray *)attributeValues empty:(BOOL)isEmpty;
{
#ifdef DEBUG
    OBINVARIANT(child == currentElt);
#endif

    void *buf;
    
    const xmlChar *tagName = getTerminatedStringBuf([child name], &buf);
    xmlTextWriterStartElement(writer, tagName);
    if(buf) free(buf);
        
    NSUInteger attributeCount = [attributes count], attributeIndex;
    if (attributeCount > 0) {
        for(attributeIndex = 0; attributeIndex < attributeCount; attributeIndex ++) {
            const xmlChar *attributeName = getTerminatedStringBuf([attributes objectAtIndex:attributeIndex], &buf);
            xmlTextWriterStartAttribute(writer, attributeName);
            if(buf) free(buf);
            
            writeString(writer, [attributeValues objectAtIndex:attributeIndex]);

            xmlTextWriterEndAttribute(writer);
        }
    }
        
    if (isEmpty) {
        // If isEmpty is YES, _closeOpenChild won't be called separately.
        xmlTextWriterEndElement(writer);
#ifdef DEBUG
        currentElt = [child parent]; // finish up what _beginOpenChild:of: did
#endif
    } else {
        // We may get some other nodes, which will be children of this node. Eventually followed by a _closeOpenChild for this node. Keep track of the node which will be the intervening nodes' parent.
    }
}

- (void)closeOpenChild:(OFXMLMakerElement *)child;
{
    OBPRECONDITION(child == currentElt);
    xmlTextWriterEndElement(writer);
#ifdef DEBUG
    currentElt = [child parent];
#endif
}


- (void)addString:(NSString *)aString of:(OFXMLMaker *)container asComment:(BOOL)isComment;
{
    OBASSERT(container == currentElt);
    
    if (isComment) {
        xmlTextWriterStartComment(writer);
        writeString(writer, aString);
        xmlTextWriterEndComment(writer);
    } else {
        writeString(writer, aString);
    }
}

@end

static const xmlChar *getTerminatedStringBuf(NSString *nsstring, void **freeThis)
{
    *freeThis = NULL;

    /* Most of the time, we're passing simple string literals into libxml for use in tag names and such, and this call will cheaply return the underlying cstring-like buffer. */
    const char *simple = CFStringGetCStringPtr((CFStringRef)(nsstring), kCFStringEncodingUTF8);
    if (simple) {
        return castXmlChar(simple);
    }
    
    /* Otherwise, we need to copy it out into a NUL-terminated buffer. */
    CFStringRef cfString = (__bridge CFStringRef)nsstring;
    CFIndex sourceStringLength = CFStringGetLength(cfString);
    CFIndex bufferSize = 0;

#ifdef OMNI_ASSERTIONS_ON
    CFIndex converted = 
#endif
    CFStringGetBytes(cfString, (CFRange){ .location = 0, .length = sourceStringLength }, kCFStringEncodingUTF8, 0, FALSE, NULL, 0, &bufferSize);
    
    OBASSERT(bufferSize > 0);
    OBASSERT(converted == sourceStringLength);
    UInt8 *buf = malloc( 1 + bufferSize );
    
#ifdef OMNI_ASSERTIONS_ON
    converted = 
#endif
    CFStringGetBytes(cfString, (CFRange){ .location = 0, .length = sourceStringLength }, kCFStringEncodingUTF8, 0, FALSE, buf, bufferSize, &bufferSize);
    OBASSERT(converted == sourceStringLength);
    buf[bufferSize] = 0;
    
    *freeThis = buf;
    return buf;
}

static void writeString(xmlTextWriter *writer, NSString *str)
{
    /* The simple case */
    const char *simple = CFStringGetCStringPtr((CFStringRef)(str), kCFStringEncodingUTF8);
    if (simple) {
        xmlTextWriterWriteString(writer, castXmlChar(simple));
        return;
    }
    
    /* TODO: This can't handle NULs in the string being written. There's no "with length" variant of xmlTextWriterWriteString(), so the only way to do that would be to handle all the entity encoding ourselves, and I'd rather not. */
    
    /* The complicated case */
#define CONV_BUF_SIZE 2048
    UInt8 buf[CONV_BUF_SIZE+1];
    CFStringRef cfString = (__bridge CFStringRef)str;
    CFIndex sourceStringLength = CFStringGetLength(cfString);
    CFIndex conversionLocation = 0;
    while(conversionLocation < sourceStringLength) {
        CFIndex bufferUsed = 0;
        CFIndex converted = CFStringGetBytes(cfString, (CFRange){ .location = conversionLocation, .length = sourceStringLength - conversionLocation }, kCFStringEncodingUTF8, 0, FALSE, buf, CONV_BUF_SIZE, &bufferUsed);
        OBASSERT(converted > 0);
        conversionLocation += converted;
        buf[bufferUsed] = 0;
        xmlTextWriterWriteString(writer, buf);
    }
}

