//
//  RNVoipPushNotificationManager.m
//  RNVoipPushNotification
//
//  Copyright 2016-2020 The react-native-voip-push-notification Contributors
//  see: https://github.com/react-native-webrtc/react-native-voip-push-notification/graphs/contributors
//  SPDX-License-Identifier: ISC, MIT
//

#import <PushKit/PushKit.h>
#import "RNVoipPushNotificationManager.h"

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>

NSString *const RNVoipPushRemoteNotificationsRegisteredEvent = @"RNVoipPushRemoteNotificationsRegisteredEvent";
NSString *const RNVoipPushRemoteNotificationReceivedEvent = @"RNVoipPushRemoteNotificationReceivedEvent";
NSString *const RNVoipPushDidLoadWithEvents = @"RNVoipPushDidLoadWithEvents";

// --- Return a guaranteed JSON-serializable string. Unpaired UTF-16 surrogates
// --- pass +isValidJSONObject: yet still make -dataWithJSONObject: throw, so we
// --- use NSJSONSerialization itself as the oracle: original -> lossy ASCII -> "".
static NSString *RNVoipSafeString(NSString *string)
{
    if (![string isKindOfClass:[NSString class]] || string.length == 0) {
        return @"";
    }
    NSData *asciiData = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *asciiLossy = asciiData ? [[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding] : nil;
    NSArray<NSString *> *candidates = @[ string, asciiLossy ?: @"", @"" ];
    for (NSString *candidate in candidates) {
        @try {
            NSError *error = nil;
            if ([NSJSONSerialization dataWithJSONObject:@[ candidate ] options:0 error:&error] != nil && error == nil) {
                return candidate;
            }
        } @catch (NSException *exception) {
            // try the next, more conservative candidate
        }
    }
    return @"";
}

// --- Recursively coerce any object into a JSON-safe representation so the RN
// --- bridge's NSJSONSerialization can never throw NSInvalidArgumentException
// --- (observed as a SIGABRT on the iOS 26 SDK).
static id RNVoipSanitizeJSONObject(id object)
{
    if (object == nil || [object isKindOfClass:[NSNull class]]) {
        return [NSNull null];
    }
    if ([object isKindOfClass:[NSString class]]) {
        return RNVoipSafeString((NSString *)object);
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        double value = [(NSNumber *)object doubleValue];
        if (isnan(value) || isinf(value)) { return @0; } // NaN/Infinity are not valid JSON
        return object;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[(NSArray *)object count]];
        for (id element in (NSArray *)object) {
            [result addObject:RNVoipSanitizeJSONObject(element)];
        }
        return result;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)object count]];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? RNVoipSafeString((NSString *)key) : RNVoipSafeString([key description]);
            if (stringKey.length > 0) {
                result[stringKey] = RNVoipSanitizeJSONObject(value);
            }
        }];
        return result;
    }
    return RNVoipSafeString([object description]); // NSData / NSDate / custom -> string
}

// --- Return a body the RN bridge is GUARANTEED to serialize. The bridge runs
// --- NSJSONSerialization on the JS thread asynchronously, so a @try/@catch
// --- around sendEventWithName: cannot catch the throw; we therefore pre-flight
// --- the exact serialization HERE and only forward a proven-safe body.
static id RNVoipSerializableBodyOrFallback(NSDictionary *rawPayload)
{
    id sanitized = RNVoipSanitizeJSONObject(rawPayload);
    @try {
        if ([NSJSONSerialization isValidJSONObject:sanitized]) {
            NSError *error = nil;
            if ([NSJSONSerialization dataWithJSONObject:sanitized options:0 error:&error] != nil && error == nil) {
                return sanitized;
            }
        }
    } @catch (NSException *exception) {
        // fall through to the minimal payload below
    }
    NSLog(@"[RNVoipPushNotification] PushKit payload not JSON-serializable after sanitize; forwarding minimal fallback.");
    NSDictionary *raw = [rawPayload isKindOfClass:[NSDictionary class]] ? rawPayload : @{};
    return @{ @"_rnvoip_sanitized": @YES,
              @"voip_call_id": RNVoipSafeString([raw[@"voip_call_id"] description]) };
}

@implementation RNVoipPushNotificationManager
{
    bool _hasListeners;
    NSMutableArray *_delayedEvents;
}

RCT_EXPORT_MODULE();

static bool _isVoipRegistered = NO;
static NSString *_lastVoipToken = @"";
static NSMutableDictionary<NSString *, RNVoipPushNotificationCompletion> *completionHandlers = nil;

// =====
// ===== RN Module Configure and Override =====
// =====

-(instancetype) init
{
    return [[self class] sharedInstance];
}

-(instancetype) initPrivate
{
    if (self = [super init]) {
        _delayedEvents = [NSMutableArray array];
    }

    return self;
}

// Singletone implementation based on https://stackoverflow.com/q/5720029/3686678 and https://stackoverflow.com/a/7035136/3686678
+(instancetype) sharedInstance
{
    static RNVoipPushNotificationManager *sharedVoipPushManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedVoipPushManager = [[self alloc] initPrivate];
    });

    return sharedVoipPushManager;
}

// --- clean observer and completionHandlers when app close
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // --- invoke complete() and remove for all completionHanders
    for (NSString *uuid in [RNVoipPushNotificationManager completionHandlers]) {
        RNVoipPushNotificationCompletion completion = [[RNVoipPushNotificationManager completionHandlers] objectForKey:uuid];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    }

    [[RNVoipPushNotificationManager completionHandlers] removeAllObjects];
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

