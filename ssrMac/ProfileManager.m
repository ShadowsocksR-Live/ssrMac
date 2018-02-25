//
// Created by clowwindy on 11/3/14.
// Copyright (c) 2014 clowwindy. All rights reserved.
//

#import "ProfileManager.h"
#import "ShadowsocksRunner.h"

#define CONFIG_DATA_KEY @"config"

@implementation ProfileManager {

}

+ (Configuration *)configuration {
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:CONFIG_DATA_KEY];
    Configuration *configuration;
    if (data == nil) {
        // upgrade data from old version
        configuration = [[Configuration alloc] init];
        configuration.profiles = [[NSMutableArray alloc] initWithCapacity:16];
        {
            configuration.current = 0;
            Profile *profile = [ShadowsocksRunner battleFrontGetProfile];
            [((NSMutableArray *)configuration.profiles) addObject:profile];
        }
        return configuration;
    }
    if (data == nil) {
        // load default configuration
        configuration = [[Configuration alloc] init];
        // public server
        configuration.current = -1;
        configuration.profiles = [[NSMutableArray alloc] initWithCapacity:16];
    } else {
        configuration = [[Configuration alloc] initWithJSONData:data];
    }
    return configuration;
}

+ (void)saveConfiguration:(Configuration *)configuration {
    if (configuration.profiles.count == 0) {
        configuration.current = -1;
    }
    if (configuration.current != -1 && configuration.current >= configuration.profiles.count) {
        configuration.current = 0;
    }
    [[NSUserDefaults standardUserDefaults] setObject:[configuration JSONData] forKey:CONFIG_DATA_KEY];
    [ProfileManager reloadShadowsocksRunner];
}

+ (void)reloadShadowsocksRunner {
    Configuration *configuration = [ProfileManager configuration];
    if (configuration.current == -1) {
        [ShadowsocksRunner reloadConfig];
    } else {
        Profile *profile = configuration.profiles[configuration.current];
        [ShadowsocksRunner battleFrontSaveProfile:profile];
        [ShadowsocksRunner reloadConfig];
    }
}

@end
