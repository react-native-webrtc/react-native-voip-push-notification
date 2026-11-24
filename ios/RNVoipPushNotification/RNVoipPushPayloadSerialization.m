//
//  RNVoipPushPayloadSerialization.m
//  RNVoipPushNotification
//

#import "RNVoipPushPayloadSerialization.h"

#import <math.h>

static NSString *const RNVoipPayloadSanitizedKey = @"_rnvoip_payload_sanitized";
static NSUInteger const RNVoipPayloadMaximumDepth = 64;

static BOOL RNVoipJSONObjectCanSerialize(id object)
{
    @try {
        if (![NSJSONSerialization isValidJSONObject:object]) {
            return NO;
        }
        NSError *error = nil;
        return [NSJSONSerialization dataWithJSONObject:object options:0 error:&error] != nil && error == nil;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static NSString *RNVoipSafeString(NSString *string)
{
    if (![string isKindOfClass:[NSString class]]) {
        return @"";
    }
    if (RNVoipJSONObjectCanSerialize(@[ string ])) {
        return string;
    }

    NSData *utf8Data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSString *lossyString = utf8Data ? [[NSString alloc] initWithData:utf8Data encoding:NSUTF8StringEncoding] : nil;
    if (lossyString && RNVoipJSONObjectCanSerialize(@[ lossyString ])) {
        return lossyString;
    }
    return @"";
}

static id _Nullable RNVoipSanitizeJSONObject(id _Nullable object, NSUInteger depth)
{
    if (depth > RNVoipPayloadMaximumDepth) {
        return nil;
    }
    if (object == nil || [object isKindOfClass:[NSNull class]]) {
        return [NSNull null];
    }
    if ([object isKindOfClass:[NSString class]]) {
        return RNVoipSafeString((NSString *)object);
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        return isfinite([(NSNumber *)object doubleValue]) ? object : [NSNull null];
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[(NSArray *)object count]];
        for (id element in (NSArray *)object) {
            id sanitizedElement = RNVoipSanitizeJSONObject(element, depth + 1);
            if (sanitizedElement == nil) {
                return nil;
            }
            [result addObject:sanitizedElement];
        }
        return [result copy];
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)object count]];
        __block BOOL failed = NO;
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if (![key isKindOfClass:[NSString class]]) {
                failed = YES;
                *stop = YES;
                return;
            }
            NSString *sanitizedKey = RNVoipSafeString((NSString *)key);
            if (result[sanitizedKey] != nil) {
                failed = YES;
                *stop = YES;
                return;
            }
            id sanitizedValue = RNVoipSanitizeJSONObject(value, depth + 1);
            if (sanitizedValue == nil) {
                failed = YES;
                *stop = YES;
                return;
            }
            result[sanitizedKey] = sanitizedValue;
        }];
        return failed ? nil : [result copy];
    }

    return [NSNull null];
}

NSDictionary *RNVoipPushPayloadForBridge(NSDictionary *rawPayload, BOOL *didSanitize)
{
    if (didSanitize != NULL) {
        *didSanitize = NO;
    }
    if ([rawPayload isKindOfClass:[NSDictionary class]] && RNVoipJSONObjectCanSerialize(rawPayload)) {
        return rawPayload;
    }

    if (didSanitize != NULL) {
        *didSanitize = YES;
    }
    @try {
        id sanitized = RNVoipSanitizeJSONObject(rawPayload, 0);
        if ([sanitized isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *markedPayload = [(NSDictionary *)sanitized mutableCopy];
            markedPayload[RNVoipPayloadSanitizedKey] = @YES;
            NSDictionary *result = [markedPayload copy];
            if (RNVoipJSONObjectCanSerialize(result)) {
                return result;
            }
        }
    } @catch (__unused NSException *exception) {
        // Fall through to a generic, serializable marker payload.
    }

    return @{ RNVoipPayloadSanitizedKey: @YES };
}
