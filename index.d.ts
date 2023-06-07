declare module 'react-native-voip-push-notification' {
    export type Events =
    'notification' |
    'register'|
    'didLoadWithEvents';

    export default class RNVoipPushNotification {
        static RNVoipPushRemoteNotificationsRegisteredEvent: string;
        static RNVoipPushRemoteNotificationReceivedEvent: string;
        static RNVoipPushDidLoadWithEvents: string;

        static addEventListener(type: Events, handler: (args: any) => void): void;
        static registerVoipToken(): void;
        static onVoipNotificationCompleted(uuid: string): void;
        static removeEventListener(type: Events): void;
    }
}