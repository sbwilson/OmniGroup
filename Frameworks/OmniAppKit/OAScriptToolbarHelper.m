// Copyright 2002-2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAScriptToolbarHelper.h"

#import <AppKit/AppKit.h>
#import <Automator/Automator.h>
#import <Foundation/Foundation.h>
#import <OSAKit/OSAKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSImage-OAExtensions.h"
#import "NSToolbar-OAExtensions.h"
#import "NSFileManager-OAExtensions.h"
#import "OAApplication.h"
#import "OAToolbarItem.h"

RCS_ID("$Id$")

typedef void (^_RunItemCompletionHandler)(OAToolbarItem *toolbarItem, NSError *error);

@implementation OAScriptToolbarHelper
{
@private
    NSMutableDictionary *_pathForItemDictionary;
    NSMutableDictionary *_cachedScriptInfoDictionaries;
}

static BOOL OAScriptToolbarItemsDisabled = NO;

+ (void)setDisabled:(BOOL)disabled;
{
    OAScriptToolbarItemsDisabled = disabled;
}

- (id)init;
{
    if (!(self = [super init]))
        return nil;

    _pathForItemDictionary = [[NSMutableDictionary alloc] init];
    _cachedScriptInfoDictionaries = [[NSMutableDictionary alloc] init];

    return self;
}

- (NSString *)itemIdentifierExtension;
{
    return @"osascript";
}

- (NSString *)templateItemIdentifier;
{
    return @"OSAScriptTemplate";
}

- (NSArray *)scriptPaths;
{
    BOOL isSandboxed = [[NSProcessInfo processInfo] isSandboxed];
    
    // Applications running on 10.8 and later have access to NSUserScriptTask.
    // Sandboxed applications can only execute items from NSApplicationScriptsDirectory.
    
    if (isSandboxed) {
        NSURL *applicationScriptsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
        if (applicationScriptsDirectoryURL != nil && [applicationScriptsDirectoryURL checkResourceIsReachableAndReturnError:NULL]) {
            return [NSArray arrayWithObject:[applicationScriptsDirectoryURL path]];
        }
        
        return [NSArray array];
    }
    
    // Unsandboxed applications can execute scripts or workflows from any of the standard locations.

    NSMutableArray *scriptPaths = [NSMutableArray array];
    NSString *applicationSupportDirectoryName = [[OAApplication sharedApplication] applicationSupportDirectoryName];
    NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask & ~(NSSystemDomainMask), YES);
    for (NSString *libraryDirectory in libraryDirectories) {
        NSString *scriptDirectory = [libraryDirectory stringByAppendingPathComponent:@"Scripts"];
        scriptDirectory = [scriptDirectory stringByAppendingPathComponent:@"Applications"];
        scriptDirectory = [scriptDirectory stringByAppendingPathComponent:applicationSupportDirectoryName];
        [scriptPaths addObject:scriptDirectory];
    }

    NSString *bundledScriptsPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Scripts"];
    [scriptPaths addObject:bundledScriptsPath];
    
    return scriptPaths;
}

- (NSArray *)allowedItems;
{
    [self _scanItems];
    return [_pathForItemDictionary allKeys];
}

- (NSString *)pathForItem:(NSToolbarItem *)item;
{
    [self _scanItems];
    return [_pathForItemDictionary objectForKey:[item itemIdentifier]];
}

