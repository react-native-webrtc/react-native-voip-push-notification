import { createRunOncePlugin } from "@expo/config-plugins";
import { withIosAppDelegate } from "./ios";

const pak = require("react-native-voip-push-notification/package.json");

export default createRunOncePlugin(withIosAppDelegate, pak.name, pak.version);
