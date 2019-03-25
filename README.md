# React Native VoIP Push Notification

[![npm version](https://badge.fury.io/js/react-native-voip-push-notification.svg)](https://badge.fury.io/js/react-native-voip-push-notification)
[![npm downloads](https://img.shields.io/npm/dm/react-native-voip-push-notification.svg?maxAge=2592000)](https://img.shields.io/npm/dm/react-native-voip-push-notification.svg?maxAge=2592000)

React Native VoIP Push Notification - Currently iOS >= 8.0 only

## Motivation

Since iOS 8.0 there is an execellent feature called **VoIP Push Notification** ([PushKit][1]), while in React Native only the traditional push notification is supported which limits the possibilities of building a VoIP app with React Native (like me!).

To understand the benefits of **Voip Push Notification**, please see [VoIP Best Practices][2].

**Note 1**: Not sure if Android support this sort of stuff since I'm neither an iOS nor Android expert, from my limited understanding that GCM's [sending high priority push notification][5] might be the case. Correct me if I'm wrong!

**Note 2** This module is inspired by [PushNotificationIOS][6] and [React Native Push Notification][7]

## Version

If you're using React Native >= 0.40, make sure to use react-native-voip-push-notification >= 1.1.0

## Installation

```bash
npm install --save react-native-voip-push-notification
```

### iOS

The iOS version should be >= 8.0 since we are using [PushKit][1].

#### Enable VoIP Push Notification and Get VoIP Certificate

Please refer to [VoIP Best Practices][2].

**Note**: Do NOT follow the `Configure VoIP Push Notification` part from the above link, use the instruction below instead.

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

// Handle updated push credentials
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
  // Register VoIP push token (a property of PKPushCredentials) with server
  [RNVoipPushNotificationManager didUpdatePushCredentials:credentials forType:(NSString *)type];
}

// Handle incoming pushes
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
  // Process the received push
  [RNVoipPushNotificationManager didReceiveIncomingPushWithPayload:payload forType:(NSString *)type];
}

...

@end

```

#### Add PushKit Framework

- In your Xcode project, select `Build Phases` --> `Link Binary With Libraries`
- Add `PushKit.framework`

#### Add RNVoipPushNotification

##### Option 1: Use [rnpm][3]

```bash
rnpm link react-native-voip-push-notification
```

**Note**: If you're using rnpm link make sure the `Header Search Paths` is `recursive`. (In step 3 of manually linking)

##### Option 2: Manually

1. Drag `node_modules/react-native-voip-push-notification/ios/RNVoipPushNotification.xcodeproj` under `<your_xcode_project>/Libraries`
2. Select `<your_xcode_project>` --> `Build Phases` --> `Link Binary With Libraries`
  - Drag `Libraries/RNVoipPushNotification.xcodeproj/Products/libRNVoipPushNotification.a` to `Link Binary With Libraries`
3. Select `<your_xcode_project>` --> `Build Settings`
  - In `Header Search Paths`, add `$(SRCROOT)/../node_modules/react-native-voip-push-notification/ios/RNVoipPushNotification` with `recursive`

## Usage

```javascript

...

import VoipPushNotification from 'react-native-voip-push-notification';

...

class MyComponent extends React.Component {

...

  componentWillMount() { // or anywhere which is most comfortable and appropriate for you
    VoipPushNotification.requestPermissions(); // required
  
    VoipPushNotification.addEventListener('register', (token) => {
      // send token to your apn provider server
    });

    VoipPushNotification.addEventListener('notification', (notification) => {
      // register your VoIP client, show local notification, etc.
      // e.g.
      this.doRegister();
      
      /* there is a boolean constant exported by this module called
       * 
       * wakeupByPush
       * 
       * you can use this constant to distinguish the app is launched
       * by VoIP push notification or not
       *
       * e.g.
       */
       if (VoipPushNotification.wakeupByPush) {
         // do something...

         // remember to set this static variable to false
         // since the constant are exported only at initialization time
         // and it will keep the same in the whole app
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
