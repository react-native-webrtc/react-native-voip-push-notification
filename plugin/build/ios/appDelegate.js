"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.withIosAppDelegate = void 0;
const config_plugins_1 = require("@expo/config-plugins");
const generateCode_1 = require("@expo/config-plugins/build/utils/generateCode");
const withIosAppDelegate = (config) => {
    return (0, config_plugins_1.withAppDelegate)(config, (cfg) => {
        const { modResults } = cfg;
        const methodInvocationBlock = `[RNVoipPushNotificationManager voipRegistration];`;
        // https://regex101.com/r/mPgaq6/1
        const methodInvocationLineMatcher = /(?:self\.moduleName\s*=\s*@\"([^"]*)\";)|(?:(self\.|_)(\w+)\s?=\s?\[\[UMModuleRegistryAdapter alloc\])|(?:RCTBridge\s?\*\s?(\w+)\s?=\s?\[(\[RCTBridge alloc\]|self\.reactDelegate))/g;
        // https://regex101.com/r/nHrTa9/1/
        // if the above regex fails, we can use this one as a fallback:
        const fallbackInvocationLineMatcher = /-\s*\(BOOL\)\s*application:\s*\(UIApplication\s*\*\s*\)\s*\w+\s+didFinishLaunchingWithOptions:/g;
        if (!modResults.contents.includes("#import <PushKit/PushKit.h>")) {
            modResults.contents = modResults.contents.replace(/#import "AppDelegate.h"/g, `#import "AppDelegate.h"
#import <PushKit/PushKit.h>
#import "RNVoipPushNotificationManager.h"
#import "RNCallKeep.h"`);
        }
        try {
            modResults.contents = (0, generateCode_1.mergeContents)({
                tag: "RNVoipPushNotificationAppDelegate",
                src: modResults.contents,
                anchor: methodInvocationLineMatcher,
                offset: 0,
                comment: "// ",
                newSrc: methodInvocationBlock,
            }).contents;
        }
        catch (e) {
            // Fallback to the other regex
            modResults.contents = (0, generateCode_1.mergeContents)({
                tag: "RNVoipPushNotificationAppDelegate",
                src: modResults.contents,
                anchor: fallbackInvocationLineMatcher,
                offset: 0,
                comment: "// ",
                newSrc: methodInvocationBlock,
            }).contents;
        }
        // Add PushKit delegate method to the bottom of the file
        // if other appDelegates are being implemented I will need to add this to the bottom of the file
        if (!modResults.contents.includes("/* Add PushKit delegate method */")) {
            modResults.contents = modResults.contents.replace(/@end/g, `/* Add PushKit delegate method */
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type
{
    [RNVoipPushNotificationManager didUpdatePushCredentials:credentials forType:(NSString *)type];
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type
{

}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion
{
    NSString *uuid = payload.dictionaryPayload[@"uuid"];
    NSString *callerName = [NSString stringWithFormat:@"%@ (Connecting...)", payload.dictionaryPayload[@"callerName"]];
    NSString *handle = payload.dictionaryPayload[@"handle"];

    [RNVoipPushNotificationManager addCompletionHandler:uuid completionHandler:completion];

    [RNVoipPushNotificationManager didReceiveIncomingPushWithPayload:payload forType:(NSString *)type];

    [RNCallKeep reportNewIncomingCall: uuid
                handle: handle
                handleType: @"generic"
                hasVideo: NO
                localizedCallerName: callerName
                supportsHolding: YES
                supportsDTMF: YES
                supportsGrouping: YES
                supportsUngrouping: YES
                fromPushKit: YES
                payload: nil
                withCompletionHandler: completion];
}

@end`);
        }
        return cfg;
    });
};
exports.withIosAppDelegate = withIosAppDelegate;
