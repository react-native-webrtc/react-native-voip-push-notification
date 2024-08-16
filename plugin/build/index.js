"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_plugins_1 = require("@expo/config-plugins");
const ios_1 = require("./ios");
const pak = require("react-native-voip-push-notification/package.json");
exports.default = (0, config_plugins_1.createRunOncePlugin)(ios_1.withIosAppDelegate, pak.name, pak.version);
