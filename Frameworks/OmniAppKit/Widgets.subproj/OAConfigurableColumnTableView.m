// Copyright 1997-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/OAConfigurableColumnTableView.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Id$")

@interface NSTableView (PrivateParts)
- (void)_writePersistentTableColumns;
@end


@interface OAConfigurableColumnTableView (PrivateAPI)
- (void)_commonInit;
- (void)_buildConfigurationMenu;
- (void)_addItemWithTableColumn:(NSTableColumn *)column dataSource: (id) dataSource;
- (NSMenuItem *)_itemForTableColumn: (NSTableColumn *) column;
- (void)_toggleColumn:(id)sender;
@end


/*"
Note that this class cannot have a 'deactivateTableColumns' ivar to store the inactive columns.  The problem with that is that if NSTableView's column position/size saving code is turned on, it will blow away table columns that aren't listed in the default.  This can lead to out-of-sync problems.

Also note that this class doesn't subclass -addTableColumn: and -removeTableColumn to update the popup.
"*/

@implementation OAConfigurableColumnTableView

//
// NSObject subclass
//

- initWithCoder:(NSCoder *)coder;
{
    if (!(self = [super initWithCoder:coder]))
        return nil;

    [self _commonInit];

    return self;
}

//
// NSView subclass
//

- initWithFrame:(NSRect)frame;
{
    if (!(self = [super initWithFrame:frame]))
        return nil;

    [self _commonInit];
    
    return self;
}

- (NSMenu *)menuForEvent:(NSEvent *)event;
{
    return configurationMenu;
}

//
// NSTableView subclass
//

// We want this method to search both active and inactive columns (OOM depends upon this).  Neither the configuration menu nor the tableColumns array is guaranteed to have all the items (the configuration menu will have all but those that cannot be configured and the tableColumns will have only the active columns).  This is on place where our strategy of not adding an ivar for 'all table columsn' is wearing thin.
- (NSTableColumn *)tableColumnWithIdentifier:(id)identifier;
{
    // First check the configuration menu
    for (NSMenuItem *item in [configurationMenu itemArray]) {
        NSTableColumn  *column = [item representedObject];
        if ([[column identifier] isEqual: identifier])
            return column;
    }

    // Then check the table view (since it might have unconfigurable columns)
    for (NSTableColumn *column in [self tableColumns]) {
        if ([[column identifier] isEqual: identifier])
            return column;
    }
    
    return nil;
}

- (void)setDataSource:(id <NSTableViewDataSource>)dataSource;
{
    [super setDataSource: dataSource];
    
    confDataSourceFlags.menuString     = [dataSource respondsToSelector: @selector(configurableColumnTableView:menuStringForColumn:)];
    confDataSourceFlags.addSeparator   = [dataSource respondsToSelector: @selector(configurableColumnTableView:shouldAddSeparatorAfterColumn:)];
    confDataSourceFlags.allowToggle    = [dataSource respondsToSelector: @selector(configurableColumnTableView:shouldAllowTogglingColumn:)];
    confDataSourceFlags.willActivate   = [dataSource respondsToSelector: @selector(configurableColumnTableView:willActivateColumn:)];
    confDataSourceFlags.didActivate    = [dataSource respondsToSelector: @selector(configurableColumnTableView:didActivateColumn:)];
    confDataSourceFlags.willDeactivate = [dataSource respondsToSelector: @selector(configurableColumnTableView:willDeactivateColumn:)];
    confDataSourceFlags.didDeactivate  = [dataSource respondsToSelector: @selector(configurableColumnTableView:didDeactivateColumn:)];

    // The new delegate may want to return different string
    [self _buildConfigurationMenu];
}

//
// New API
//

- (NSMenu *) configurationMenu;
{
    return configurationMenu;
}

- (NSArray *)inactiveTableColumns;
{
    NSMutableArray *inactiveTableColumns = [NSMutableArray array];
    
    for (NSMenuItem *item in [configurationMenu itemArray]) {
        NSTableColumn *column = [item representedObject];

        if (![self isTableColumnActive: column])
            [inactiveTableColumns addObject: column];
    }

    return inactiveTableColumns;
}

