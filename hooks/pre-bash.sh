#!/bin/bash
# Pre-Bash Hook: Validates bash commands before execution
# Exit code 2 blocks the operation

COMMAND="$TOOL_INPUT"

# Block git commit without user validation
if echo "$COMMAND" | grep -qE '^git commit'; then
  echo "❌ BLOCKED: git commit requires explicit user validation" >&2
  echo "Ask the user to confirm the commit message first." >&2
  exit 2
fi

# Block git push without user validation
if echo "$COMMAND" | grep -qE '^git push'; then
  echo "❌ BLOCKED: git push requires explicit user validation" >&2
  echo "Ask the user to confirm before pushing." >&2
  exit 2
fi

# Block destructive git operations
if echo "$COMMAND" | grep -qE 'git (reset --hard|checkout -- \.|clean -fd|push --force)'; then
  echo "❌ BLOCKED: Destructive git operation" >&2
  exit 2
fi

# Block editing main/master branch directly
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  if echo "$COMMAND" | grep -qE '^git (commit|merge|rebase)'; then
    echo "⚠️ WARNING: You are on $CURRENT_BRANCH branch" >&2
    echo "Consider creating a feature branch first." >&2
    # Don't block, just warn
  fi
fi

# All checks passed
exit 0
