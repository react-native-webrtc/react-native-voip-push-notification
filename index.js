'use strict';

import {
    NativeModules,
    DeviceEventEmitter,
    Platform,
} from 'react-native';

var RNVoipPushNotificationManager = NativeModules.RNVoipPushNotificationManager;
var invariant = require('fbjs/lib/invariant');

var _notifHandlers = new Map();

var DEVICE_NOTIF_EVENT = 'voipRemoteNotificationReceived';
var NOTIF_REGISTER_EVENT = 'voipRemoteNotificationsRegistered';
var DEVICE_LOCAL_NOTIF_EVENT = 'voipLocalNotificationReceived';

export default class RNVoipPushNotification {

    static wakeupByPush = (Platform.OS == 'ios' && RNVoipPushNotificationManager.wakeupByPush === 'true');

    /**
     * Schedules the localNotification for immediate presentation.
     *
     * details is an object containing:
     *
     * - `alertBody` : The message displayed in the notification alert.
     * - `alertAction` : The "action" displayed beneath an actionable notification. Defaults to "view";
     * - `soundName` : The sound played when the notification is fired (optional).
     * - `category`  : The category of this notification, required for actionable notifications (optional).
     * - `userInfo`  : An optional object containing additional notification data.
     */
    static presentLocalNotification(details) {
        RNVoipPushNotificationManager.presentLocalNotification(details);
    }

    /**
     * Attaches a listener to remote notification events while the app is running
     * in the foreground or the background.
     *
     * Valid events are:
     *
     * - `notification` : Fired when a remote notification is received. The
     *   handler will be invoked with an instance of `PushNotificationIOS`.
     * - `register`: Fired when the user registers for remote notifications. The
     *   handler will be invoked with a hex string representing the deviceToken.
     */
    static addEventListener(type, handler) {
        invariant(
            type === 'notification' || type === 'register' || type === 'localNotification',
            'RNVoipPushNotificationManager only supports `notification`, `register` and `localNotification` events'
        );
        var listener;
        if (type === 'notification') {
            listener = DeviceEventEmitter.addListener(
                DEVICE_NOTIF_EVENT,
                (notifData) => {
                    handler(new RNVoipPushNotification(notifData));
                }
            );
        } else if (type === 'localNotification') {
            listener = DeviceEventEmitter.addListener(
                DEVICE_LOCAL_NOTIF_EVENT,
                (notifData) => {
                    handler(new RNVoipPushNotification(notifData));
                }
            );
        } else if (type === 'register') {
            listener = DeviceEventEmitter.addListener(
                NOTIF_REGISTER_EVENT,
                (registrationInfo) => {
                    handler(registrationInfo.deviceToken);
                }
            );
        }
        _notifHandlers.set(handler, listener);
    }

    /**
     * Removes the event listener. Do this in `componentWillUnmount` to prevent
     * memory leaks
     */
    static removeEventListener(type, handler) {
        invariant(
            type === 'notification' || type === 'register' || type === 'localNotification',
            'RNVoipPushNotification only supports `notification`, `register` and `localNotification` events'
        );
        var listener = _notifHandlers.get(handler);
        if (!listener) {
            return;
        }
        listener.remove();
        _notifHandlers.delete(handler);
    }

    /**
     * Requests notification permissions from iOS, prompting the user's
     * dialog box. By default, it will request all notification permissions, but
     * a subset of these can be requested by passing a map of requested
     * permissions.
     * The following permissions are supported:
     *
     *   - `alert`
     *   - `badge`
     *   - `sound`
     *
     * If a map is provided to the method, only the permissions with truthy values
     * will be requested.
     */
    static requestPermissions(permissions) {
        var requestedPermissions = {};
        if (permissions) {
            requestedPermissions = {
                alert: !!permissions.alert,
                badge: !!permissions.badge,
                sound: !!permissions.sound
            };
        } else {
            requestedPermissions = {
                alert: true,
                badge: true,
                sound: true
            };
        }
        RNVoipPushNotificationManager.requestPermissions(requestedPermissions);
    }

    /**
     * Register for voip token
     *
     * @static
     * @memberof RNVoipPushNotification
     */
    static registerVoipToken() {
        RNVoipPushNotificationManager.registerVoipToken();
    }

    /**
     * When you have processed necessary initialization for voip push, tell ios completed.
     * This is mainly for ios 11+, which apple required us to execute `complete()` when we finished.
     * If you want to use this function, make sure you call `[RNVoipPushNotificationManager addCompletionHandler:uuid completionHandler:completion];`
     *   in `didReceiveIncomingPushWithPayload` in your AppDelegate.m
     *
     * @static
     * @memberof RNVoipPushNotification
     * 
     * uuid:
     */
    static onVoipNotificationCompleted(uuid) {
        RNVoipPushNotificationManager.onVoipNotificationCompleted(uuid);
    }

    /**
     * You will never need to instantiate `RNVoipPushNotification` yourself.
     * Listening to the `notification` event and invoking
     * `popInitialNotification` is sufficient
     */
    constructor(nativeNotif) {
        this._data = {};
  
        // Extract data from Apple's `aps` dict as defined:
  
        // https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html
  
        Object.keys(nativeNotif).forEach((notifKey) => {
            var notifVal = nativeNotif[notifKey];
            if (notifKey === 'aps') {
                this._alert = notifVal.alert;
                this._sound = notifVal.sound;
                this._badgeCount = notifVal.badge;
            } else {
                this._data[notifKey] = notifVal;
            }
        });
    }

    /**
     * An alias for `getAlert` to get the notification's main message string
     */
    getMessage() {
        // alias because "alert" is an ambiguous name
        return this._alert;
    }
  
    /**
     * Gets the sound string from the `aps` object
     */
    getSound() {
        return this._sound;
    }
  
    /**
     * Gets the notification's main message from the `aps` object
     */
    getAlert() {
        return this._alert;
    }
  
    /**
     * Gets the badge count number from the `aps` object
     */
    getBadgeCount() {
        return this._badgeCount;
    }
  
    /**
     * Gets the data object on the notif
     */
    getData() {
        return this._data;
    }
}
