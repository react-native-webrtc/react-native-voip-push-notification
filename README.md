# React Native VoIP Push Notification

[![npm version](https://badge.fury.io/js/react-native-voip-push-notification.svg)](https://badge.fury.io/js/react-native-voip-push-notification)
[![npm downloads](https://img.shields.io/npm/dm/react-native-voip-push-notification.svg?maxAge=2592000)](https://img.shields.io/npm/dm/react-native-voip-push-notification.svg?maxAge=2592000)

React Native VoIP Push Notification - Currently iOS >= 8.0 only

## Motivation

Since iOS 8.0 there is an execellent feature called **VoIP Push Notification** ([PushKit][1]), while in React Native only the traditional push notification is supported which limits the possibilities of building a VoIP app with React Native (like me!).

To understand the benefits of **Voip Push Notification**, please see [VoIP Best Practices][2].

**Note 1**: Not sure if Android support this sort of stuff since I'm neither an iOS nor Android expert, from my limited understanding that GCM's [sending high priority push notification][5] might be the case. Correct me if I'm wrong!

**Note 2** This module is inspired by [PushNotificationIOS][6] and [React Native Push Notification][7]

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

...

/* Add PushKit delegate method */

// --- Handle updated push credentials
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
  // Register VoIP push token (a property of PKPushCredentials) with server
  [RNVoipPushNotificationManager didUpdatePushCredentials:credentials forType:(NSString *)type];
}

// --- Handle incoming pushes (for ios <= 10)
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
  [RNVoipPushNotificationManager didReceiveIncomingPushWithPayload:payload forType:(NSString *)type];
}

// --- Handle incoming pushes (for ios >= 11)
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion {
  
  // --- Process the received push
  [RNVoipPushNotificationManager didReceiveIncomingPushWithPayload:payload forType:(NSString *)type];

  // --- NOTE: apple forced us to invoke callkit ASAP when we receive voip push
  // --- see: react-native-callkeep

  // --- Retrieve information from your voip push payload
  NSString *uuid = payload.dictionaryPayload[@"uuid"];
  NSString *callerName = [NSString stringWithFormat:@"%@ (Connecting...)", payload.dictionaryPayload[@"callerName"]];
  NSString *handle = payload.dictionaryPayload[@"handle"];

  // --- You should make sure to report to callkit BEFORE execute `completion()`
  [RNCallKeep reportNewIncomingCall:uuid handle:handle handleType:@"generic" hasVideo:false localizedCallerName:callerName fromPushKit: YES];
    
  completion();
}
...

@end

```

## Linking:

On RN60+, auto linking with pod file should work.  
Or you can try below:

## Linking Manually:

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

## Usage:

```javascript

...

import VoipPushNotification from 'react-native-voip-push-notification';

...

class MyComponent extends React.Component {

...

  componentDidMount() { // or anywhere which is most comfortable and appropriate for you
    VoipPushNotification.requestPermissions(); // --- optional, you can use another library to request permissions
    VoipPushNotification.registerVoipToken(); // --- required
  
    VoipPushNotification.addEventListener('register', (token) => {
      // --- send token to your apn provider server
    });

    VoipPushNotification.addEventListener('localNotification', (notification) => {
      // --- when user click local push
    });

    VoipPushNotification.addEventListener('notification', (notification) => {
      // --- when receive remote voip push, register your VoIP client, show local notification ... etc
      //this.doRegisterOrSomething();
      
       // --- This  is a boolean constant exported by this module
       // --- you can use this constant to distinguish the app is launched by VoIP push notification or not
       if (VoipPushNotification.wakeupByPush) {
         // this.doSomething()

         // --- remember to set this static variable back to false
         // --- since the constant are exported only at initialization time, and it will keep the same in the whole app
         VoipPushNotification.wakeupByPush = false;
       }

      /**
       * Local Notification Payload
       *
       * - `alertBody` : The message displayed in the notification alert.
       * - `alertAction` : The "action" displayed beneath an actionable notification. Defaults to "view";
       * - `soundName` : The sound played when the notification is fired (optional).
       * - `category`  : The category of this notification, required for actionable notifications (optional).
       * - `userInfo`  : An optional object containing additional notification data.
       */
      VoipPushNotification.presentLocalNotification({
          alertBody: "hello! " + notification.getMessage()
      });
    });
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
[5]: https://developers.google.com/cloud-messaging/concept-options#setting-the-priority-of-a-message
[6]: https://facebook.github.io/react-native/docs/pushnotificationios.html
[7]: https://github.com/zo0r/react-native-push-notification