- (NSToolbarItem *)finishSetupForToolbarItem:(NSToolbarItem *)toolbarItem toolbar:(NSToolbar *)toolbar willBeInsertedIntoToolbar:(BOOL)willInsert;
{
    if (OAScriptToolbarItemsDisabled)
        return nil;

    // <bug:///89032> (Update OAScriptToolbarHelper to use non-deprecated API)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *path = [self pathForItem:toolbarItem];
    if (path == nil) {
        return nil;
    }
    
    path = [path stringByExpandingTildeInPath];

    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(executeScriptItem:)];

    NSString *typename = [[NSWorkspace sharedWorkspace] typeOfFile:path error:NULL];
    OBASSERT_NOTNULL(typename);
    BOOL isAutomatorWorfklow = [[NSWorkspace sharedWorkspace] type:typename conformsToType:@"com.apple.automator-workflow"];

    if (isAutomatorWorfklow) {
        OAToolbarWindowController *windowController = (OAToolbarWindowController *)[toolbar delegate];
        OBASSERT([windowController isKindOfClass:[OAToolbarWindowController class]]);
        NSDictionary *localizedToolbarInfo = [windowController localizedToolbarInfoForItem:@"AutomatorWorkflowTemplate"];
        OBASSERT_NULL(localizedToolbarInfo);
        NSArray *keys = @[@"label", @"paletteLabel", @"toolTip"];
        for (NSString *key in keys) {
            NSString *format = [localizedToolbarInfo objectForKey:key];
            NSString *value = [NSString stringWithFormat:format, [self _stringByRemovingScriptFilenameExtension:[path lastPathComponent]]];
            [toolbarItem setValue:value forKey:key];
        }
    } else {
        [toolbarItem setLabel:[self _stringByRemovingScriptFilenameExtension:[toolbarItem label]]];
        [toolbarItem setPaletteLabel:[self _stringByRemovingScriptFilenameExtension:[toolbarItem paletteLabel]]];
        [toolbarItem setToolTip:[self _stringByRemovingScriptFilenameExtension:[toolbarItem toolTip]]];
    }
    
    BOOL hasCustomIcon = NO;
    FSRef fsref;
    if (CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:path], &fsref)) {
        FSCatalogInfo catalogInfo;
        if (FSGetCatalogInfo(&fsref, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL) == noErr) {
            if ((((FileInfo *)(&catalogInfo.finderInfo))->finderFlags & kHasCustomIcon) != 0) {
                hasCustomIcon = YES;
                [toolbarItem setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
            }
        }
    }

    if (!hasCustomIcon) {
        if (isAutomatorWorfklow) {
            [toolbarItem setImage:[NSImage imageNamed:@"OAAutomatorWorkflowIconTemplate" inBundle:OMNI_BUNDLE]];
        } else {
            [toolbarItem setImage:[NSImage imageNamed:@"OAScriptIconTemplate" inBundle:OMNI_BUNDLE]];
        }
    }
#pragma clang diagnostic pop

    return toolbarItem;
}

