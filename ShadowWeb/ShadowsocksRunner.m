//
// Created by clowwindy on 14-2-27.
// Copyright (c) 2014 clowwindy. All rights reserved.
//

#import "ShadowsocksRunner.h"
#import "SWBAppDelegate.h"
#import "Profile.h"
#import "Configuration.h"
#import "ProfileManager.h"
#include <ssrNative/ssrNative.h>

static uint16_t retrieve_socket_port(int socket) {
    char tmp[256] = { 0 }; // buffer size must big enough
    socklen_t len = sizeof(tmp);
    if (getsockname(socket, (struct sockaddr*)tmp, &len) != 0) {
        return 0;
    }
    else {
        return ntohs(((struct sockaddr_in*)tmp)->sin_port);
    }
}

struct server_config * build_config_object(Profile *profile, unsigned short port) {
    const char *protocol = profile.protocol.UTF8String;
    if (protocol && strcmp(protocol, "verify_sha1") == 0) {
        // LOGI("The verify_sha1 protocol is deprecate! Fallback to origin protocol.");
        protocol = NULL;
    }

    struct server_config *config = config_create();

    // config->udp = true;
    config->listen_port = port;
    string_safe_assign(&config->method, profile.method.UTF8String);
    string_safe_assign(&config->remote_host, profile.server.UTF8String);
    config->remote_port = (unsigned short) profile.serverPort;
    string_safe_assign(&config->password, profile.password.UTF8String);
    string_safe_assign(&config->protocol, protocol);
    string_safe_assign(&config->protocol_param, profile.protocolParam.UTF8String);
    string_safe_assign(&config->obfs, profile.obfs.UTF8String);
    string_safe_assign(&config->obfs_param, profile.obfsParam.UTF8String);
    string_safe_assign(&config->remarks, profile.remarks.UTF8String);
    config->over_tls_enable = (profile.ot_enable != NO);
    string_safe_assign(&config->over_tls_server_domain, profile.ot_domain.UTF8String);
    string_safe_assign(&config->over_tls_path, profile.ot_path.UTF8String);

    return config;
}

struct ssr_client_state *g_state = NULL;

void feedback_state(struct ssr_client_state *state, void *p) {
    g_state = state;
    SWBAppDelegate *appDelegate = (__bridge SWBAppDelegate *)p;
    int realPort = retrieve_socket_port(ssr_get_listen_socket_fd(state));
    appDelegate.workingListenPort = realPort;
    [appDelegate modifySystemProxySettings:YES port:realPort];
}

void dump_info_callback(int dump_level, const char *info, void *p) {
    (void)p;
    printf("%s", info);
}

void ssr_main_loop(unsigned short listenPort, const char *appPath, void*p) {
    struct server_config *config = NULL;
    do {
        set_app_name(appPath);
        set_dump_info_callback(&dump_info_callback, NULL);
        Profile *profile = [ShadowsocksRunner battleFrontGetProfile];
        config = build_config_object(profile, listenPort);
        if (config == NULL) {
            break;
        }

        config_ssrot_revision(config);

        if (config->method == NULL || config->password==NULL || config->remote_host==NULL) {
            break;
        }

        ssr_run_loop_begin(config, &feedback_state, p);
        g_state = NULL;
    } while(0);

    config_release(config);
}

void ssr_stop(void) {
    ssr_run_loop_shutdown(g_state);
}

@implementation ShadowsocksRunner {
}

