#!/bin/bash
# Post-Edit Hook: Runs after file edits
# Auto-format Ruby files with StandardRB
# Couvre les outils Edit et Write (cf. matcher "Edit|Write" dans hooks.json).

# Extraction robuste du chemin : Claude Code transmet le payload du hook en
# JSON sur stdin. Edit et Write exposent tous deux .tool_input.file_path.
# Repli sur $TOOL_INPUT pour préserver l'ancien comportement si stdin est vide.
HOOK_INPUT="$(cat 2>/dev/null)"
FILE_PATH="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$FILE_PATH" ]] && FILE_PATH="$TOOL_INPUT"

# Only process Ruby files
if [[ "$FILE_PATH" == *.rb ]]; then
  # Check if StandardRB is available
  if command -v bundle &> /dev/null && bundle show standard &> /dev/null; then
    # Auto-format the file silently
    bundle exec standardrb --fix "$FILE_PATH" 2>/dev/null || true
  fi
fi

exit 0