- (void)executeScriptItem:(id)sender;
{
    OBRetainAutorelease(sender);
    OAToolbarItem *toolbarItem = sender;
    
    OAToolbarWindowController *windowController = (OAToolbarWindowController *)[[toolbarItem toolbar] delegate];
    OBASSERT(!windowController || [windowController isKindOfClass:[OAToolbarWindowController class]]);
    OBRetainAutorelease(windowController);  // The script may cause the window to be closed

    if ([windowController respondsToSelector:@selector(scriptToolbarItemShouldExecute:)] && ![windowController scriptToolbarItemShouldExecute:sender]) {
	return;
    }

    _RunItemCompletionHandler completionHandler = ^(OAToolbarItem *toolbarItem_, NSError *error) {
	if ([windowController respondsToSelector:@selector(scriptToolbarItemFinishedExecuting:)]) {
	    [windowController scriptToolbarItemFinishedExecuting:toolbarItem_];
        }
    };
    
    // TODO: We seem to always be sandboxed now? If so, the unsandboxed paths below could go away, taking a deprecation warning along with them. <bug:///122264> (Unassigned: Remove the non-sandboxed code path from -[OAScriptToolbarHelper executeScriptItem:]). 
    BOOL isSandboxed = [[NSProcessInfo processInfo] isSandboxed];
    NSString *itemPath = [[self pathForItem:sender] stringByExpandingTildeInPath];
    NSString *typename = [[NSWorkspace sharedWorkspace] typeOfFile:itemPath error:NULL];

    // Once we require 10.8 and later, we can collapse these code paths down to just the "sandboxed" version.
    // The sandboxed version uses 10.8 and later API, but that API also works in unsandboxed applications.
    // We'd give up our compiled script cache, but that isn't really buying us a lot in terms of performance, and may cause persistent properties to get out of sync if the scripts are ever run outside of the app while they are in our cache.
    
    OBASSERT_NOTNULL(typename);
    if ([[NSWorkspace sharedWorkspace] type:typename conformsToType:@"com.apple.automator-workflow"]) {
        if (isSandboxed) {
            [self _sandboxedExecuteAutomatorWorkflowForToolbarItem:toolbarItem inWindowController:windowController completionHandler:completionHandler];
        } else {
            [self _unsandboxedExecuteAutomatorWorkflowForToolbarItem:toolbarItem inWindowController:windowController completionHandler:completionHandler];
        }
    } else {
        if (isSandboxed) {
            [self _sandboxedExecuteOSAScriptForToolbarItem:toolbarItem inWindowController:windowController completionHandler:completionHandler];
        } else {
            [self _unsandboxedExecuteOSAScriptForToolbarItem:toolbarItem inWindowController:windowController completionHandler:completionHandler];
        }
    }
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
{
    return !OAScriptToolbarItemsDisabled;
}

#pragma mark -
#pragma mark Private

- (OSAScript *)_compiledScriptForPath:(NSString *)path errorInfo:(NSDictionary **)errorInfo;
{
    static NSString *ScriptInfoCompiledScriptKey = @"ScriptInfoCompiledScriptKey";
    static NSString *ScriptInfoModificationDateKey = @"ScriptInfoModificationDateKey";
    
    if (errorInfo != NULL) {
        *errorInfo = nil;
    }
    
    NSDictionary *scriptFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    NSDate *scriptModificationDate = [scriptFileAttributes fileModificationDate];
    
    OBASSERT_NOTNULL(scriptModificationDate); // clang can't tell that this shouldn't happen
    
    NSDictionary *cachedScriptInfoDictionary = [_cachedScriptInfoDictionaries objectForKey:path];
    if (cachedScriptInfoDictionary == nil || OFNOTEQUAL(scriptModificationDate, [cachedScriptInfoDictionary objectForKey:ScriptInfoModificationDateKey])) {
        // We don't have a cached script yet, or the script has been modified since it was cached
        OSAScript *compiledScript = [[OSAScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:errorInfo];
        NSMutableDictionary *scriptInfoDictionary = [NSMutableDictionary dictionary];
        [scriptInfoDictionary setObject:compiledScript forKey:ScriptInfoCompiledScriptKey defaultObject:nil];
        [scriptInfoDictionary setObject:scriptModificationDate forKey:ScriptInfoModificationDateKey defaultObject:nil];
        [_cachedScriptInfoDictionaries setObject:scriptInfoDictionary forKey:path];
        cachedScriptInfoDictionary = scriptInfoDictionary;
    }
    
    return [cachedScriptInfoDictionary objectForKey:ScriptInfoCompiledScriptKey];
}

- (void)_scanItems;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *scriptTypes = [self _scriptTypes];
    
    // Remove all existing items before rescanning
    [_pathForItemDictionary removeAllObjects];
    
    [self _scriptFilenameExtensions];

    for (NSString *scriptFolder in [self scriptPaths]) {
        for( NSString *filename in [fileManager directoryContentsAtPath:scriptFolder ofTypes:scriptTypes deep:NO fullPath:NO error:NULL]) {
	    // Don't register more than one script with the same name.
            // This means you won't be able to have toolbar items of different script types with the same name.
            NSString *itemName = [self _stringByRemovingScriptFilenameExtension:filename];
            NSString *itemIdentifier = [itemName stringByAppendingPathExtension:[self itemIdentifierExtension]];
            if ([_pathForItemDictionary objectForKey:itemIdentifier] == nil) {
                NSString *path = [[scriptFolder stringByAppendingPathComponent:filename] stringByAbbreviatingWithTildeInPath];
                [_pathForItemDictionary setObject:path forKey:itemIdentifier];
            }
        }
    }
}

- (NSArray *)_scriptTypes;
{
    static NSArray *scriptTypes = nil;
    
    if (scriptTypes == nil) {
        // Note that text scripts and compiled scripts do not conform to each other.
        NSMutableArray *types = [NSMutableArray array];
        [types addObjects:@"com.apple.applescript.text", @"com.apple.applescript.script", @"com.apple.automator-workflow", nil];
        
        CFArrayRef scriptBundleUTIs = UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, CFSTR("scptd"), NULL);
        if (scriptBundleUTIs != NULL) {
            [types addObjectsFromArray:(__bridge NSArray *)scriptBundleUTIs];
            CFRelease(scriptBundleUTIs);
        }
        
        scriptTypes = [types copy];
    }
    
    return scriptTypes;
}

- (NSArray *)_scriptFilenameExtensions;
{
    static NSArray *scriptFilenameExtensions = nil;
    
    if (scriptFilenameExtensions == nil) {
        scriptFilenameExtensions = [[NSArray alloc] initWithObjects:
            @"workflow",
            @"applescript",
            @"scptd",
            @"scpt",
            nil
        ];
    }
    
    return scriptFilenameExtensions;
}

- (NSString *)_stringByRemovingScriptFilenameExtension:(NSString *)string;
{
    NSString *extension = [string pathExtension];
    if ([[self _scriptFilenameExtensions] containsObject:extension]) {
        NSString *suffix = [NSString stringWithFormat:@".%@", extension];
        return [string stringByRemovingSuffix:suffix];
    }
    
    return string;
}

