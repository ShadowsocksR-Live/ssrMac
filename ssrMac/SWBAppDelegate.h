//
//  SWBAppDelegate.h
//  ssrMac
//
//  Created by clowwindy on 14-2-19.
//  Copyright (c) 2014年 clowwindy. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SWBAppDelegate : NSObject <NSApplicationDelegate>
@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem* item;
@property(nonatomic, assign) NSInteger listenPort;
@property(nonatomic, assign) NSInteger workingListenPort;
- (NSInteger) correctListenPort;
- (void) modifySystemProxySettings:(BOOL)useProxy port:(NSInteger)port;
- (void) updateMenu;
@end
