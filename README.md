# React Native VoIP Push Notification

[![npm version](https://badge.fury.io/js/react-native-voip-push-notification.svg)](https://badge.fury.io/js/react-native-voip-push-notification)
[![npm downloads](https://img.shields.io/npm/dm/react-native-voip-push-notification.svg?maxAge=2592000)](https://img.shields.io/npm/dm/react-native-voip-push-notification.svg?maxAge=2592000)

React Native VoIP Push Notification - Currently iOS >= 8.0 only

## RN Version

* 1.1.0+ ( RN 40+ )
* 2.0.0+ (RN 60+)

## !!IMPORTANT NOTE!!

#### You should use this module with CallKit:

Now Apple forced us to invoke CallKit ASAP when we receive voip push on iOS 13 and later, so you should check [react-native-callkeep](https://github.com/react-native-webrtc/react-native-callkeep) as well.

#### Please read below links carefully:

https://developer.apple.com/documentation/pushkit/pkpushregistrydelegate/2875784-pushregistry

> When linking against the iOS 13 SDK or later, your implementation of this method must report notifications of type voIP to the CallKit framework by calling the reportNewIncomingCall(with:update:completion:) method
>
> On iOS 13.0 and later, if you fail to report a call to CallKit, the system will terminate your app.
> 
> Repeatedly failing to report calls may cause the system to stop delivering any more VoIP push notifications to your app.
> 
> If you want to initiate a VoIP call without using CallKit, register for push notifications using the UserNotifications framework instead of PushKit. For more information, see UserNotifications.

#### Issue introduced in this change:

When received VoipPush, we should present CallKit ASAP even before RN instance initialization.  
  
This breaks especially if you handled almost call behavior at js side, for example:  
Do-Not-Disturb / check if Ghost-Call / using some sip libs to register or waiting invite...etc.  
  
Staff from Apple gives some advisions for these issues in the below discussion:
https://forums.developer.apple.com/thread/117939

#### You may need to change your server for APN voip push:

Especially `apns-push-type` value should be `'voip'` for iOS 13  
And be aware of `apns-expiration`value, adjust according to your call logics  
  
https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/sending_notification_requests_to_apns

#### About Silent Push ( Background Push ):

VoIP pushes were intended to specifically support incoming call notifications and nothing else.   

If you were using voip push to do things other than `nootify incoming call`, such as: `cancel call` / `background updates`...etc,  You should change to use [Notification Service Extension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension), it contains different kind of pushs.

To  use`Background Push` to [Pushing Background Updates to Your App](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/pushing_background_updates_to_your_app),
You should:
1. Make sure you enabled `Xcode` -> `Signing & Capabilities` -> `Background Modes` -> `Remote Notifications` enabled
2. When sending background push from your APN back-end, the push header / payload should set:
    * content-available = 1
    * apns-push-type = 'background'
    * apns-priority = 5


## Installation

```bash
npm install --save react-native-voip-push-notification
# --- if using pod
cd ios/ && pod install
```

The iOS version should be >= 8.0 since we are using [PushKit][1].

#### Enable VoIP Push Notification and Get VoIP Certificate

Please refer to [VoIP Best Practices][2].

Make sure you enabled the folowing in `Xcode` -> `Signing & Capabilities`:
* `Background Modes` -> `Voice over IP` enabled
* `+Capability` -> `Push Notifications`

#### AppDelegate.m Modification

```objective-c

...

#import <PushKit/PushKit.h>                    /* <------ add this line */
#import "RNVoipPushNotificationManager.h"      /* <------ add this line */

...

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  


  // ===== (THIS IS OPTIONAL BUT RECOMMENDED) =====
  // --- register VoipPushNotification here ASAP rather than in JS. Doing this from the JS side may be too slow for some use cases
  // --- see: https://github.com/react-native-webrtc/react-native-voip-push-notification/issues/59#issuecomment-691685841
  [RNVoipPushNotificationManager voipRegistration];
  // ===== (THIS IS OPTIONAL BUT RECOMMENDED) =====



  RCTRootView *rootView = [[RCTRootView alloc] initWithBridge:bridge moduleName:@"AppName" initialProperties:nil];
}

...

/* Add PushKit delegate method */

// --- Handle updated push credentials
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
  // Register VoIP push token (a property of PKPushCredentials) with server
  [RNVoipPushNotificationManager didUpdatePushCredentials:credentials forType:(NSString *)type];
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type
{
  // --- The system calls this method when a previously provided push token is no longer valid for use. No action is necessary on your part to reregister the push type. Instead, use this method to notify your server not to send push notifications using the matching push token.
}

// --- Handle incoming pushes
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion {
  

  // --- NOTE: apple forced us to invoke callkit ASAP when we receive voip push
  // --- see: react-native-callkeep

  // --- Retrieve information from your voip push payload
  NSString *uuid = payload.dictionaryPayload[@"uuid"];
  NSString *callerName = [NSString stringWithFormat:@"%@ (Connecting...)", payload.dictionaryPayload[@"callerName"]];
  NSString *handle = payload.dictionaryPayload[@"handle"];

  // --- this is optional, only required if you want to call `completion()` on the js side
  [RNVoipPushNotificationManager addCompletionHandler:uuid completionHandler:completion];

  // --- Process the received push
  [RNVoipPushNotificationManager didReceiveIncomingPushWithPayload:payload forType:(NSString *)type];

  // --- You should make sure to report to callkit BEFORE execute `completion()`
  [RNCallKeep reportNewIncomingCall:uuid handle:handle handleType:@"generic" hasVideo:false localizedCallerName:callerName fromPushKit: YES payload:nil];
  
  // --- You don't need to call it if you stored `completion()` and will call it on the js side.
  completion();
}
...

@end

```

## Linking:

On RN60+, auto linking with pod file should work.  
<details>
  <summary>Linking Manually</summary>

  ### Add PushKit Framework:
  
  - In your Xcode project, select `Build Phases` --> `Link Binary With Libraries`
  - Add `PushKit.framework`
  
  ### Add RNVoipPushNotification:
  
  #### Option 1: Use [rnpm][3]
  
  ```bash
  rnpm link react-native-voip-push-notification
  ```
  
  **Note**: If you're using rnpm link make sure the `Header Search Paths` is `recursive`. (In step 3 of manually linking)
  
  #### Option 2: Manually
  
  1. Drag `node_modules/react-native-voip-push-notification/ios/RNVoipPushNotification.xcodeproj` under `<your_xcode_project>/Libraries`
  2. Select `<your_xcode_project>` --> `Build Phases` --> `Link Binary With Libraries`
    - Drag `Libraries/RNVoipPushNotification.xcodeproj/Products/libRNVoipPushNotification.a` to `Link Binary With Libraries`
  3. Select `<your_xcode_project>` --> `Build Settings`
    - In `Header Search Paths`, add `$(SRCROOT)/../node_modules/react-native-voip-push-notification/ios/RNVoipPushNotification` with `recursive`
</details>

## API and Usage:

#### Native API:

Voip Push is time sensitive, these native API mainly used in AppDelegate.m, especially before JS bridge is up.
This usually

* `(void)voipRegistration` --- 
  register delegate for PushKit if you like to register in AppDelegate.m ASAP instead JS side ( too late for some use cases )
* `(void)didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type` ---
  call this api to fire 'register' event to JS
* `(void)didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type` ---
  call this api to fire 'notification' event to JS
* `(void)addCompletionHandler:(NSString *)uuid completionHandler:(RNVoipPushNotificationCompletion)completionHandler` ---
  add completionHandler to RNVoipPush module
* `(void)removeCompletionHandler:(NSString *)uuid` ---
  remove completionHandler to RNVoipPush module

#### JS API:

* `registerVoipToken()` --- JS method to register PushKit delegate
* `onVoipNotificationCompleted(notification.uuid)` --- JS mehtod to tell PushKit we have handled received voip push

#### Events:

* `'register'` --- fired when PushKit give us the latest token
* `'notification'` --- fired when received voip push notification
* `'didLoadWithEvents'` --- fired when there are not-fired events been cached before js bridge is up

```javascript

...

import VoipPushNotification from 'react-native-voip-push-notification';

...

class MyComponent extends React.Component {

...

    // --- anywhere which is most comfortable and appropriate for you,
    // --- usually ASAP, ex: in your app.js or at some global scope.
    componentDidMount() {

        // --- NOTE: You still need to subscribe / handle the rest events as usuall.
        // --- This is just a helper whcih cache and propagate early fired events if and only if for
        // --- "the native events which DID fire BEFORE js bridge is initialed",
        // --- it does NOT mean this will have events each time when the app reopened.


        // ===== Step 1: subscribe `register` event =====
        // --- this.onVoipPushNotificationRegistered
        VoipPushNotification.addEventListener('register', (token) => {
            // --- send token to your apn provider server
        });

        // ===== Step 2: subscribe `notification` event =====
        // --- this.onVoipPushNotificationiReceived
        VoipPushNotification.addEventListener('notification', (notification) => {
            // --- when receive remote voip push, register your VoIP client, show local notification ... etc
            this.doSomething();
          
            // --- optionally, if you `addCompletionHandler` from the native side, once you have done the js jobs to initiate a call, call `completion()`
            VoipPushNotification.onVoipNotificationCompleted(notification.uuid);
        });

        // ===== Step 3: subscribe `didLoadWithEvents` event =====
        VoipPushNotification.addEventListener('didLoadWithEvents', (events) => {
            // --- this will fire when there are events occured before js bridge initialized
            // --- use this event to execute your event handler manually by event type

            if (!events || !Array.isArray(events) || events.length < 1) {
                return;
            }
            for (let voipPushEvent of events) {
                let { name, data } = voipPushEvent;
                if (name === VoipPushNotification.RNVoipPushRemoteNotificationsRegisteredEvent) {
                    this.onVoipPushNotificationRegistered(data);
                } else if (name === VoipPushNotification.RNVoipPushRemoteNotificationReceivedEvent) {
                    this.onVoipPushNotificationiReceived(data);
                }
            }
        });

        // ===== Step 4: register =====
        // --- it will be no-op if you have subscribed before (like in native side)
        // --- but will fire `register` event if we have latest cahced voip token ( it may be empty if no token at all )
        VoipPushNotification.registerVoipToken(); // --- register token
    }

    // --- unsubscribe event listeners
    componentWillUnmount() {
        VoipPushNotification.removeEventListener('didLoadWithEvents');
        VoipPushNotification.removeEventListener('register');
        VoipPushNotification.removeEventListener('notification');
    }
...
}

```

## Original Author:

[![ianlin](https://avatars1.githubusercontent.com/u/914406?s=48)](https://github.com/ianlin)

## License

[ISC License][4] (functionality equivalent to **MIT License**)

[1]: https://developer.apple.com/library/ios/documentation/NetworkingInternet/Reference/PushKit_Framework/index.html
[2]: https://developer.apple.com/library/ios/documentation/Performance/Conceptual/EnergyGuide-iOS/OptimizeVoIP.html
[3]: https://github.com/rnpm/rnpm
[4]: https://opensource.org/licenses/ISC