- (void)_sandboxedExecuteAutomatorWorkflowForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController completionHandler:(_RunItemCompletionHandler)completionHandler;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    NSURL *url = [NSURL fileURLWithPath:path];
    
    NSError *taskError = nil;
    NSUserAutomatorTask *task = [[NSUserAutomatorTask alloc] initWithURL:url error:&taskError];
    if (task == nil) {
        [self _handleAutomatorWorkflowLoadErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:[taskError localizedDescription]];
        completionHandler(toolbarItem, taskError);
        return;
    }
    
    [task executeWithInput:nil completionHandler:^(id result, NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (error != nil) {
                [self _handleAutomatorWorkflowExecutionErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:[error localizedDescription]];
            }
            completionHandler(toolbarItem, error);
        }];
    }];
}

- (void)_sandboxedExecuteOSAScriptForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController completionHandler:(_RunItemCompletionHandler)completionHandler;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    if (!path) {
        // This can happen if the user removes a script while the app is running.
        NSLog(@"No script found for toolbar item %@", toolbarItem.itemIdentifier);
        NSBeep();
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    
    NSError *taskError = nil;
    NSUserAppleScriptTask *task = [[NSUserAppleScriptTask alloc] initWithURL:url error:&taskError];
    if (task == nil) {
        [self _handleOSAScriptLoadErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:[taskError localizedDescription]];
        completionHandler(toolbarItem, taskError);
        return;
    }
    
    NSAppleEventDescriptor *event = nil;

    if ([windowController respondsToSelector:@selector(scriptToolbarItemArguments:)]) {
        NSAppleEventDescriptor *arguments = [windowController scriptToolbarItemArguments:toolbarItem];
        if (arguments != nil) {
            if ([arguments descriptorType] != cAEList) {
                arguments = [arguments coerceToDescriptorType:cAEList];
                OBASSERT_NOTNULL(arguments);
            }
        }
        
        if (arguments != nil) {
            event = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenApplication targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
            [event setParamDescriptor:arguments forKeyword:keyDirectObject];
        }
    }

    [task executeWithAppleEvent:event completionHandler:^(NSAppleEventDescriptor *result, NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (error != nil) {
                [self _handleOSAScriptExecutionErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:[error localizedDescription]];
            }
            completionHandler(toolbarItem, error);
        }];
    }];
}

- (void)_unsandboxedExecuteAutomatorWorkflowForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController completionHandler:(_RunItemCompletionHandler)completionHandler;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    NSURL *url = [NSURL fileURLWithPath:path];

    NSError *error = nil;
    id result = [AMWorkflow runWorkflowAtURL:url withInput:nil error:&error];
    if (result == nil) {
        [self _handleAutomatorWorkflowExecutionErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:[error localizedDescription]];
    }
    
    completionHandler(toolbarItem, error);
}

- (void)_unsandboxedExecuteOSAScriptForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController completionHandler:(_RunItemCompletionHandler)completionHandler;
{
    NSDictionary *errorDictionary = nil;
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    OSAScript *script = [self _compiledScriptForPath:path errorInfo:&errorDictionary];

    if (script == nil) {
        [self _handleOSAScriptLoadErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:[errorDictionary objectForKey:OSAScriptErrorMessage]];

        // Should probably pass en error through to the completion handler, but it is not currently unused
        completionHandler(toolbarItem, nil);
        return;
    }
    
    NSAppleEventDescriptor *result = nil;
    NSAppleEventDescriptor *arguments = nil;

    if (![windowController respondsToSelector:@selector(scriptToolbarItemArguments:)] || !(arguments = [windowController scriptToolbarItemArguments:toolbarItem])) {
        result = [script executeAndReturnError:&errorDictionary];
    } else {
        if ([arguments descriptorType] != cAEList) {
            // Scripts expect to be given a list of arguments (though for some reason "run script aScriptObj" will give them a reference to the script object, rather than a list)
            arguments = [arguments coerceToDescriptorType:cAEList];
            OBASSERT_NOTNULL(arguments);
        }

        NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenApplication targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
        [event setParamDescriptor:arguments forKeyword:keyDirectObject];
        result = [script executeAppleEvent:event error:&errorDictionary];
    }
    
    if (result == nil) {
        NSString *errorText = [errorDictionary objectForKey:OSAScriptErrorMessage];
        [self _handleOSAScriptExecutionErrorForToolbarItem:toolbarItem inWindowController:windowController errorText:errorText];

        // Should probably pass en error through to the completion handler, but it is not currently unused
        completionHandler(toolbarItem, nil);
        return;
    }
    
    // This might fail for a variety of reasons, but we don't consider that fatal
    if ([script isCompiled]) {
        // <bug:///124065> (Unassigned: Update saving of script toolbar items to pass the right storage type)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        [script writeToURL:[NSURL fileURLWithPath:path] ofType:nil error:&errorDictionary];
#pragma clang diagnostic pop
    }

    completionHandler(toolbarItem, nil);
}

