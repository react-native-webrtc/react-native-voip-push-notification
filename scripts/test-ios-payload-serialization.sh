#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rnvoip-payload-tests.XXXXXX")"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

xcrun --sdk macosx clang \
  -fobjc-arc \
  -fmodules \
  -Wall \
  -Wextra \
  -Werror \
  -framework Foundation \
  -I "$REPO_ROOT/ios/RNVoipPushNotification" \
  "$REPO_ROOT/ios/RNVoipPushNotification/RNVoipPushPayloadSerialization.m" \
  "$REPO_ROOT/ios/RNVoipPushNotificationTests/RNVoipPushPayloadSerializationTests.m" \
  -o "$TEST_TMP_DIR/RNVoipPushPayloadSerializationTests"

"$TEST_TMP_DIR/RNVoipPushPayloadSerializationTests"
