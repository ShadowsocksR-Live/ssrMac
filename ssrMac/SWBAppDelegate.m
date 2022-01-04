//
//  SWBAppDelegate.m
//  ssrMac
//
//  Created by clowwindy on 14-2-19.
//  Copyright (c) 2014年 clowwindy. All rights reserved.
//

#import <GZIP/GZIP.h>
#import "SWBConfigWindowController.h"
#import "SWBQRCodeWindowController.h"
#import "SWBAppDelegate.h"
#import <GCDWebServers/GCDWebServer.h>
#import <GCDWebServers/GCDWebServerDataResponse.h>
#import "ShadowsocksRunner.h"
#import "ProfileManager.h"
#import <AFNetworking/AFNetworking.h>
#import "qrCodeOnScreen.h"
#include <ssrNative/ssrNative.h>
#include "net_port_is_free.h"

#define kShadowsocksIsRunningKey @"ShadowsocksIsRunning"
#define kShadowsocksRunningModeKey @"ShadowsocksMode"
#define kShadowsocksHelper @"/Library/Application Support/ssrMac/ssr_mac_sysconf"
#define kSysconfVersion @"1.0.0"

@interface SWBAppDelegate () <SWBConfigWindowControllerDelegate>
@property(nonatomic, assign) BOOL useProxy;
@property(nonatomic, strong) NSString *runningMode;
@end

@implementation SWBAppDelegate {
    SWBConfigWindowController *configWindowController;
    SWBQRCodeWindowController *qrCodeWindowController;
    NSMenuItem *statusMenuItem;
    NSMenuItem *enableMenuItem;
    NSMenuItem *autoMenuItem;
    NSMenuItem *globalMenuItem;
    NSMenuItem *qrCodeMenuItem;
    NSMenu *serversMenu;
    NSData *originalPACData;
    FSEventStreamRef fsEventStream;
    NSString *configPath;
    NSString *PACPath;
    NSString *userRulePath;
    AFHTTPSessionManager *manager;
    NSInteger _listenPort;
}

static SWBAppDelegate *appDelegate;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self installHelper];

    _listenPort = DEFAULT_BIND_PORT;
    
    NSAppleEventManager *m = [NSAppleEventManager sharedAppleEventManager];
    [m setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    NSURL *url = [[NSBundle mainBundle] URLForResource:@"proxy" withExtension:@"pac.gz"];
    originalPACData = [[NSData dataWithContentsOfURL:url] gunzippedData];
    GCDWebServer *webServer = [[GCDWebServer alloc] init];
    [webServer addHandlerForMethod:@"GET"
                              path:@"/proxy.pac"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request)
     {
         return [GCDWebServerDataResponse responseWithData:[self PACData] contentType:@"application/x-ns-proxy-autoconfig"];
     }];

    [webServer startWithPort:8090 bonjourName:@"webserver"];

    manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];

    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:20];
    NSImage *image = [NSImage imageNamed:@"menu_icon"];
    [image setTemplate:YES];
    self.item.image = image;
    self.item.highlightMode = YES;
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ShadowsocksR"];
    [menu setMinimumWidth:200];
    
    statusMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"ShadowsocksR Off", nil) action:nil keyEquivalent:@""];
    enableMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Turn ShadowsocksR Off", nil) action:@selector(toggleRunning) keyEquivalent:@""];
    autoMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Auto Proxy Mode", nil) action:@selector(enableAutoProxy) keyEquivalent:@""];
    globalMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Global Mode", nil) action:@selector(enableGlobal) keyEquivalent:@""];
    
    [menu addItem:statusMenuItem];
    [menu addItem:enableMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:autoMenuItem];
    [menu addItem:globalMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];

    serversMenu = [[NSMenu alloc] init];
    NSMenuItem *serversItem = [[NSMenuItem alloc] init];
    [serversItem setTitle:NSLocalizedString(@"Servers", nil)];
    [serversItem setSubmenu:serversMenu];
    [menu addItem:serversItem];

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Edit PAC for Auto Proxy Mode...", nil) action:@selector(editPAC) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Update PAC from GFWList", nil) action:@selector(updatePACFromGFWList) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Edit User Rule for GFWList...", nil) action:@selector(editUserRule) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    qrCodeMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Generate QR Code...", nil) action:@selector(showQRCode) keyEquivalent:@""];
    [menu addItem:qrCodeMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Import URL from clipboard...", nil) action:@selector(importUrlFromClipboard) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Scan QR Code from Screen...", nil) action:@selector(scanQRCode) keyEquivalent:@""]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Show Logs...", nil) action:@selector(showLogs) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Help", nil) action:@selector(showHelp) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(exit) keyEquivalent:@""];
    self.item.menu = menu;

    [self initializeProxy];
    [self updateMenu];

    configPath = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @".ssrMac"];
    PACPath = [NSString stringWithFormat:@"%@/%@", configPath, @"gfwlist.js"];
    userRulePath = [NSString stringWithFormat:@"%@/%@", configPath, @"user-rule.txt"];
    [self monitorPAC:configPath];
    appDelegate = self;
    
    dispatch_queue_t proxy = dispatch_queue_create("proxy", NULL);
    dispatch_async(proxy, ^{
        [self doRunProxyLoop];
    });
}

