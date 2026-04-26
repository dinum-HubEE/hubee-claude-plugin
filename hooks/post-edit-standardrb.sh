#!/bin/bash
# Post-Edit Hook: Runs after file edits
# Auto-format Ruby files with StandardRB

FILE_PATH="$TOOL_INPUT"

# Only process Ruby files
if [[ "$FILE_PATH" == *.rb ]]; then
  # Check if StandardRB is available
  if command -v bundle &> /dev/null && bundle show standard &> /dev/null; then
    # Auto-format the file silently
    bundle exec standardrb --fix "$FILE_PATH" 2>/dev/null || true
  fi
fi

exit 0
