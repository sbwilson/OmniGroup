// Copyright 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "ODOModel-SQL.h"

#import "ODODatabase-Internal.h"
#import "ODOEntity-SQL.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-09-09/OmniGroup/Frameworks/OmniDataObjects/ODOModel-SQL.m 104581 2008-09-06 21:18:23Z kc $")

@implementation ODOModel (SQL)

- (BOOL)_createSchemaInDatabase:(ODODatabase *)database error:(NSError **)outError;
{
    NSEnumerator *entityEnum;
    ODOEntity *entity;
    
    // Create the tables
    entityEnum = [_entitiesByName objectEnumerator];
    while ((entity = [entityEnum nextObject]))
        if (![entity _createSchemaInDatabase:database error:outError])
            return NO;
    
    // Create extra indexes
    entityEnum = [_entitiesByName objectEnumerator];
    while ((entity = [entityEnum nextObject]))
        if (![entity _createIndexesInDatabase:database error:outError])
            return NO;
    
    return YES;
}

@end