- (void)activateTableColumn:(NSTableColumn *)column;
{
    if ([[self tableColumns] indexOfObjectIdenticalTo:column] != NSNotFound)
        // Already active
        return;

    if (confDataSourceFlags.willActivate)
        [(id)[self dataSource] configurableColumnTableView: self willActivateColumn: column];
        
    NSMenuItem *item = [self _itemForTableColumn: column];
    [item setState:YES];
    
    [self addTableColumn:column];
    
    // workaround for rdar://4508650. [NSTableView {add,remove}TableColumn:] honor autosaveTableColumns.
    if ([self autosaveTableColumns] && [self autosaveName] != nil) {
        if ([self respondsToSelector:@selector(_writePersistentTableColumns)])
            [self _writePersistentTableColumns];
        else
            OBASSERT_NOT_REACHED("no _writePersistentTableColumns on NSTableView");
    }
        
    if (confDataSourceFlags.didActivate)
        [(id)[self dataSource] configurableColumnTableView: self didActivateColumn: column];
}

- (void)deactivateTableColumn:(NSTableColumn *)column;
{
    if ([[self tableColumns] indexOfObjectIdenticalTo:column] == NSNotFound)
        // Already inactive
        return;

    if (confDataSourceFlags.willDeactivate)
        [(id)[self dataSource] configurableColumnTableView: self willDeactivateColumn: column];
        
    NSMenuItem *item = [self _itemForTableColumn: column];
    [item setState:NO];
    
    [self removeTableColumn:column];

    // workaround for rdar://4508650. [NSTableView {add,remove}TableColumn:] honor autosaveTableColumns.
    if ([self autosaveTableColumns] && [self autosaveName] != nil) {
        if ([self respondsToSelector:@selector(_writePersistentTableColumns)])
            [self _writePersistentTableColumns];
        else
            OBASSERT_NOT_REACHED("no _writePersistentTableColumns on NSTableView");
    }
        
    if (confDataSourceFlags.didDeactivate)
        [(id)[self dataSource] configurableColumnTableView: self didDeactivateColumn: column];
}

- (void)toggleTableColumn:(NSTableColumn *)column;
{
    OBPRECONDITION(column);
    OBPRECONDITION([self _itemForTableColumn: column]);
    
    if ([self isTableColumnActive:column])
        [self deactivateTableColumn:column];
    else
        [self activateTableColumn:column];
    
    [self tile];
    [self sizeToFit]; // We don't need to check the -columnAutoresizingStyle, because -sizeToFit honors it
}

- (BOOL)isTableColumnActive:(NSTableColumn *)column;
{
    return [[self tableColumns] indexOfObject:column] != NSNotFound;
}

- (void)reloadData;
{
    [super reloadData];
    
    for (NSMenuItem *item in [configurationMenu itemArray]) {
        NSTableColumn *column = [item representedObject];
        [[self _itemForTableColumn:column] setState:[self isTableColumnActive:column]];
    }
}

@end


@implementation OAConfigurableColumnTableView (PrivateAPI)

- (void)_commonInit;
{
    [self _buildConfigurationMenu];
}

- (void)_buildConfigurationMenu;
{
    configurationMenu = nil;
    
    id dataSource = [self dataSource];
    if (!dataSource)
        return;

    configurationMenu = [[NSMenu alloc] initWithTitle: @"Configure Columns"];
        
    // Add items for all the columns.  For columsn that aren't currently displayed, this will be where we store the pointer to the column.
    for (NSTableColumn *column in [self tableColumns])
        [self _addItemWithTableColumn:column dataSource:dataSource];
}

- (void)_addItemWithTableColumn:(NSTableColumn *)column dataSource: (id) dataSource;
{
    // If we don't allow configuration, don't add the item to the menu
    if (confDataSourceFlags.allowToggle && ![dataSource configurableColumnTableView:self shouldAllowTogglingColumn:column])
        return;
    
    NSString *title = nil;
    if (confDataSourceFlags.menuString)
        title = [dataSource configurableColumnTableView:self menuStringForColumn:column];
    if (!title)
        title = [[column headerCell] stringValue];
        
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(_toggleColumn:) keyEquivalent: @""];
    [item setState:[self isTableColumnActive:column]];
    [item setRepresentedObject:column];
    [configurationMenu addItem: item];
    
    if (confDataSourceFlags.addSeparator && [dataSource configurableColumnTableView:self shouldAddSeparatorAfterColumn:column])
        [configurationMenu addItem: [NSMenuItem separatorItem]];
}

- (NSMenuItem *)_itemForTableColumn:(NSTableColumn *)column;
{
    for (NSMenuItem *item in [configurationMenu itemArray])
        if (column == [item representedObject])
            return item;
    return nil;
}

- (void)_toggleColumn:(id)sender;
{
    NSMenuItem *item = (NSMenuItem *)sender;
    OBASSERT([item isKindOfClass: [NSMenuItem class]]);

    [self toggleTableColumn:[item representedObject]];
}

@end
