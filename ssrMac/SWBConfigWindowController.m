//
// Created by clowwindy on 14-2-26.
// Copyright (c) 2014 clowwindy. All rights reserved.
//

#import <openssl/evp.h>
#import <QuartzCore/QuartzCore.h>
#import "SWBConfigWindowController.h"
#import "ShadowsocksRunner.h"
#import "ProfileManager.h"
#import "encrypt.h"
#include "ssr_cipher_names.h"
#import "KSPasswordField.h"


@implementation SWBConfigWindowController {
    IBOutlet KSPasswordField *_passwordField;

    Configuration *_configuration;
}


- (void)windowWillLoad {
    [super windowWillLoad];
}

- (void)addMethods {
    for (enum ss_cipher_type i = ss_cipher_none; i < ss_cipher_max; ++i) {
        const char* method_name = ss_cipher_name_of_type(i);
        if (method_name == NULL) {
            continue;
        }
        [_methodBox addItemWithObjectValue:[NSString stringWithUTF8String:method_name]];
    }
}

- (void) fillProtocols {
    for(enum ssr_protocol i=ssr_protocol_origin; i<ssr_protocol_max; ++i) {
        const char *protocol = ssr_protocol_name_of_type(i);
        if (protocol == NULL) {
            continue;
        }
        [_protocolBox addItemWithObjectValue:[NSString stringWithUTF8String:protocol]];
    }
}

- (void) fileObfuscators {
    for (enum ssr_obfs i=ssr_obfs_plain; i<ssr_obfs_max; ++i) {
        const char *obfs = ssr_obfs_name_of_type(i);
        if (obfs == NULL) {
            continue;
        }
        [_obfsBox addItemWithObjectValue:[NSString stringWithUTF8String:obfs]];
    }
}

- (void)loadSettings {
    _configuration = [ProfileManager configuration];
    [self.tableView reloadData];
    [self loadCurrentProfile];
}

- (void)saveSettings {
    [ProfileManager saveConfiguration:_configuration];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if (self.tableView.selectedRow < 0) {
        // always allow no selection to selection
        return YES;
    }
    if (row >= 0 && row < _configuration.profiles.count) {
        if ([self validateCurrentProfile]) {
            [self saveCurrentProfile];
        } else {
            return NO;
        }
    }
    // always allow selection to no selection
    return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (self.tableView.selectedRow >= 0) {
        [self loadCurrentProfile];
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Profile *profile = _configuration.profiles[row];
    if ([profile.server isEqualToString:@""]) {
        return @"New Server";
    }
    return profile.server;
}

- (IBAction)sectionClick:(id)sender {
    NSInteger index = ((NSSegmentedControl *)sender).selectedSegment;
    if (index == 0) {
        [self add:sender];
    } else if (index == 1) {
        [self remove:sender];
    }
}

- (IBAction)add:(id)sender {
    if (_configuration.profiles.count != 0 && ![self saveCurrentProfile]) {
        [self shakeWindow];
        return;
    }
    Profile *profile = [[Profile alloc] init];
    [((NSMutableArray *) _configuration.profiles) addObject:profile];
    [self.tableView reloadData];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:(_configuration.profiles.count - 1)];
    [self.tableView selectRowIndexes:indexes byExtendingSelection:NO];
    [self updateSettingsBoxVisible:self];
    [self loadCurrentProfile];
}

- (IBAction)remove:(id)sender {
    NSInteger selection = self.tableView.selectedRow;
    if (selection >= 0 && selection < _configuration.profiles.count) {
        [((NSMutableArray *) _configuration.profiles) removeObjectAtIndex:selection];
        [self.tableView reloadData];
        [self updateSettingsBoxVisible:self];
        if (_configuration.profiles.count > 0) {
            NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:(_configuration.profiles.count - 1)];
            [self.tableView selectRowIndexes:indexes byExtendingSelection:NO];
        }
        [self loadCurrentProfile];
        if (_configuration.current > selection) {
            // select the original profile
            _configuration.current = _configuration.current - 1;
        }
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _configuration.profiles.count;
}

