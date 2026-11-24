//
//  RNVoipPushPayloadSerialization.h
//  RNVoipPushNotification
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSDictionary *RNVoipPushPayloadForBridge(NSDictionary * _Nullable rawPayload,
                                                            BOOL * _Nullable didSanitize);

NS_ASSUME_NONNULL_END
