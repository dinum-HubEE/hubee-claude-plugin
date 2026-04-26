#!/bin/bash
# On-Stop Hook: Runs when Claude Code completes
# Play notification sound on macOS

if [[ "$OSTYPE" == "darwin"* ]]; then
  afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
elif command -v paplay &> /dev/null; then
  # Linux with PulseAudio
  paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true
fi

exit 0