- (BOOL) useProxy {
    BOOL result = YES;
    NSNumber *tmp = [[NSUserDefaults standardUserDefaults] objectForKey:kShadowsocksIsRunningKey];
    if ([tmp isKindOfClass:[NSNumber class]]) {
        result = [tmp boolValue];
    }
    return result;
}

- (void) setUseProxy:(BOOL)useProxy {
    [[NSUserDefaults standardUserDefaults] setBool:useProxy forKey:kShadowsocksIsRunningKey];
}

- (NSData *)PACData {
    if ([[NSFileManager defaultManager] fileExistsAtPath:PACPath]) {
        return [NSData dataWithContentsOfFile:PACPath];
    } else {
        return originalPACData;
    }
}

- (void)enableAutoProxy {
    self.runningMode = @"auto";
    [self updateMenu];
    [self reloadSystemProxy];
}

- (void)enableGlobal {
    self.runningMode = @"global";
    [self updateMenu];
    [self reloadSystemProxy];
}

- (void)chooseServer:(id)sender {
    NSInteger tag = [sender tag];
    Configuration *configuration = [ProfileManager configuration];
    if (tag == -1 || tag < configuration.profiles.count) {
        configuration.current = tag;
    }
    [ProfileManager saveConfiguration:configuration];
    [self updateServersMenu];
}

- (void)updateServersMenu {
    Configuration *configuration = [ProfileManager configuration];
    [serversMenu removeAllItems];
    int i = 0;
    for (Profile *profile in configuration.profiles) {
        NSString *title;
        if (profile.remarks.length) {
            title = [NSString stringWithFormat:@"%@ (%@:%d)", profile.remarks, profile.server, (int)profile.serverPort];
        } else {
            title = [NSString stringWithFormat:@"%@:%d", profile.server, (int)profile.serverPort];
        }
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(chooseServer:) keyEquivalent:@""];
        item.tag = i;
        if (i == configuration.current) {
            [item setState:1];
        }
        [serversMenu addItem:item];
        i++;
    }
    [serversMenu addItem:[NSMenuItem separatorItem]];
    [serversMenu addItemWithTitle:NSLocalizedString(@"Open Server Preferences...", nil) action:@selector(showConfigWindow) keyEquivalent:@""];
}

- (void) updateMenu {
    if (self.useProxy) {
        statusMenuItem.title = NSLocalizedString(@"ShadowsocksR: On", nil);
        enableMenuItem.title = NSLocalizedString(@"Turn ShadowsocksR Off", nil);
        NSImage *image = [NSImage imageNamed:@"menu_icon"];
        [image setTemplate:YES];
        self.item.image = image;
    } else {
        statusMenuItem.title = NSLocalizedString(@"ShadowsocksR: Off", nil);
        enableMenuItem.title = NSLocalizedString(@"Turn ShadowsocksR On", nil);
        NSImage *image = [NSImage imageNamed:@"menu_icon_disabled"];
        [image setTemplate:YES];
        self.item.image = image;
    }

    NSString *mode = [self runningMode];

    if ([mode isEqualToString:@"auto"]) {
        [autoMenuItem setState:1];
        [globalMenuItem setState:0];
    } else if([mode isEqualToString:@"global"]) {
        [autoMenuItem setState:0];
        [globalMenuItem setState:1];
    }

        [qrCodeMenuItem setTarget:self];
        [qrCodeMenuItem setAction:@selector(showQRCode)];

    [self updateServersMenu];
}

void onPACChange(
                ConstFSEventStreamRef streamRef,
                void *clientCallBackInfo,
                size_t numEvents,
                void *eventPaths,
                const FSEventStreamEventFlags eventFlags[],
                const FSEventStreamEventId eventIds[])
{
    [appDelegate reloadSystemProxy];
}

- (void) reloadSystemProxy {
    if (self.useProxy) {
        [self toggleSystemProxy:NO];
        [self toggleSystemProxy:YES];
    }
}

