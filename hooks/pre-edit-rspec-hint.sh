#!/bin/bash
# Pre-Edit Hook: signale (sans bloquer) l'édition d'un spec sans fichier
# d'implémentation correspondant. Spécifique Rails/RSpec.

FILE_PATH="$TOOL_INPUT"

if [[ "$FILE_PATH" == *"_spec.rb" ]]; then
  IMPL_FILE="${FILE_PATH/_spec.rb/.rb}"
  IMPL_FILE="${IMPL_FILE/spec\//app/}"
  if [[ ! -f "$IMPL_FILE" ]]; then
    echo "ℹ️ Note: Editing spec without implementation file" >&2
  fi
fi

exit 0
