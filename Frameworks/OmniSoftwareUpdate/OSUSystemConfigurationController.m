// Copyright 2001-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSUSystemConfigurationController.h"

#import <WebKit/WebKit.h>
#import <OmniFoundation/OmniFoundation.h>
#import <mach-o/arch.h>
#import <OmniSoftwareUpdate/OSUProbe.h>
#import <OmniAppKit/OAController.h>

#import "OSUChecker.h"
#import "OSUPreferences.h"
#import "OSUCheckOperation.h"
#import "OSURunOperation.h"

RCS_ID("$Id$");

@interface OSUSystemConfigurationController ()
@property(nonatomic,strong) IBOutlet WebView *systemConfigurationWebView;
@property(assign) IBOutlet NSButton *okButton;
@end

@implementation OSUSystemConfigurationController

- (NSString *)frameworkDisplayName;
{
#if OSU_FULL
    return NSLocalizedStringFromTableInBundle(@"Omni Software Update", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"framework name when building the full OmniSoftwareUpdate");
#else
    return NSLocalizedStringFromTableInBundle(@"Omni System Info", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"framework name when building the mini OmniSoftwareInfo framework");
#endif
}

- (NSString *)htmlString;
{
    NSString *path = [OMNI_BUNDLE pathForResource:@"OSUHardwareDescriptionTemplate" ofType:@"html"];
    if (!path) {
#ifdef DEBUG
        NSLog(@"Cannot find OSUHardwareDescriptionTemplate.html");
#endif
        return nil;
    }
    
    NSData *templateData = [[NSData alloc] initWithContentsOfFile:path];
    if (!templateData) {
#ifdef DEBUG
        NSLog(@"Cannot load OSUHardwareDescriptionTemplate.html");
#endif
        return nil;
    }
    
    // We have to do the variable replacement on the string since the tables in the HTML will get replaced with attachment cells
    NSString *htmlTemplate = [[NSMutableString alloc] initWithData:templateData encoding:NSUTF8StringEncoding];
    
    // Get the system configuration report
    OSUChecker *checker = [OSUChecker sharedUpdateChecker];
    NSMutableDictionary *report = [[checker generateReport][OSUReportResultsInfoKey] mutableCopy];
    if (!report) {
#ifdef DEBUG
        NSLog(@"Couldn't generate report");
#endif
        return nil;
    }
    
    
    NSString *appName = [[OAController sharedController] appName];
    NSMutableString *body = [NSMutableString string];
    
    void (^p)(NSString *) = ^(NSString *line){
        [body appendString:@"<p>"];
        [body appendString:line];
        [body appendString:@"</p>"];
    };

    void (^table)(void (^)(void)) = ^(void (^guts)(void)) {
        [body appendString:@"<table class=\"toptable\">"];
        guts();
        [body appendString:@"</table>"];
    };
    void (^tr)(void (^)(void)) = ^(void (^guts)(void)) {
        [body appendString:@"<tr>"];
        guts();
        [body appendString:@"</tr>"];
    };
    void (^th_section)(void (^)(void)) = ^(void (^guts)(void)) {
        [body appendString:@"<th colspan=2 class=\"section\">"];
        guts();
        [body appendString:@"</th>"];
    };
    void (^th)(void (^)(void)) = ^(void (^guts)(void)) {
        [body appendString:@"<th>"];
        guts();
        [body appendString:@"</th>"];
    };
    void (^td)(void (^)(void)) = ^(void (^guts)(void)) {
        [body appendString:@"<td>"];
        guts();
        [body appendString:@"</td>"];
    };
    void (^td_right)(void (^)(void)) = ^(void (^guts)(void)) {
        [body appendString:@"<td align=\"right\">"];
        guts();
        [body appendString:@"</td>"];
    };
    
    void (^infoRow)(NSString *title, NSString *value) = ^(NSString *title, NSString *value){
        tr(^{
            th(^{
                [body appendString:title];
            });
            td(^{
                [body appendString:value];
            });
        });
    };

    void (^infoRow_b)(NSString *title, NSString *(^value)(void)) = ^(NSString *title, NSString *(^value)(void)){
        infoRow(title, value());
    };

    NSString *(^getValue)(NSString *) = ^(NSString *key){
        NSString *value = report[key];
        [report removeObjectForKey:key];
        return value;
    };
    
    // Intro.
    {
        NSString *line;
        
        p([NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ can optionally send us some basic information about your system configuration. We use this data to determine what systems our customers are using and therefore what systems are most important to support.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Software update hardware description page intro line one."), appName]);
        p(NSLocalizedStringFromTableInBundle(@"Omni will <b>never</b> release information about an individual’s computer configuration — only statistical information about all collected configurations. We honestly respect your privacy.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Software update hardware description page intro line two. Note the <b> HTML tag around 'never'."));
        p(NSLocalizedStringFromTableInBundle(@"If you prefer not to submit your system info, no problem — simply disable this option in the preference pane.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Software update hardware description page intro line two."));

        NSString *linkString = [NSString stringWithFormat:@"<a href=\"http://update.omnigroup.com/\">%@</a>", self.frameworkDisplayName];
        
        line = NSLocalizedStringFromTableInBundle(@"We do make the statistics we gather public so that other developers can also benefit from this knowledge. You can see the information we release at the LINK_PLACEHOLDER page.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Software update hardware description page intro line four. Do not localized LINK_PLACEHOLDER; it will be replaced at runtime.");
        
        p([line stringByReplacingOccurrencesOfString:@"LINK_PLACEHOLDER" withString:linkString options:0 range:NSMakeRange(0, [line length])]);
    }
    
    table(^{
        tr(^{
            th_section(^{
#if OSU_FULL
                NSString *format = NSLocalizedStringFromTableInBundle(@"When you check for updates, the following information about your copy of %@ is always sent.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Format string for the information sent header when using the full framework.");
#else
                NSString *format = NSLocalizedStringFromTableInBundle(@"When you check for updates, the following information about your copy of %@ is sent.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Format string for the information sent header when using the mini framework.");
#endif
                [body appendFormat:format, appName];
            });
        });
        
#if OSU_FULL
        NSString *versionTitle = NSLocalizedStringFromTableInBundle(@"OmniSoftwareUpdate version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for framework version in info table, when using the full framework.");
#else
        NSString *versionTitle = NSLocalizedStringFromTableInBundle(@"OmniSystemInfo version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for framework version in info table, when using the mini framework.");
#endif
        
        infoRow(versionTitle, [[OSUChecker OSUVersionNumber] originalVersionString]);

    
        infoRow(NSLocalizedStringFromTableInBundle(@"Application ID", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for application identifier in the info table."),
                [checker applicationIdentifier]);

        infoRow(NSLocalizedStringFromTableInBundle(@"Application Version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for application version in the info table."),
                [checker applicationEngineeringVersion]);
        
        infoRow(NSLocalizedStringFromTableInBundle(@"Update Track", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for application current update track in the info table."),
                [checker applicationTrack]);
        infoRow(NSLocalizedStringFromTableInBundle(@"Visible Update Tracks", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for application visible update tracks in the info table."),
                [[OSUPreferences visibleTracks] componentsJoinedByString:@", "]);
        
#if OSU_FULL
        tr(^{
            th_section(^{
                [body appendFormat:NSLocalizedStringFromTableInBundle(@"If you choose in %@ preferences to provide it, the following information is also sent.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Software update hardware description page intro line one."), appName];
            });
        });
#endif
        
        tr(^{
            th(^{
                [body appendString:@"UUID"]; // Probably doesn't need localizing.
            });
            td(^{
                NSString *explain = NSLocalizedStringFromTableInBundle(@"A random string that anonymously identifies your computer. This allows us to keep our database up to date when your system configuration changes. This is not associated with your name or any other personal information.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Explanatory text for the UUID in the info table.");
                [body appendFormat:@"%@<br><span class=\"explain\">%@</span>", getValue(@"uuid"), explain];
            });
        });
        
#if OSU_FULL
        tr(^{
            th(^{
                [body appendString:NSLocalizedStringFromTableInBundle(@"License Type", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for license type row in the info table.")];
            });
            td(^{
                NSString *explain = NSLocalizedStringFromTableInBundle(@"Your license key itself will never be sent.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Explanatory text for the license type row in the info table.");
                [body appendFormat:@"%@<br><span class=\"explain\">%@</span>", getValue(@"license-type"), explain];
            });
        });
#endif
        
        infoRow(NSLocalizedStringFromTableInBundle(@"OS Version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the OS version row in the info table."),
                getValue(@"os"));

        infoRow_b(NSLocalizedStringFromTableInBundle(@"Preferred Language", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the preferred language row in the info table."), ^{
            NSString *value = getValue(@"lang");
            NSString *localizedName = OFLocalizedNameForISOLanguageCode(value);
            return localizedName ? localizedName : value;
        });

    
        infoRow_b(NSLocalizedStringFromTableInBundle(@"Computer Model", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the computer model row in the info table."), ^{
            return [NSString stringWithFormat:@"%@ (%@)", getValue(@"machine_name"), getValue(@"hw-model")];
        });
        
        infoRow(NSLocalizedStringFromTableInBundle(@"CPU Count", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the CPU count row in the info table."),
                getValue(@"ncpu"));
        
        infoRow_b(NSLocalizedStringFromTableInBundle(@"CPU Type", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the CPU type row in the info table."), ^{
            return [NSString stringWithFormat:@"%@ (%@)", getValue(@"cpu_type"), getValue(@"cpu")];
        });
        
        
        infoRow_b(NSLocalizedStringFromTableInBundle(@"CPU Speed", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the CPU speed row in the info table."), ^{
            NSDecimalNumber *bytes = [NSDecimalNumber decimalNumberWithString:getValue(@"cpuhz")];
            return [NSString abbreviatedStringForHertz:[bytes unsignedLongLongValue]];
        });

        infoRow_b(NSLocalizedStringFromTableInBundle(@"Bus Speed", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the bus speed row in the info table."), ^{
            NSDecimalNumber *bytes = [NSDecimalNumber decimalNumberWithString:getValue(@"bushz")];
            return [NSString abbreviatedStringForHertz:[bytes unsignedLongLongValue]];
        });
        
        infoRow_b(NSLocalizedStringFromTableInBundle(@"Memory", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the memory row in the info table."), ^{
            NSString *mem = getValue(@"mem");
            if ([mem isEqualToString:@"-2147483648"]) {
                // See the check tool -- sysctl blow up here.
                return @">= 2GB";
            }
            
            return [NSByteCountFormatter stringFromByteCount:[mem longLongValue] countStyle:NSByteCountFormatterCountStyleMemory];
        });
        
        infoRow_b(NSLocalizedStringFromTableInBundle(@"Display Settings", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the display settings row in the info table."), ^{
            NSMutableString *displays = [NSMutableString string];
            
            unsigned int displayIndex = 0;
            while (YES) {
                NSString *displayKey = [NSString stringWithFormat:@"display%d", displayIndex];
                NSString *displayInfo = [report objectForKey:displayKey];
                if (!displayInfo)
                    break;
                if ([displays length])
                    [displays appendString:@"<br>"];
                [displays appendString:displayInfo];
                if ([displays length])
                    [displays appendString:@"<br>"];
                [report removeObjectForKey:displayKey];
                
                NSString *quartzExtremeKey = [NSString stringWithFormat:@"qe%d", displayIndex];
                NSString *quartzExtreme = [report objectForKey:quartzExtremeKey];
                if ([@"1" isEqualToString:quartzExtreme])
                    [displays appendString:NSLocalizedStringFromTableInBundle(@"Quartz Extreme Enabled", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel value - shown if Quartz Extreme is enabled")];
                else if ([@"0" isEqualToString:quartzExtreme])
                    [displays appendString:NSLocalizedStringFromTableInBundle(@"Quartz Extreme Disabled", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel value - shown if Quartz Extreme is not enabled")];
                else {
                    OBASSERT(NO);
                }
                if ([displays length])
                    [displays appendString:@"<br>"];
                [report removeObjectForKey:quartzExtremeKey];
                
                displayIndex++;
            }
            return displays;
        });

        infoRow_b(NSLocalizedStringFromTableInBundle(@"Video Cards", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the video cards row in the info table."), ^{
            NSMutableString *adaptors = [NSMutableString string];
            
            // We only record the name of the first adaptor for now
            NSString *adaptorName = [report objectForKey:@"adaptor0_name"];
            if (adaptorName) {
                static BOOL firstTime = YES;
                static NSBundle *displayNamesBundle = nil;
                if (firstTime) {
                    firstTime = NO;
                    displayNamesBundle = [NSBundle bundleWithPath:@"/System/Library/SystemProfiler/SPDisplaysReporter.spreporter"];
                }
                
                if (displayNamesBundle)
                    adaptorName = [displayNamesBundle localizedStringForKey:adaptorName value:adaptorName table:@"Localizable"];
                [adaptors appendFormat:@"%@", adaptorName];
                [report removeObjectForKey:@"adaptor0_name"];
            }
            
            unsigned int adaptorIndex = 0;
            while (YES) {
                NSString *pciKey   = [NSString stringWithFormat:@"accel%d_pci", adaptorIndex];
                NSString *glKey    = [NSString stringWithFormat:@"accel%d_gl", adaptorIndex];
                NSString *identKey = [NSString stringWithFormat:@"accel%d_id", adaptorIndex];
                NSString *verKey   = [NSString stringWithFormat:@"accel%d_ver", adaptorIndex];
                
                NSString *pci, *gl, *ident, *ver;
                pci   = [report objectForKey:pciKey];
                gl    = [report objectForKey:glKey];
                ident = [report objectForKey:identKey];
                ver   = [report objectForKey:verKey];
                
                if (!pci && !gl && !ident && !ver)
                    break;
                
                if ([adaptors length])
                    [adaptors appendString:@"<br><br>"];
                
                [adaptors appendString:NSLocalizedStringFromTableInBundle(@"PCI ID", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - PCI bus ID of video card")];
                [adaptors appendFormat:@": %@<br>", pci ?: @""];
                [adaptors appendString:NSLocalizedStringFromTableInBundle(@"OpenGL Driver", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - name of the OpenGL driver")];
                [adaptors appendFormat:@": %@<br>", gl ?: @""];
                [adaptors appendString:NSLocalizedStringFromTableInBundle(@"Hardware Driver", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - name of video card driver")];
                [adaptors appendFormat:@": %@<br>", ident ?: @""];
                [adaptors appendString:NSLocalizedStringFromTableInBundle(@"Driver Version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - version of video card driver")];
                [adaptors appendFormat:@": %@", ver ?: @""];
                
                [report removeObjectForKey:pciKey];
                [report removeObjectForKey:glKey];
                [report removeObjectForKey:identKey];
                [report removeObjectForKey:verKey];
                adaptorIndex++;
            }
            
            NSString *memString = [report objectForKey:@"accel_mem"];
            if (memString) {
                [adaptors appendString:@"<br>"];
                if (adaptorIndex == 1) {
                    [adaptors appendString:NSLocalizedStringFromTableInBundle(@"Memory", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - amount of video memory installed")];
                    [adaptors appendString:@": "];
                } else
                    [adaptors appendString:@"<br>"];
                
                NSArray *mems = [memString componentsSeparatedByString:@","];
                NSUInteger memIndex, memCount = [mems count];
                for (memIndex = 0; memIndex < memCount; memIndex++) {
                    if (memIndex)
                        [adaptors appendString:@", "];
                    [adaptors appendString:[NSString abbreviatedStringForBytes:[[mems objectAtIndex:memIndex] intValue]]];
                }
                [report removeObjectForKey:@"accel_mem"];
            }
            
            return adaptors;
        });

        infoRow_b(NSLocalizedStringFromTableInBundle(@"OpenGL Information", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the OpenGL information row in the info table."), ^{
            NSMutableString *glInfo = [NSMutableString string];
            
            unsigned int adaptorIndex = 0;
            while (YES) {
                NSString *vendorKey     = [NSString stringWithFormat:@"gl_vendor%d", adaptorIndex];
                NSString *rendererKey   = [NSString stringWithFormat:@"gl_renderer%d", adaptorIndex];
                NSString *versionKey    = [NSString stringWithFormat:@"gl_version%d", adaptorIndex];
                NSString *extensionsKey = [NSString stringWithFormat:@"gl_extensions%d", adaptorIndex];
                
                NSString *vendor, *renderer, *version, *extensions;
                vendor     = [report objectForKey:vendorKey];
                renderer   = [report objectForKey:rendererKey];
                version    = [report objectForKey:versionKey];
                extensions = [report objectForKey:extensionsKey];
                
                if (!vendor && !renderer && !version && !extensions)
                    break;
                
                if ([glInfo length])
                    [glInfo appendString:@"<br><br>"];
                
                [glInfo appendString:NSLocalizedStringFromTableInBundle(@"OpenGL Vendor", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string")];
                [glInfo appendFormat:@": %@<br>", vendor ?: @""];
                [glInfo appendString:NSLocalizedStringFromTableInBundle(@"OpenGL Renderer", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string")];
                [glInfo appendFormat:@": %@<br>", renderer ?: @""];
                [glInfo appendString:NSLocalizedStringFromTableInBundle(@"OpenGL Version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string")];
                [glInfo appendFormat:@": %@<br>", version ?: @""];
                [glInfo appendString:NSLocalizedStringFromTableInBundle(@"OpenGL Extensions", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string")];
                [glInfo appendFormat:@": %@<br>", extensions ?: @""];
                
                [report removeObjectForKey:vendorKey];
                [report removeObjectForKey:rendererKey];
                [report removeObjectForKey:versionKey];
                [report removeObjectForKey:extensionsKey];
                adaptorIndex++;
            }
            
            return glInfo;
        });
        
        infoRow_b(NSLocalizedStringFromTableInBundle(@"OpenCL Information", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Title for the OpenCL information row in the info table."), ^{
            NSMutableString *clInfo = [NSMutableString string];
            
            unsigned int clPlatformIndex = 0;
            for(;;) {
                NSString *platInfoKey = [NSString stringWithFormat:@"cl%u", clPlatformIndex];
                NSString *platExtKey = [platInfoKey stringByAppendingString:@"_ext"];
                NSString *platInfo = [report objectForKey:platInfoKey];
                NSString *platExt = [report objectForKey:platExtKey];
                
                if (!platInfo && !platExt)
                    break;
                
                [report removeObjectForKey:platInfoKey];
                [report removeObjectForKey:platExtKey];
                
                [clInfo appendString:@"<tr><td colspan=\"8\">"];

                if (platInfo)
                    [clInfo appendString:platInfo];
                if (![NSString isEmptyString:platExt]) {
                    NSString *extLabel = NSLocalizedStringFromTableInBundle(@"Extensions", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - list of OpenCL platform extensions");
                    [clInfo appendFormat:@"<br>%@: %@", extLabel, platExt];
                }
                [clInfo appendString:@"</td></tr>"];
                
                NSMutableString *clDeviceInfo = [NSMutableString string];
                
                unsigned int clDeviceIndex = 0;
                for(;;) {
                    NSString *devInfoKey = [NSString stringWithFormat:@"cl%u.%u_dev", clPlatformIndex, clDeviceIndex];
                    NSString *devInfo = [report objectForKey:devInfoKey];
                    if (!devInfo)
                        break;
                    [report removeObjectForKey:devInfoKey];
                    NSArray *parts = [devInfo componentsSeparatedByString:@" " maximum:5];
                    
                    [clDeviceInfo appendFormat:@"<tr><td>%@</td><td>%@</td><td>%@</td>",
                     [parts objectAtIndex:0],  // Device type
                     [parts objectAtIndex:1],  // Number of cores
                     [NSString abbreviatedStringForHertz:1048576*[[parts objectAtIndex:2] unsignedLongLongValue]] // Freq
                     ];
                    OFForEachInArray([[parts objectAtIndex:3] componentsSeparatedByString:@"/"], NSString *, mem, {
                        ([clDeviceInfo appendFormat:@"<td>%@</td>", [NSString abbreviatedStringForBytes:1024*[mem unsignedLongLongValue]]]);
                    });
                    [clDeviceInfo appendFormat:@"<td>%@</td></tr>", [parts objectAtIndex:4]];
                    
                    clDeviceIndex ++;
                }
                if (clDeviceIndex != 0) {
                    NSString *typeHeader = NSLocalizedStringFromTableInBundle(@"Type", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - column header for OpenCL device type");
                    NSString *unitsHeader = NSLocalizedStringFromTableInBundle(@"Units", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - column header for OpenCL device processing-unit count");
                    NSString *freqHeader = NSLocalizedStringFromTableInBundle(@"Freq.", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - column header for OpenCL device core frequency");
                    NSString *memHeader = NSLocalizedStringFromTableInBundle(@"Memory", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - column header for OpenCL device memory sizes");
                    NSString *extHeader = NSLocalizedStringFromTableInBundle(@"Exts", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - column header for OpenCL device extensions");
                    [clInfo appendFormat:@"<tr><td rowspan=\"%u\">&nbsp;&nbsp;</td><th>%@</th><th>%@</th><th>%@</th><th colspan=\"3\">%@</th><th>%@</th></tr>%@",
                     1 + clDeviceIndex,
                     typeHeader, unitsHeader, freqHeader, memHeader, extHeader,
                     clDeviceInfo];
                }
                
                clPlatformIndex ++;
            }
            
            [clInfo insertString:@"<table class=\"subtable\">" atIndex:0];
            [clInfo appendString:@"</table>"];
            return clInfo;
        });

    });
    
    
    table(^{
        tr(^{
            [body appendString:@"<th colspan=3 class=\"section\">"];
            [body appendString:NSLocalizedStringFromTableInBundle(@"Run Count and Times", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Section header for the application run/count table in the info table.")];
            [body appendString:@"</th>"];
        });
        
        tr(^{
            th(^{});
            th(^{
                [body appendString:NSLocalizedStringFromTableInBundle(@"Current Version", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Header for current version section in the run/count table of the info sheet")];
            });
            th(^{
                [body appendString:NSLocalizedStringFromTableInBundle(@"All Versions", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Header for all versions section in the run/count table of the info sheet")];
            });
            
            tr(^{
                th(^{
                    [body appendString:NSLocalizedStringFromTableInBundle(@"Hours Run", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Header for number of hours row in the run/count table of the info sheet")];
                });
                td_right(^{
                    NSString *value = [NSString stringWithFormat:@"%.1f", [getValue(@"runmin") unsignedIntValue]/60.0];
                    [body appendString:value];
                });
                td_right(^{
                    NSString *value = [NSString stringWithFormat:@"%.1f", [getValue(@"trunmin") unsignedIntValue]/60.0];
                    [body appendString:value];
                });
            });
            
            tr(^{
                th(^{
                    [body appendString:NSLocalizedStringFromTableInBundle(@"# of Launches", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Header for number of launches row in the run/count table of the info sheet")];
                });
                td_right(^{
                    [body appendString:getValue(@"nrun")];
                });
                td_right(^{
                    [body appendString:getValue(@"tnrun")];
                });
            });

            tr(^{
                th(^{
                    [body appendString:NSLocalizedStringFromTableInBundle(@"# of Crashes", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"Header for number of crashes row in the run/count table of the info sheet")];
                });
                td_right(^{
                    [body appendString:getValue(@"ndie")];
                });
                td_right(^{
                    [body appendString:getValue(@"tndie")];
                });
            });

        });
    });
    
    // Append a table for application-specific probes. We include these here even if the values are currently zero (and we won't send the zeros) so that there is no surprise if we start sending non-zero data later.
    NSArray *probes = [OSUProbe allProbes];
    if ([probes count] > 0) {
        table(^{
            tr(^{
                th_section(^{
                    [body appendString:NSLocalizedStringFromTableInBundle(@"Application Usage", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"details panel string - header for application feature usage table")];
                });
            });
            for (OSUProbe *probe in probes) {
                tr(^{
                    th(^{
                        [body appendString:probe.title];
                    });
                    td_right(^{
                        [body appendString:probe.displayString];
                    });
                });
                [report removeObjectForKey:probe.key];
            }
        });
    }
    
    
    // Append a table for unknown key/value pairs
    if ([report count] > 0) {
        OBASSERT_NOT_REACHED("Unknown keys in software update report: %@", report);
        
        table(^{
            tr(^{
                th_section(^{
                    [body appendString:@"Unknown Keys"]; // Not localized since this is a bug if it is hit anyway.
                });
            });

            [report enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
                tr(^{
                    th(^{
                        [body appendString:key];
                    });
                    td_right(^{
                        [body appendString:value];
                    });
                });
            }];
        });
    }

    return [htmlTemplate stringByReplacingKeysWithStartingDelimiter:@"${" endingDelimiter:@"}" usingBlock:^NSString *(NSString *key) {
        if ([key isEqualToString:@"OSU_FRAMEWORK"]) {
            return self.frameworkDisplayName;
        }

        if ([key isEqualToString:@"OSU_PANE_TITLE"]) {
            return NSLocalizedStringFromTableInBundle(@"Hardware Description", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"system preferences hardware description page title");
        }

        if ([key isEqual:@"OSU_BODY"]) {
            return body;
        }
        
        OBASSERT_NOT_REACHED("Unknown template key %@", key);
        return @"";
    }];
}

- (void)runModalSheetInWindow:(NSWindow *)parentWindow;
{
    NSWindow *sheetWindow = self.window;
    
    NSString *htmlString = [self htmlString];
    if (!htmlString) {
        return;
    }
    
#if OSU_FULL
    _systemConfigurationWebView.mediaStyle = @"osu-full";
#endif

    [[_systemConfigurationWebView mainFrame] loadHTMLString:htmlString baseURL:nil];
    
    OBStrongRetain(self); // stay alive while we are on screen.
    
    [parentWindow beginSheet:sheetWindow completionHandler:nil];
}

- (IBAction)dismissSystemConfigurationDetailsSheet:(id)sender;
{
    NSWindow *sheetWindow = self.window;
    NSWindow *parentWindow = sheetWindow.sheetParent;
    OBASSERT(parentWindow);
    [parentWindow endSheet:sheetWindow];
    
    OBAutorelease(self); // Matching the strong retain in -runModalSheetInWindow:
}

#pragma mark - NSWindowController subclass

- (NSString *)windowNibName;
{
    return @"OSUSystemConfiguration";
}

- (id)owner;
{
    return self; // Used to find the nib
}

#pragma mark - NSNibAwaking

- (void)awakeFromNib;
{
    [super awakeFromNib];
    self.okButton.title = NSLocalizedStringFromTableInBundle(@"OK", @"OmniSoftwareUpdate", OMNI_BUNDLE, @"button title");
}

#pragma mark - WebPolicyDelegate

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
	request:(NSURLRequest *)request
	  frame:(WebFrame *)frame
decisionListener:(id<WebPolicyDecisionListener>)listener;
{
    NSURL *url = [actionInformation objectForKey:WebActionOriginalURLKey];
    
    // about:blank is passed when loading the initial content
    if ([[url absoluteString] isEqualToString:@"about:blank"]) {
	[listener use];
	return;
    }
    
    // when a link is clicked reject it locally and open it in an external browser
    if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue] == WebNavigationTypeLinkClicked) {
	[[NSWorkspace sharedWorkspace] openURL:url];
	[listener ignore];
	return;
    }
    
#ifdef DEBUG
    NSLog(@"action %@, request %@", actionInformation, request);
#endif
}

- (void)webView:(WebView *)webView unableToImplementPolicyWithError:(NSError *)error frame:(WebFrame *)frame;
{
#ifdef DEBUG
    NSLog(@"error %@", error);
#endif
}

@end