- (void)monitorPAC:(NSString *)pacPath {
    if (fsEventStream) {
        return;
    }
    CFStringRef mypath = (__bridge CFStringRef)(pacPath);
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&mypath, 1, NULL);
    void *callbackInfo = NULL; // could put stream-specific data here.
    CFAbsoluteTime latency = 3.0; /* Latency in seconds */

    /* Create the stream, passing in a callback */
    fsEventStream = FSEventStreamCreate(NULL,
            &onPACChange,
            callbackInfo,
            pathsToWatch,
            kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
            latency,
            kFSEventStreamCreateFlagNone /* Flags explained in reference */
    );
    FSEventStreamScheduleWithRunLoop(fsEventStream, [[NSRunLoop mainRunLoop] getCFRunLoop], (__bridge CFStringRef)NSDefaultRunLoopMode);
    FSEventStreamStart(fsEventStream);
}

- (void)editPAC {

    if (![[NSFileManager defaultManager] fileExistsAtPath:PACPath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:configPath withIntermediateDirectories:NO attributes:nil error:&error];
        // TODO check error
        [originalPACData writeToFile:PACPath atomically:YES];
    }
    [self monitorPAC:configPath];
    
    NSArray *fileURLs = @[[NSURL fileURLWithPath:PACPath]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}


- (void)editUserRule {
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:userRulePath]) {
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:configPath withIntermediateDirectories:NO attributes:nil error:&error];
    // TODO check error
    [@"! Put user rules line by line in this file.\n! See https://adblockplus.org/en/filter-cheatsheet\n" writeToFile:userRulePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
  }
  
  NSArray *fileURLs = @[[NSURL fileURLWithPath:userRulePath]];
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

- (void)showQRCode {
    NSURL *qrCodeURL = [ShadowsocksRunner generateSSURL];
    if (qrCodeURL) {
        qrCodeWindowController = [[SWBQRCodeWindowController alloc] initWithWindowNibName:@"QRCodeWindow"];
        qrCodeWindowController.qrCode = [qrCodeURL absoluteString];
        [qrCodeWindowController showWindow:self];
        [NSApp activateIgnoringOtherApps:YES];
        [qrCodeWindowController.window makeKeyAndOrderFront:nil];
    } else {
        // TODO
    }
}

- (void) importUrlFromClipboard {
    NSPasteboard *board = [NSPasteboard generalPasteboard];
    NSPasteboardItem *strObj = [[board pasteboardItems] firstObject];
    NSString *str = [strObj stringForType:NSPasteboardTypeString];
    if ([str isKindOfClass:[NSString class]]) {
        [self dealWithIncomingURL:str];
    }
}

- (void) scanQRCode {
    NSArray<NSURL *> *qrs = [qrCodeOnScreen scan];
    if (qrs.count) {
        [self dealWithIncomingURL:[qrs[0] absoluteString]];
    }
}

- (void)showLogs {
    [[NSWorkspace sharedWorkspace] launchApplication:@"/Applications/Utilities/Console.app"];
}

- (void)showHelp {
    NSString *url = NSLocalizedString(@"https://github.com/shadowsocks/shadowsocks-iOS/wiki/Shadowsocks-for-OSX-Help", nil);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

- (void)showConfigWindow {
    if (configWindowController) {
        [configWindowController close];
    }
    configWindowController = [[SWBConfigWindowController alloc] initWithWindowNibName:@"ConfigWindow"];
    configWindowController.delegate = self;
    [configWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
    [configWindowController.window makeKeyAndOrderFront:nil];
}

- (void) applicationWillTerminate:(NSNotification *)notification {
    NSLog(@"terminating");
    if (self.useProxy) {
        [self toggleSystemProxy:NO];
    }
}

#pragma mark SWBConfigWindowControllerDelegate

- (void) configurationDidChange {
    [self updateMenu];
}

#pragma mark -

- (void) doRunProxyLoop {
    [ShadowsocksRunner reloadConfig];
    for (; ;) {
        if ([ShadowsocksRunner runProxy]) {
            sleep(1);
        } else {
            sleep(2);
        }
    }
}

- (void)exit {
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)installHelper {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:kShadowsocksHelper] || ![self isSysconfVersionOK]) {
        NSString *helperPath = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], @"install_helper.sh"];
        NSLog(@"run install script: %@", helperPath);
        NSDictionary *error;
        NSString *script = [NSString stringWithFormat:@"do shell script \"bash %@\" with administrator privileges", helperPath];
        NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
        if ([appleScript executeAndReturnError:&error]) {
            NSLog(@"installation success");
        } else {
            NSLog(@"installation failure");
        }
    }
}