+ (BOOL)settingsAreNotComplete {
    if (([[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksIPKey] == nil ||
         [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksPortKey] == nil ||
         [[NSUserDefaults standardUserDefaults] stringForKey:kShadowsocksPasswordKey] == nil))
    {
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL) runProxy {
    __block SWBAppDelegate *appDelegate;
    dispatch_sync(dispatch_get_main_queue(), ^{
        appDelegate = (SWBAppDelegate *) [NSApplication sharedApplication].delegate;
    });
    NSAssert([appDelegate isKindOfClass:[SWBAppDelegate class]], @"SWBAppDelegate");
    
    NSString *path = [NSBundle mainBundle].executablePath;
    
    unsigned short port = (unsigned short) [appDelegate correctListenPort];
    
    BOOL result = NO;
    if (![ShadowsocksRunner settingsAreNotComplete]) {
        ssr_main_loop(port, path.UTF8String, (__bridge void *)(appDelegate));
        usleep(200000);
        result = YES;
    } else {
#ifdef DEBUG
        NSLog(@"warning: settings are not complete");
#endif
    }
    return result;
}

+ (void) reloadConfig {
    if (![ShadowsocksRunner settingsAreNotComplete]) {
        ssr_stop();
        dispatch_async(dispatch_get_main_queue(), ^{
            SWBAppDelegate *appDelegate;
            appDelegate = (SWBAppDelegate *) [NSApplication sharedApplication].delegate;
            appDelegate.workingListenPort = 0;
        });
    }
}

+ (Profile *) profileFromServerConfig:(struct server_config *)config {
    Profile *profile = [[Profile alloc] init];
    
    profile.method = [NSString stringWithUTF8String:config->method];
    profile.password = [NSString stringWithUTF8String:config->password];
    profile.server = [NSString stringWithUTF8String:config->remote_host];
    profile.serverPort = config->remote_port;
    
    profile.protocol = [NSString stringWithUTF8String:config->protocol];
    profile.protocolParam = [NSString stringWithUTF8String:config->protocol_param?:""];
    profile.obfs = [NSString stringWithUTF8String:config->obfs];
    profile.obfsParam = [NSString stringWithUTF8String:config->obfs_param?:""];
    profile.ot_enable = (config->over_tls_enable != false);
    profile.ot_domain = [NSString stringWithUTF8String:config->over_tls_server_domain?:""];
    profile.ot_path = [NSString stringWithUTF8String:config->over_tls_path?:""];
    
    profile.remarks = [NSString stringWithUTF8String:config->remarks?:""];

    return profile;
}

+ (BOOL)openSSURL:(NSURL *)url {
    if (!url.host) {
        return NO;
    }
    
    struct server_config *config = ssr_qr_code_decode([url absoluteString].UTF8String);
    if (config == NULL) {
        return NO;
    }
    
    Profile *profile = [[self class] profileFromServerConfig:config];

    config_release(config);

    Configuration *configuration = [ProfileManager configuration];
    [configuration.profiles addObject:profile];
    [ProfileManager saveConfiguration:configuration];
    
    [ShadowsocksRunner reloadConfig];

    SWBAppDelegate *appDelegate = (SWBAppDelegate *) [NSApplication sharedApplication].delegate;
    NSAssert([appDelegate isKindOfClass:[SWBAppDelegate class]], @"SWBAppDelegate");
    [appDelegate updateMenu];
    
    return YES;
}

+(NSURL *)generateSSURL {
    char *qrCode = NULL;

    Profile *profile = [ShadowsocksRunner battleFrontGetProfile];
    struct server_config *config = build_config_object(profile, 0);
    qrCode = ssr_qr_code_encode(config, &malloc);
    config_release(config);

    NSString *r = [NSString stringWithUTF8String:qrCode];
    free(qrCode);
    
    return [NSURL URLWithString:r];
}

+ (void)saveConfigForKey:(NSString *)key value:(NSString *)value {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
}

+ (NSString *) configForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

+ (void) battleFrontSaveProfile:(Profile *)profile {
    if (profile == nil) {
        return;
    }
    
    [ShadowsocksRunner saveConfigForKey:kShadowsocksRemarksKey value:profile.remarks];

    [ShadowsocksRunner saveConfigForKey:kShadowsocksIPKey value:profile.server];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksPortKey value:[NSString stringWithFormat:@"%ld", (long)profile.serverPort]];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksPasswordKey value:profile.password];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksEncryptionKey value:profile.method];

    [ShadowsocksRunner saveConfigForKey:kShadowsocksProtocolKey value:profile.protocol];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksProtocolParamKey value:profile.protocolParam];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksObfsKey value:profile.obfs];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksObfsParamKey value:profile.obfsParam];
    
    [ShadowsocksRunner saveConfigForKey:kShadowsocksOtEnableKey value:[NSString stringWithFormat:@"%ld", (long)profile.ot_enable]];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksOtDomainKey value:profile.ot_domain];
    [ShadowsocksRunner saveConfigForKey:kShadowsocksOtPathKey value:profile.ot_path];
}

+ (Profile *) battleFrontGetProfile {
    Profile *profile = [[Profile alloc] init];

    NSString *remarks = [ShadowsocksRunner configForKey:kShadowsocksRemarksKey];
    profile.remarks = [remarks isKindOfClass:[NSString class]] ? remarks : @"";

    NSString *server = [ShadowsocksRunner configForKey:kShadowsocksIPKey];
    profile.server = [server isKindOfClass:[NSString class]] ? server : @"";

    NSString *port = [ShadowsocksRunner configForKey:kShadowsocksPortKey];
    profile.serverPort = [port isKindOfClass:[NSString class]] ? port.integerValue : 0;

    NSString *password = [ShadowsocksRunner configForKey:kShadowsocksPasswordKey];
    profile.password = [password isKindOfClass:[NSString class]] ? password : @"";

    NSString *method = [ShadowsocksRunner configForKey:kShadowsocksEncryptionKey];
    profile.method = [method isKindOfClass:[NSString class]] ? method : @"";

    NSString *protocol = [ShadowsocksRunner configForKey:kShadowsocksProtocolKey];
    profile.protocol = [protocol isKindOfClass:[NSString class]] ? protocol : @"";

    NSString *protocolParam = [ShadowsocksRunner configForKey:kShadowsocksProtocolParamKey];
    profile.protocolParam = [protocolParam isKindOfClass:[NSString class]] ? protocolParam : @"";

    NSString *obfs = [ShadowsocksRunner configForKey:kShadowsocksObfsKey];
    profile.obfs = [obfs isKindOfClass:[NSString class]] ? obfs : @"";

    NSString *obfsParam = [ShadowsocksRunner configForKey:kShadowsocksObfsParamKey];
    profile.obfsParam = [obfsParam isKindOfClass:[NSString class]] ? obfsParam : @"";

    NSString *ot_enable = [ShadowsocksRunner configForKey:kShadowsocksOtEnableKey];
    profile.ot_enable = [ot_enable isKindOfClass:[NSString class]] ? (ot_enable.integerValue != 0) : NO;

    NSString *ot_domain = [ShadowsocksRunner configForKey:kShadowsocksOtDomainKey];
    profile.ot_domain = [ot_domain isKindOfClass:[NSString class]] ? ot_domain : @"";

    NSString *ot_path = [ShadowsocksRunner configForKey:kShadowsocksOtPathKey];
    profile.ot_path = [ot_path isKindOfClass:[NSString class]] ? ot_path : @"";

    return profile;
}

@end
