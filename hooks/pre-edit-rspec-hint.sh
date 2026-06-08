#!/bin/bash
# Pre-Edit Hook: signale (sans bloquer) l'édition d'un spec sans fichier
# d'implémentation correspondant. Spécifique Rails/RSpec.
# Couvre les outils Edit et Write (cf. matcher "Edit|Write" dans hooks.json).

# Extraction robuste du chemin : Claude Code transmet le payload du hook en
# JSON sur stdin. Edit et Write exposent tous deux .tool_input.file_path.
# Repli sur $TOOL_INPUT pour préserver l'ancien comportement si stdin est vide.
HOOK_INPUT="$(cat 2>/dev/null)"
FILE_PATH="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$FILE_PATH" ]] && FILE_PATH="$TOOL_INPUT"

if [[ "$FILE_PATH" == *"_spec.rb" ]]; then
  IMPL_FILE="${FILE_PATH/_spec.rb/.rb}"
  IMPL_FILE="${IMPL_FILE/spec\//app/}"
  if [[ ! -f "$IMPL_FILE" ]]; then
    echo "ℹ️ Note: Editing spec without implementation file" >&2
  fi
fi

exit 0