// --- Override method of RCTEventEmitter
- (NSArray<NSString *> *)supportedEvents
{
    return @[
        RNVoipPushRemoteNotificationsRegisteredEvent,
        RNVoipPushRemoteNotificationReceivedEvent,
        RNVoipPushDidLoadWithEvents
    ];
}

- (void)startObserving
{
    _hasListeners = YES;
    if ([_delayedEvents count] > 0) {
        [self sendEventWithName:RNVoipPushDidLoadWithEvents body:_delayedEvents];
    }
}


// =====
// ===== Class Method =====
// =====

// --- send directly if has listeners, cache it otherwise
- (void)sendEventWithNameWrapper:(NSString *)name body:(id)body {
    if (_hasListeners) {
        [self sendEventWithName:name body:body];
    } else {
        NSDictionary *dictionary = @{
            @"name": name,
            @"data": body
        };
        [_delayedEvents addObject:dictionary];
    }
}

// --- register delegate for PushKit to delivery credential and remote voip push to your delegate
// --- this usually register once and ASAP after your app launch
+ (void)voipRegistration
{
    if (_isVoipRegistered) {
#ifdef DEBUG
        RCTLog(@"[RNVoipPushNotificationManager] voipRegistration is already registered. return _lastVoipToken = %@", _lastVoipToken);
#endif
        RNVoipPushNotificationManager *voipPushManager = [RNVoipPushNotificationManager sharedInstance];
        [voipPushManager sendEventWithNameWrapper:RNVoipPushRemoteNotificationsRegisteredEvent body:_lastVoipToken];
    } else {
        _isVoipRegistered = YES;
#ifdef DEBUG
        RCTLog(@"[RNVoipPushNotificationManager] voipRegistration enter");
#endif
        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        dispatch_async(mainQueue, ^{
            // --- Create a push registry object
            PKPushRegistry * voipRegistry = [[PKPushRegistry alloc] initWithQueue: mainQueue];
            // --- Set the registry's delegate to AppDelegate
            voipRegistry.delegate = (RNVoipPushNotificationManager *)RCTSharedApplication().delegate;
            // ---  Set the push type to VoIP
            voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
        });
    }
}

// --- should be called from `AppDelegate.didUpdatePushCredentials`
+ (void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type
{
#ifdef DEBUG
    RCTLog(@"[RNVoipPushNotificationManager] didUpdatePushCredentials credentials.token = %@, type = %@", credentials.token, type);
#endif
    NSUInteger voipTokenLength = credentials.token.length;
    if (voipTokenLength == 0) {
        return;
    }

    NSMutableString *hexString = [NSMutableString string];
    const unsigned char *bytes = credentials.token.bytes;
    for (NSUInteger i = 0; i < voipTokenLength; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }

    _lastVoipToken = [hexString copy];

    RNVoipPushNotificationManager *voipPushManager = [RNVoipPushNotificationManager sharedInstance];
    [voipPushManager sendEventWithNameWrapper:RNVoipPushRemoteNotificationsRegisteredEvent body:_lastVoipToken];
}

// --- should be called from `AppDelegate.didReceiveIncomingPushWithPayload`
+ (void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
#ifdef DEBUG
    RCTLog(@"[RNVoipPushNotificationManager] didReceiveIncomingPushWithPayload payload.dictionaryPayload = %@, type = %@", payload.dictionaryPayload, type);
#endif

    RNVoipPushNotificationManager *voipPushManager = [RNVoipPushNotificationManager sharedInstance];
    // iOS 26 SIGABRT fix: the RN bridge serializes the event body with
    // NSJSONSerialization asynchronously on the JS thread, so a @try/@catch
    // around sendEventWithName: cannot catch the throw. Pre-flight the exact
    // serialization here and only forward a body proven to serialize.
    id safeBody = RNVoipSerializableBodyOrFallback(payload.dictionaryPayload);
    [voipPushManager sendEventWithNameWrapper:RNVoipPushRemoteNotificationReceivedEvent body:safeBody];
}

// --- getter for completionHandlers
+ (NSMutableDictionary *)completionHandlers {
    if (completionHandlers == nil) {
        completionHandlers = [NSMutableDictionary new];
    }
    return completionHandlers;
}

+ (void)addCompletionHandler:(NSString *)uuid completionHandler:(RNVoipPushNotificationCompletion)completionHandler
{
    self.completionHandlers[uuid] = completionHandler;
}

+ (void)removeCompletionHandler:(NSString *)uuid
{
    self.completionHandlers[uuid] = nil;
    [self.completionHandlers removeObjectForKey:uuid];
}


// =====
// ===== React Method =====
// =====


// --- register voip push token
RCT_EXPORT_METHOD(registerVoipToken)
{
    if (RCTRunningInAppExtension()) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [RNVoipPushNotificationManager voipRegistration];
    });
}

// --- called from js when finished to process incoming voip push
RCT_EXPORT_METHOD(onVoipNotificationCompleted:(NSString *)uuid)
{
    RNVoipPushNotificationCompletion completion = [[RNVoipPushNotificationManager completionHandlers] objectForKey:uuid];
    if (completion) {
#ifdef DEBUG
        RCTLog(@"[RNVoipPushNotificationManager] onVoipNotificationCompleted() complete(). uuid = %@", uuid);
#endif
        [RNVoipPushNotificationManager removeCompletionHandler: uuid];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
        return;
    }

#ifdef DEBUG
    RCTLog(@"[RNVoipPushNotificationManager] onVoipNotificationCompleted() not found. uuid = %@", uuid);
#endif
}

@end
