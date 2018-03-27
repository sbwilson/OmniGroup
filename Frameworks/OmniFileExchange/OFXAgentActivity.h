// Copyright 2012-2014,2017 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <Foundation/NSObject.h>

@class OFXAgent, OFXServerAccount, OFXAccountActivity;

@interface OFXAgentActivity : NSObject

- initWithAgent:(OFXAgent *)agent;

@property(nonatomic,readonly) OFXAgent *agent;

- (OFXAccountActivity *)activityForAccount:(OFXServerAccount *)account;

@property(nonatomic,readonly) BOOL isActive; // YES if any account is syncing
@property(nonatomic,readonly,copy) NSSet <NSString *> *accountUUIDsWithErrors;
@property(nonatomic,readonly) NSDate *lastSyncDate;

- (void)eachAccountActivityWithError:(void (^)(OFXAccountActivity *accountActivity))applier;

@end
