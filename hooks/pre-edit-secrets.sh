#!/bin/bash
# Pre-Edit Hook: bloque l'édition des fichiers contenant des secrets.
# Exit code 2 blocks the operation.

FILE_PATH="$TOOL_INPUT"

PROTECTED_FILES=(
  ".env"
  ".env.local"
  ".env.production"
  "config/master.key"
  "config/credentials.yml.enc"
)

for protected in "${PROTECTED_FILES[@]}"; do
  if [[ "$FILE_PATH" == *"$protected"* ]]; then
    echo "❌ BLOCKED: Cannot edit protected file: $protected" >&2
    exit 2
  fi
done

exit 0
