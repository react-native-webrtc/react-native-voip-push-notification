//
//  RNVoipPushNotificationManager.m
//  RNVoipPushNotification
//
//  Created by Ian Yu-Hsun Lin on 4/18/16.
//  Copyright © 2016 ianyuhsunlin. All rights reserved.
//

#import <PushKit/PushKit.h>
#import "RNVoipPushNotificationManager.h"

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>

NSString *const RNVoipRemoteNotificationsRegistered = @"voipRemoteNotificationsRegistered";
NSString *const RNVoipLocalNotificationReceived = @"voipLocalNotificationReceived";
NSString *const RNVoipRemoteNotificationReceived = @"voipRemoteNotificationReceived";

static NSString *RCTCurrentAppBackgroundState()
{
    static NSDictionary *states;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        states = @{
            @(UIApplicationStateActive): @"active",
            @(UIApplicationStateBackground): @"background",
            @(UIApplicationStateInactive): @"inactive"
        };
    });

    if (RCTRunningInAppExtension()) {
        return @"extension";
    }

    return states[@(RCTSharedApplication().applicationState)] ? : @"unknown";
}

@implementation RCTConvert (UILocalNotification)

+ (UILocalNotification *)UILocalNotification:(id)json
{
    NSDictionary<NSString *, id> *details = [self NSDictionary:json];
    UILocalNotification *notification = [UILocalNotification new];
    notification.fireDate = [RCTConvert NSDate:details[@"fireDate"]] ?: [NSDate date];
    notification.alertTitle = [RCTConvert NSString:details[@"alertTitle"]];
    notification.alertBody = [RCTConvert NSString:details[@"alertBody"]];
    notification.alertAction = [RCTConvert NSString:details[@"alertAction"]];
    notification.soundName = [RCTConvert NSString:details[@"soundName"]] ?: UILocalNotificationDefaultSoundName;
    notification.userInfo = [RCTConvert NSDictionary:details[@"userInfo"]];
    notification.category = [RCTConvert NSString:details[@"category"]];
    return notification;
}

@end

@implementation RNVoipPushNotificationManager

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setBridge:(RCTBridge *)bridge
{
    _bridge = bridge;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRemoteNotificationsRegistered:)
                                                 name:RNVoipRemoteNotificationsRegistered
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLocalNotificationReceived:)
                                                 name:RNVoipLocalNotificationReceived
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRemoteNotificationReceived:)
                                                 name:RNVoipRemoteNotificationReceived
                                               object:nil];
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
    NSString *currentState = RCTCurrentAppBackgroundState();
    NSLog(@"[RNVoipPushNotificationManager] constantsToExport currentState = %@", currentState);
    return @{@"wakeupByPush": (currentState == @"background") ? @"true" : @"false"};
}

- (void)registerUserNotification:(NSDictionary *)permissions
{
    UIUserNotificationType types = UIUserNotificationTypeNone;
    if (permissions) {
        if ([RCTConvert BOOL:permissions[@"alert"]]) {
            types |= UIUserNotificationTypeAlert;
        }
        if ([RCTConvert BOOL:permissions[@"badge"]]) {
            types |= UIUserNotificationTypeBadge;
        }
        if ([RCTConvert BOOL:permissions[@"sound"]]) {
            types |= UIUserNotificationTypeSound;
        }
    } else {
        types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
    }

    UIApplication *app = RCTSharedApplication();
    UIUserNotificationSettings *notificationSettings =
        [UIUserNotificationSettings settingsForTypes:(NSUInteger)types categories:nil];
    [app registerUserNotificationSettings:notificationSettings];
}

- (void)voipRegistration
{
    NSLog(@"[RNVoipPushNotificationManager] voipRegistration");

    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_async(mainQueue, ^{
      // Create a push registry object
      PKPushRegistry * voipRegistry = [[PKPushRegistry alloc] initWithQueue: mainQueue];
      // Set the registry's delegate to AppDelegate
      voipRegistry.delegate = (RNVoipPushNotificationManager *)RCTSharedApplication().delegate;
      // Set the push type to VoIP
      voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    });
}

- (NSDictionary *)checkPermissions
{
    NSUInteger types = [RCTSharedApplication() currentUserNotificationSettings].types;
  
    return @{
        @"alert": @((types & UIUserNotificationTypeAlert) > 0),
        @"badge": @((types & UIUserNotificationTypeBadge) > 0),
        @"sound": @((types & UIUserNotificationTypeSound) > 0),
    };
  
}

+ (NSString *)getCurrentAppBackgroundState
{
    return RCTCurrentAppBackgroundState();
}

+ (void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type
{
    NSLog(@"[RNVoipPushNotificationManager] didUpdatePushCredentials credentials.token = %@, type = %@", credentials.token, type);

    NSMutableString *hexString = [NSMutableString string];
    NSUInteger voipTokenLength = credentials.token.length;
    const unsigned char *bytes = credentials.token.bytes;
    for (NSUInteger i = 0; i < voipTokenLength; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:RNVoipRemoteNotificationsRegistered
                                                        object:self
                                                      userInfo:@{@"deviceToken" : [hexString copy]}];
}

+ (void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    NSLog(@"[RNVoipPushNotificationManager] didReceiveIncomingPushWithPayload payload.dictionaryPayload = %@, type = %@", payload.dictionaryPayload, type);
    [[NSNotificationCenter defaultCenter] postNotificationName:RNVoipRemoteNotificationReceived
                                                        object:self
                                                      userInfo:payload.dictionaryPayload];
}

- (void)handleRemoteNotificationsRegistered:(NSNotification *)notification
{
    NSLog(@"[RNVoipPushNotificationManager] handleRemoteNotificationsRegistered notification.userInfo = %@", notification.userInfo);
    [_bridge.eventDispatcher sendDeviceEventWithName:@"voipRemoteNotificationsRegistered"
                                                body:notification.userInfo];
}

- (void)handleLocalNotificationReceived:(NSNotification *)notification
{
    NSLog(@"[RNVoipPushNotificationManager] handleLocalNotificationReceived notification.userInfo = %@", notification.userInfo);
    [_bridge.eventDispatcher sendDeviceEventWithName:@"voipLocalNotificationReceived"
                                                body:notification.userInfo];
}

- (void)handleRemoteNotificationReceived:(NSNotification *)notification
{
    NSLog(@"[RNVoipPushNotificationManager] handleRemoteNotificationReceived notification.userInfo = %@", notification.userInfo);
    [_bridge.eventDispatcher sendDeviceEventWithName:@"voipRemoteNotificationReceived"
                                                body:notification.userInfo];
}

RCT_EXPORT_METHOD(requestPermissions:(NSDictionary *)permissions)
{
    if (RCTRunningInAppExtension()) {
        return;
    }
  dispatch_async(dispatch_get_main_queue(), ^{
    [self registerUserNotification:permissions];
    [self voipRegistration];
  });
}

RCT_EXPORT_METHOD(checkPermissions:(RCTResponseSenderBlock)callback)
{
    if (RCTRunningInAppExtension()) {
        callback(@[@{@"alert": @NO, @"badge": @NO, @"sound": @NO}]);
        return;
    }

    callback(@[[self checkPermissions]]);
}

RCT_EXPORT_METHOD(presentLocalNotification:(UILocalNotification *)notification)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [RCTSharedApplication() presentLocalNotificationNow:notification];
    });
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

@end
