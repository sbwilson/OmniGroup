// Copyright 2010-2019 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIViewController.h>
#import <OmniFileExchange/OFXServerAccount.h>

@class OUIImportExportAccountListViewController;

@interface OUIImportExportAccountListViewController : UITableViewController

- (instancetype)initForExporting:(BOOL)isExporting;

@property (copy, nonatomic) void (^finished)(OFXServerAccount *accountOrNil);

@end
