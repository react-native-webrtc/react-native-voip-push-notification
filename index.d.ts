declare module 'react-native-voip-push-notification' {
    export type NativeEvents = {
        register: 'RNVoipPushRemoteNotificationsRegisteredEvent';
        notification: 'RNVoipPushRemoteNotificationReceivedEvent';
        didLoadWithEvents: 'RNVoipPushDidLoadWithEvents';
    }

    export type Events = keyof NativeEvents;
    export type EventsPayload = {
        register: string,
        notification: object,
        didLoadWithEvents: Array<InitialEvent>,
    }

    export type InitialEvent = {
        [Event in Events]: { name: NativeEvents[Event], data: EventsPayload[Event] }
    }[Events];

    export default class RNVoipPushNotification {
        static RNVoipPushRemoteNotificationsRegisteredEvent: NativeEvents['register']
        static RNVoipPushRemoteNotificationReceivedEvent: NativeEvents['notification']
        static RNVoipPushDidLoadWithEvents: NativeEvents['didLoadWithEvents']

        static addEventListener<Event extends Events>(
            type: Event,
            handler: (args: EventsPayload[Event]) => void,
        ): void
        static removeEventListener(type: Events): void

        static registerVoipToken(): void;
        static onVoipNotificationCompleted(uuid: string): void;
    }
}