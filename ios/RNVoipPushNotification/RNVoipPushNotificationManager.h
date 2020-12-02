//
//  RNVoipPushNotificationManager.h
//  RNVoipPushNotification
//
//  Copyright 2016-2020 The react-native-voip-push-notification Contributors
//  see: https://github.com/react-native-webrtc/react-native-voip-push-notification/graphs/contributors
//  SPDX-License-Identifier: ISC, MIT
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RNVoipPushNotificationManager : RCTEventEmitter <RCTBridgeModule>

typedef void (^RNVoipPushNotificationCompletion)(void);

@property (nonatomic, strong) NSMutableDictionary<NSString *, RNVoipPushNotificationCompletion> *completionHandlers;

+ (void)voipRegistration;
+ (void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type;
+ (void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type;
+ (void)addCompletionHandler:(NSString *)uuid completionHandler:(RNVoipPushNotificationCompletion)completionHandler;
+ (void)removeCompletionHandler:(NSString *)uuid;

@end
