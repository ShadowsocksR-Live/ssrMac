//
// Created by clowwindy on 14-2-27.
// Copyright (c) 2014 clowwindy. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kShadowsocksRemarksKey @"proxy remarks"

#define kShadowsocksIPKey @"proxy ip"
#define kShadowsocksPortKey @"proxy port"
#define kShadowsocksPasswordKey @"proxy password"
#define kShadowsocksEncryptionKey @"proxy encryption"

#define kShadowsocksProtocolKey @"proxy protocol"
#define kShadowsocksProtocolParamKey @"proxy protocolParam"
#define kShadowsocksObfsKey @"proxy obfs"
#define kShadowsocksObfsParamKey @"proxy obfsParam"

#define kShadowsocksOtEnableKey @"ot_enable"
#define kShadowsocksOtDomainKey @"ot_domain"
#define kShadowsocksOtPathKey @"ot_path"

#define kShadowsocksProxyModeKey @"proxy mode"

@class Profile;

@interface ShadowsocksRunner : NSObject

+ (BOOL)settingsAreNotComplete;
+ (BOOL)runProxy;
+ (void)reloadConfig;
+ (BOOL)openSSURL:(NSURL *)url;
+ (NSURL *)generateSSURL;
+ (NSString *)configForKey:(NSString *)key;
+ (void)saveConfigForKey:(NSString *)key value:(NSString *)value;

+ (void) battleFrontSaveProfile:(Profile *)profile;
+ (Profile *) battleFrontGetProfile;

@end
