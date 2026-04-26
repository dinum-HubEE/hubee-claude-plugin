#!/bin/bash
# Pre-Edit Hook: bloque l'édition des fichiers contenant des secrets.
# Exit code 2 blocks the operation.

FILE_PATH="$TOOL_INPUT"

# Substring matches (filename or path fragment)
PROTECTED_PATTERNS=(
  ".env"
  ".env.local"
  ".env.production"
  ".env.development"
  ".env.staging"
  ".env.test"
  "config/master.key"
  "config/credentials.yml.enc"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "❌ BLOCKED: Cannot edit protected file: $pattern" >&2
    exit 2
  fi
done

# Rails 6+ per-environment credentials : config/credentials/*.{key,yml.enc}
if [[ "$FILE_PATH" == *"config/credentials/"*".key" ]] \
  || [[ "$FILE_PATH" == *"config/credentials/"*".yml.enc" ]]; then
  echo "❌ BLOCKED: Cannot edit protected per-env Rails credentials" >&2
  exit 2
fi

exit 0
