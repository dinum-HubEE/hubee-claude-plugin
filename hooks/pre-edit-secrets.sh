#!/bin/bash
# Pre-Edit Hook: bloque l'édition des fichiers contenant des secrets.
# Couvre les outils Edit et Write (cf. matcher "Edit|Write" dans hooks.json).
# Exit code 2 blocks the operation.

# Extraction robuste du chemin : Claude Code transmet le payload du hook en
# JSON sur stdin. Edit et Write exposent tous deux .tool_input.file_path
# (seules les autres clés diffèrent : old_string/new_string vs content).
# Repli sur $TOOL_INPUT pour préserver l'ancien comportement si stdin est vide.
HOOK_INPUT="$(cat 2>/dev/null)"
FILE_PATH="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$FILE_PATH" ]] && FILE_PATH="$TOOL_INPUT"

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