- (void)windowDidLoad {
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [super windowDidLoad];
    [self addMethods];
    [self fillProtocols];
    [self fileObfuscators];
    [self loadSettings];
    [self updateSettingsBoxVisible:self];
}

- (IBAction)updateSettingsBoxVisible:(id)sender {
    if (_configuration.profiles.count == 0) {
        [_settingsBox setHidden:YES];
        [_placeholderLabel setHidden:NO];
    } else {
        [_settingsBox setHidden:NO];
        [_placeholderLabel setHidden:YES];
    }
}

- (void)loadCurrentProfile {
    if (_configuration.profiles.count > 0) {
        if (self.tableView.selectedRow >= 0 && self.tableView.selectedRow < _configuration.profiles.count) {
            Profile *profile = _configuration.profiles[self.tableView.selectedRow];
            [_serverField setStringValue:profile.server];
            [_portField setStringValue:[NSString stringWithFormat:@"%ld", (long)profile.serverPort]];
            [_methodBox setStringValue:profile.method];
            [_passwordField setStringValue:profile.password];
            
            [_protocolBox setStringValue:profile.protocol];
            [_protocolParamField setStringValue:profile.protocolParam];
            [_obfsBox setStringValue:profile.obfs];
            [_obfsParamField setStringValue:profile.obfsParam];
            
            if (profile.remarks) {
                [_remarksField setStringValue:profile.remarks];
            } else {
                [_remarksField setStringValue:@""];
            }
        }
    }
}

- (BOOL) saveCurrentProfile {
    if (![self validateCurrentProfile]) {
        return NO;
    }
    NSInteger selectedRow = self.tableView.selectedRow;
    if (0 <= selectedRow && selectedRow < _configuration.profiles.count) {
        Profile *profile = _configuration.profiles[selectedRow];
        profile.server = [_serverField stringValue];
        profile.serverPort = [_portField integerValue];
        profile.method = [_methodBox stringValue];
        profile.password = [_passwordField stringValue];
        
        profile.protocol = [_protocolBox stringValue];
        profile.protocolParam = [_protocolParamField stringValue];
        profile.obfs = [_obfsBox stringValue];
        profile.obfsParam = [_obfsParamField stringValue];
        
        profile.remarks = [_remarksField stringValue];
    }

    return YES;
}

- (BOOL)validateCurrentProfile {
    if ([[_serverField stringValue] isEqualToString:@""]) {
        [_serverField becomeFirstResponder];
        return NO;
    }
    if ([_portField integerValue] == 0) {
        [_portField becomeFirstResponder];
        return NO;
    }
    if ([[_methodBox stringValue] isEqualToString:@""]) {
        [_methodBox becomeFirstResponder];
        return NO;
    }
    if ([[_passwordField stringValue] isEqualToString:@""]) {
        [_passwordField becomeFirstResponder];
        return NO;
    }
    
    if (_protocolBox.stringValue.length == 0) {
        [_protocolBox becomeFirstResponder];
        return NO;
    }
    if (_obfsBox.stringValue.length == 0) {
        [_obfsBox becomeFirstResponder];
        return NO;
    }

    return YES;
}

- (IBAction)OK:(id)sender {
    if ([self saveCurrentProfile]) {
        [self saveSettings];
        [ShadowsocksRunner reloadConfig];
        [self.delegate configurationDidChange];
        [self.window performClose:self];
    } else {
        [self shakeWindow];
    }
}

- (IBAction)cancel:(id)sender {
    [self.window performClose:self];
}

- (IBAction) passwordChkBoxClicked:(NSButton *)sender {
    [_passwordField setShowsText:(sender.state == NSOnState)];
}

- (void)shakeWindow {
    static int numberOfShakes = 3;
    static float durationOfShake = 0.7f;
    static float vigourOfShake = 0.03f;

    CGRect frame=[self.window frame];
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];

    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
    int index;
    for (index = 0; index < numberOfShakes; ++index)
    {
        CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame));
        CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame));
    }
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = durationOfShake;

    [self.window setAnimations:[NSDictionary dictionaryWithObject: shakeAnimation forKey:@"frameOrigin"]];
    [[self.window animator] setFrameOrigin:[self.window frame].origin];
}

@end
