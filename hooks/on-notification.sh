#!/bin/bash
# On-Notification Hook: Runs when Claude Code has a notification
# Play notification sound on macOS

if [[ "$OSTYPE" == "darwin"* ]]; then
  afplay /System/Library/Sounds/Blow.aiff 2>/dev/null || true
elif command -v paplay &> /dev/null; then
  # Linux with PulseAudio
  paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null || true
fi

exit 0