- (void)_handleAutomatorWorkflowLoadErrorForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController errorText:(NSString *)errorText;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    NSString *scriptName = [[NSFileManager defaultManager] displayNameAtPath:path];
    
    NSString *messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The Automator Workflow \"%@\" could not be opened.", @"OmniAppKit", [OAScriptToolbarHelper bundle], "Automator Workflow loading error"), scriptName];
    NSString *informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Automator reported the following error:\n%@", @"OmniAppKit", [OAScriptToolbarHelper bundle], "Automator Workflow error message"), errorText];
    NSString *OKButtonTitle = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = messageText;
    alert.informativeText = informativeText;
    [alert addButtonWithTitle:OKButtonTitle];
    [alert beginSheetModalForWindow:[windowController window] completionHandler:nil];
}

- (void)_handleAutomatorWorkflowExecutionErrorForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController errorText:(NSString *)errorText;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    NSString *scriptName = [[NSFileManager defaultManager] displayNameAtPath:path];
    
    NSString *messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The Automator Workflow \"%@\" could not complete.", @"OmniAppKit", [OAScriptToolbarHelper bundle], "Automator Workflow execute error"), scriptName];
    NSString *informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Automator reported the following error:\n\n%@", @"OmniAppKit", [OAScriptToolbarHelper bundle], "Automator Workflow execute error message"), errorText];
    NSString *OKButtonTitle = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
    NSString *editButtonTitle = NSLocalizedStringFromTableInBundle(@"Edit Workflow", @"OmniAppKit", [OAScriptToolbarHelper bundle], "Automatork workflow error panel button");
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = messageText;
    alert.informativeText = informativeText;
    [alert addButtonWithTitle:OKButtonTitle];
    [alert addButtonWithTitle:editButtonTitle];

    [alert beginSheetModalForWindow:[windowController window] completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            [[NSWorkspace sharedWorkspace] openFile:path];
        }
    }];
}

- (void)_handleOSAScriptLoadErrorForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController errorText:(NSString *)errorText;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    NSString *scriptName = [[NSFileManager defaultManager] displayNameAtPath:path];

    NSString *messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The script file \"%@\" could not be opened.", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script loading error"), scriptName];
    NSString *informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"AppleScript reported the following error:\n%@", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script loading error message"), errorText];
    NSString *OKButtonTitle = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = messageText;
    alert.informativeText = informativeText;
    [alert addButtonWithTitle:OKButtonTitle];
    [alert beginSheetModalForWindow:[windowController window] completionHandler:nil];
}

- (void)_handleOSAScriptExecutionErrorForToolbarItem:(OAToolbarItem *)toolbarItem inWindowController:(OAToolbarWindowController *)windowController errorText:(NSString *)errorText;
{
    NSString *path = [[self pathForItem:toolbarItem] stringByExpandingTildeInPath];
    NSString *scriptName = [[NSFileManager defaultManager] displayNameAtPath:path];

    NSString *messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The script \"%@\" could not complete.", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script execute error"), scriptName];
    NSString *informativeText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"AppleScript reported the following error:\n\n%@", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script execute error message"), errorText];
    NSString *OKButtonTitle = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
    NSString *editButtonTitle = NSLocalizedStringFromTableInBundle(@"Edit Script", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = messageText;
    alert.informativeText = informativeText;
    [alert addButtonWithTitle:OKButtonTitle];
    [alert addButtonWithTitle:editButtonTitle];

    [alert beginSheetModalForWindow:[windowController window] completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            [[NSWorkspace sharedWorkspace] openFile:path];
        }
    }];
}

@end

@implementation OAToolbarWindowController (OAScriptToolbarHelperExtensions)

- (NSAppleEventDescriptor *)scriptToolbarItemArguments:(OAToolbarItem *)item;
{
    NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor listDescriptor];
    [descriptor insertDescriptor:[[[self window] objectSpecifier] descriptor] atIndex:0]; // 0 means "at the end"
    return descriptor;
}

@end
