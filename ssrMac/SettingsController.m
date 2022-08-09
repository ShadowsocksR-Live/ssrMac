//
//  SettingsController.m
//  ssrMac
//
//  Created by ssrlive on 2022/8/10.
//  Copyright © 2022 ssrLive. All rights reserved.
//

#import "SettingsController.h"

@interface SettingsController ()

@end

@implementation SettingsController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSString *port = [NSString stringWithFormat:@"%ld", (long)self.appDelegate.listenPort];
    [self.txtPort setStringValue:port];
}

- (IBAction) btnOkClicked:(NSButton *)sender {
    NSString *s = self.txtPort.stringValue;
    NSInteger i = [self integerFromString:s];
    self.appDelegate.listenPort = i;
    [self.window performClose:self];
}

- (NSInteger) integerFromString:(NSString *)string {
    NSNumberFormatter *formatter=[[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *numberObj = [formatter numberFromString:string];
    return [numberObj integerValue];
}

@end
