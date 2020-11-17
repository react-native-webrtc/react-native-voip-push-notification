'use strict';

import {
    NativeModules,
    NativeEventEmitter,
    Platform,
} from 'react-native';

const RNVoipPushNotificationManager = NativeModules.RNVoipPushNotificationManager;

const eventEmitter = new NativeEventEmitter(RNVoipPushNotificationManager);
const _eventHandlers = new Map();

// --- native unique event names
const RNVoipPushRemoteNotificationsRegisteredEvent = "RNVoipPushRemoteNotificationsRegisteredEvent"; // --- 'register'
const RNVoipPushRemoteNotificationReceivedEvent = "RNVoipPushRemoteNotificationReceivedEvent"; // --- 'notification'
const RNVoipPushDidLoadWithEvents = "RNVoipPushDidLoadWithEvents"; // --- 'didLoadWithEvents'

export default class RNVoipPushNotification {

    static get RNVoipPushRemoteNotificationsRegisteredEvent() {
        return RNVoipPushRemoteNotificationsRegisteredEvent;
    }

    static get RNVoipPushRemoteNotificationReceivedEvent() {
        return RNVoipPushRemoteNotificationReceivedEvent;
    }

    static get RNVoipPushDidLoadWithEvents() {
        return RNVoipPushDidLoadWithEvents;
    }

    /**
     * Attaches a listener to remote notification events while the app is running
     * in the foreground or the background.
     *
     * Valid events are:
     *
     * - `notification` : Fired when a remote notification is received.
     * - `register`: Fired when the user registers for remote notifications.
     * - `didLoadWithEvents`: Fired when the user have initially subscribed any listener and has cached events already.
     */
    static addEventListener(type, handler) {
        let listener;
        if (type === 'notification') {
            listener = eventEmitter.addListener(
                RNVoipPushRemoteNotificationReceivedEvent,
                (notificationPayload) => {
                    handler(notificationPayload);
                }
            );
        } else if (type === 'register') {
            listener = eventEmitter.addListener(
                RNVoipPushRemoteNotificationsRegisteredEvent,
                (deviceToken) => {
                    handler(deviceToken);
                }
            );
        } else if (type === 'didLoadWithEvents') {
            listener = eventEmitter.addListener(
                RNVoipPushDidLoadWithEvents,
                (events) => {
                    handler(events);
                }
            );
        } else {
            return;
        }

        // --- we only support one listener at a time, remove to prevent leak
        RNVoipPushNotification.removeEventListener(type);
        _eventHandlers.set(type, listener);
    }

    /**
     * Removes the event listener. Do this in `componentWillUnmount` to prevent
     * memory leaks
     */
    static removeEventListener(type) {
        let listener = _eventHandlers.get(type);
        if (!listener) {
            return;
        }
        listener.remove();
        _eventHandlers.delete(type);
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

}
