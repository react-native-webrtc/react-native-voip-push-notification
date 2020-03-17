//
//  RNVoipPushNotificationManager.h
//  RNVoipPushNotification
//
//  Created by Ian Yu-Hsun Lin on 4/18/16.
//  Copyright © 2016 ianyuhsunlin. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <React/RCTBridgeModule.h>

@interface RNVoipPushNotificationManager : NSObject <RCTBridgeModule>

typedef void (^RNVoipPushNotificationCompletion)(void);

@property (nonatomic, strong) NSMutableDictionary<NSString *, RNVoipPushNotificationCompletion> *completionHandlers;

- (void)voipRegistration;
- (void)registerUserNotification:(NSDictionary *)permissions;
- (NSDictionary *)checkPermissions;
+ (void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type;
+ (void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type;
+ (NSString *)getCurrentAppBackgroundState;
+ (void)addCompletionHandler:(NSString *)uuid completionHandler:(RNVoipPushNotificationCompletion)completionHandler;
+ (void)removeCompletionHandler:(NSString *)uuid;

@end
