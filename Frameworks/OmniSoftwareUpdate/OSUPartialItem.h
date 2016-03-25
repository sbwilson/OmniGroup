// Copyright 2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSObject.h>
#import <Foundation/NSXMLParser.h>

@interface OSUPartialItem : NSObject <NSXMLParserDelegate>

@property (nonatomic, strong) NSString *releaseNotesURLString;

-(instancetype)initWithXMLData:(NSData *)data;

@end