- (BOOL)isSysconfVersionOK {
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:kShadowsocksHelper];
    
    [task setArguments:@[@"-v", @"0"]];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *fd;
    fd = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [fd readDataToEndOfFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (![str isEqualToString:kSysconfVersion]) {
        return NO;
    }
    return YES;
}

- (void) initializeProxy {
    if (self.useProxy) {
        [self toggleSystemProxy:YES];
    }
    [self updateMenu];
}

- (void) toggleRunning {
    BOOL tmp = ! self.useProxy;
    self.useProxy = tmp;
    [self toggleSystemProxy:tmp];
    [self updateMenu];
}

- (NSString *) runningMode {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksRunningModeKey];
    return mode?:@"auto";
}

- (void) setRunningMode:(NSString *)runningMode {
    if (runningMode.length == 0) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setValue:runningMode forKey:kShadowsocksRunningModeKey];
}

- (NSInteger) toggleSystemProxyExternal {
    [self toggleSystemProxy:self.useProxy];
    return _listenPort;
}

- (void) toggleSystemProxy:(BOOL)useProxy {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:kShadowsocksHelper];

    NSString *mode;
    if (useProxy) {
        mode = [self runningMode];
    } else {
        mode = @"off";
    }
    
    do {
        if (net_port_is_free(DEFAULT_BIND_HOST, (uint16_t)_listenPort)) {
            break;
        }
        ++_listenPort;
    } while(true);

    NSString *portStr = [NSString stringWithFormat:@"%ld", (long)_listenPort];

    // this log is very important
    NSLog(@"run ShadowsocksR helper: %@", kShadowsocksHelper);
    [task setArguments:@[mode, portStr]];

    NSPipe *stdoutpipe = [NSPipe pipe];
    [task setStandardOutput:stdoutpipe];

    NSPipe *stderrpipe = [NSPipe pipe];
    [task setStandardError:stderrpipe];

    NSFileHandle *file = [stdoutpipe fileHandleForReading];

    [task launch];

    NSData *data = [file readDataToEndOfFile];

    NSString *string;
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0) {
        NSLog(@"%@", string);
    }

    file = [stderrpipe fileHandleForReading];
    data = [file readDataToEndOfFile];
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0) {
        NSLog(@"%@", string);
    }
}

- (void)updatePACFromGFWList {
    NSString *gfwList = @"https://autoproxy-gfwlist.googlecode.com/svn/trunk/gfwlist.txt";
    [manager GET:gfwList parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        // Objective-C is bullshit
        NSData *data = responseObject;
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSData *data2 = [[NSData alloc] initWithBase64Encoding:str];
        if (!data2) {
            NSLog(@"can't decode base64 string");
            return;
        }
        // Objective-C is bullshit
        NSString *str2 = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
        NSArray *lines = [str2 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        NSString *str3 = [[NSString alloc] initWithContentsOfFile:self->userRulePath encoding:NSUTF8StringEncoding error:nil];
        if (str3) {
            NSArray *rules = [str3 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            lines = [lines arrayByAddingObjectsFromArray:rules];
        }
        
        NSMutableArray *filtered = [[NSMutableArray alloc] init];
        for (NSString *line in lines) {
            if ([line length] > 0) {
                unichar s = [line characterAtIndex:0];
                if (s == '!' || s == '[') {
                    continue;
                }
                [filtered addObject:line];
            }
        }
        // Objective-C is bullshit
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:filtered options:NSJSONWritingPrettyPrinted error:&error];
        NSString *rules = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSData *data3 = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"abp" withExtension:@"js"]];
        NSString *template = [[NSString alloc] initWithData:data3 encoding:NSUTF8StringEncoding];
        NSString *result = [template stringByReplacingOccurrencesOfString:@"__RULES__" withString:rules];
        [[result dataUsingEncoding:NSUTF8StringEncoding] writeToFile:self->PACPath atomically:YES];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Updated";
        [alert runModal];
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    }];
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    [self dealWithIncomingURL:url];
}

- (void) dealWithIncomingURL:(NSString *)url {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert setMessageText:NSLocalizedString(@"Use this server?", nil)];
    [alert setInformativeText:url];
    [alert setAlertStyle:NSInformationalAlertStyle];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        BOOL result = [ShadowsocksRunner openSSURL:[NSURL URLWithString:url]];
        if (!result) {
            alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert setMessageText:@"Invalid ShadowsocksR URL"];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert runModal];
        }
    }
}

@end
