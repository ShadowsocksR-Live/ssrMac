//
//  SettingsController.h
//  ssrMac
//
//  Created by ssrlive on 2022/8/10.
//  Copyright © 2022 ssrLive. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SWBAppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsController : NSWindowController
@property (weak) IBOutlet NSTextField *txtPort;

@property(weak) SWBAppDelegate *appDelegate;

@end

NS_ASSUME_NONNULL_END
