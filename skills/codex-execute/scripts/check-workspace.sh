#!/usr/bin/env bash
# Fail-fast preflight before handing a workspace to Codex for a 5-20 minute run.
# Requires: a git repo with at least one commit, `codex` on PATH, and no modified or
# staged TRACKED files (Codex's diff must be reviewable in isolation). Untracked files
# are allowed but listed, so the reviewer can tell Codex-created files from ones that
# were already there.
# Output:
#   BASE_SHA: <sha>
#   BRANCH: <name|DETACHED>
#   CODEX_VERSION: <codex --version>
#   PRE_UNTRACKED: <path>      (zero or more lines)
# Usage: check-workspace.sh [workspace-path]

set -euo pipefail

WORKSPACE="${1:-$(pwd)}"

if ! git -C "$WORKSPACE" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  echo "ERROR: '$WORKSPACE' is not a git repository with commits." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: 'codex' CLI not found on PATH. Install it and run 'codex login'." >&2
  exit 1
fi

DIRTY=$(git -C "$WORKSPACE" status --porcelain --untracked-files=no)
if [[ -n "$DIRTY" ]]; then
  echo "ERROR: tracked files are modified or staged; commit or stash them first so Codex's diff is reviewable on its own:" >&2
  echo "$DIRTY" >&2
  exit 1
fi

echo "BASE_SHA: $(git -C "$WORKSPACE" rev-parse HEAD)"
BRANCH=$(git -C "$WORKSPACE" symbolic-ref -q --short HEAD || echo DETACHED)
echo "BRANCH: $BRANCH"
echo "CODEX_VERSION: $(codex --version 2>/dev/null | head -1)"
git -C "$WORKSPACE" ls-files --others --exclude-standard | sed 's/^/PRE_UNTRACKED: /'
