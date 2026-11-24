#import <Foundation/Foundation.h>

#import <math.h>

#import "RNVoipPushPayloadSerialization.h"

static void RNVoipAssert(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL RNVoipCanSerialize(id object)
{
    @try {
        NSError *error = nil;
        return [NSJSONSerialization isValidJSONObject:object] &&
            [NSJSONSerialization dataWithJSONObject:object options:0 error:&error] != nil &&
            error == nil;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

int main(void)
{
    @autoreleasepool {
        NSDictionary *validPayload = @{
            @"": @"empty-key-value",
            @"caller": @"Alice 📞",
            @"nested": @{ @"numbers": @[ @1, @2, @3 ] },
            @"_rnvoip_payload_sanitized": @NO,
        };
        BOOL didSanitize = YES;
        NSDictionary *validResult = RNVoipPushPayloadForBridge(validPayload, &didSanitize);
        RNVoipAssert(validResult == validPayload, @"valid payload must preserve object identity");
        RNVoipAssert(!didSanitize, @"valid payload must not be marked sanitized");
        RNVoipAssert([validResult[@""] isEqual:@"empty-key-value"], @"valid empty-string key must be preserved");
        RNVoipAssert(![validResult[@"_rnvoip_payload_sanitized"] boolValue], @"valid payload must preserve a caller-provided marker key");

        NSDictionary *nonFinitePayload = @{
            @"": @"still-present",
            @"caller": @"Bob 📞",
            @"value": @(NAN),
            @"positiveInfinity": @(INFINITY),
            @"negativeInfinity": @(-INFINITY),
            @"_rnvoip_payload_sanitized": @NO,
        };
        didSanitize = NO;
        NSDictionary *nonFiniteResult = RNVoipPushPayloadForBridge(nonFinitePayload, &didSanitize);
        RNVoipAssert(didSanitize, @"NaN payload must be sanitized");
        RNVoipAssert(RNVoipCanSerialize(nonFiniteResult), @"sanitized NaN payload must serialize");
        RNVoipAssert(nonFiniteResult[@"value"] == [NSNull null], @"NaN must become null, not a misleading number");
        RNVoipAssert(nonFiniteResult[@"positiveInfinity"] == [NSNull null], @"positive infinity must become null");
        RNVoipAssert(nonFiniteResult[@"negativeInfinity"] == [NSNull null], @"negative infinity must become null");
        RNVoipAssert([nonFiniteResult[@""] isEqual:@"still-present"], @"empty-string key must survive sanitization");
        RNVoipAssert([nonFiniteResult[@"caller"] isEqual:@"Bob 📞"], @"valid Unicode must survive sanitization");
        RNVoipAssert([nonFiniteResult[@"_rnvoip_payload_sanitized"] boolValue], @"sanitized payload must carry a marker");

        NSDictionary *unsupportedValuePayload = @{ @"date": [NSDate dateWithTimeIntervalSince1970:0] };
        didSanitize = NO;
        NSDictionary *unsupportedValueResult = RNVoipPushPayloadForBridge(unsupportedValuePayload, &didSanitize);
        RNVoipAssert(didSanitize, @"unsupported value payload must be sanitized");
        RNVoipAssert(unsupportedValueResult[@"date"] == [NSNull null], @"unsupported value must become null");
        RNVoipAssert(RNVoipCanSerialize(unsupportedValueResult), @"unsupported value result must serialize");

        NSDictionary *nonStringKeyPayload = [NSDictionary dictionaryWithObject:@"value" forKey:@42];
        didSanitize = NO;
        NSDictionary *nonStringKeyResult = RNVoipPushPayloadForBridge(nonStringKeyPayload, &didSanitize);
        RNVoipAssert(didSanitize, @"non-string key payload must be sanitized");
        RNVoipAssert(nonStringKeyResult.count == 1, @"non-string key must use the generic fallback");
        RNVoipAssert([nonStringKeyResult[@"_rnvoip_payload_sanitized"] boolValue], @"fallback must carry a marker");

        unichar loneSurrogateCharacter = 0xD800;
        NSString *loneSurrogate = [NSString stringWithCharacters:&loneSurrogateCharacter length:1];
        NSDictionary *surrogatePayload = @{ @"caller": loneSurrogate, @"emoji": @"📞" };
        BOOL rawSurrogateSerializes = RNVoipCanSerialize(surrogatePayload);
        didSanitize = NO;
        NSDictionary *surrogateResult = RNVoipPushPayloadForBridge(surrogatePayload, &didSanitize);
        RNVoipAssert(RNVoipCanSerialize(surrogateResult), @"lone-surrogate result must serialize");
        if (!rawSurrogateSerializes) {
            RNVoipAssert(didSanitize, @"invalid lone surrogate must take the sanitize path");
            RNVoipAssert([surrogateResult[@"emoji"] isEqual:@"📞"], @"unrelated valid Unicode must remain intact");
        }

        id deeplyNestedValue = @(NAN);
        for (NSUInteger depth = 0; depth < 70; depth++) {
            deeplyNestedValue = @[ deeplyNestedValue ];
        }
        NSDictionary *deepPayload = @{ @"value": deeplyNestedValue };
        didSanitize = NO;
        NSDictionary *deepResult = RNVoipPushPayloadForBridge(deepPayload, &didSanitize);
        RNVoipAssert(didSanitize, @"overly deep invalid payload must be sanitized");
        RNVoipAssert(deepResult.count == 1, @"overly deep payload must use the generic fallback");
        RNVoipAssert(RNVoipCanSerialize(deepResult), @"generic fallback must serialize");

        didSanitize = NO;
        NSDictionary *nilResult = RNVoipPushPayloadForBridge(nil, &didSanitize);
        RNVoipAssert(didSanitize, @"nil payload must be sanitized");
        RNVoipAssert([nilResult[@"_rnvoip_payload_sanitized"] boolValue], @"nil fallback must carry a marker");

        printf("RNVoipPushPayloadSerializationTests: PASS\n");
    }
    return 0;
}
