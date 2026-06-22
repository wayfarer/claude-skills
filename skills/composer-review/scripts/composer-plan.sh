#!/usr/bin/env bash
# Harness: run an external Cursor agent to review a commit range (default: the
# last commit) against the workspace's own documented standards (CLAUDE.md and any file it
# designates as binding).
# Creates a dedicated chat session and pins all work to it.
# Output always contains:
#   CHAT_ID: <uuid>       (first line, emitted by this script)
#   PLAN_NEEDED: yes|no   (from the agent, first line of its response)
# Usage: composer-plan.sh [workspace-path] [model-id] [rev-range]

set -euo pipefail

WORKSPACE="${1:-$(pwd)}"
MODEL="${2:-composer-2.5}"
RANGE="${3:-HEAD~1..HEAD}"

# Root-commit safety: the default range references HEAD~1, which does not exist when
# HEAD is the repo's first commit. In that case, diff against the empty tree so the
# initial commit can still be reviewed (matches the old `git log -1` behavior).
if [[ "$RANGE" == "HEAD~1..HEAD" ]] && ! git -C "$WORKSPACE" rev-parse -q --verify HEAD~1 >/dev/null 2>&1; then
  RANGE="$(git -C "$WORKSPACE" hash-object -t tree /dev/null)..HEAD"
fi

# Extract a clean UUID; tolerate banners or multiline output from create-chat.
# `|| true` keeps the no-match/SIGPIPE case from aborting under `set -euo pipefail`
# before the guard below can report it.
CHAT_ID=$(agent create-chat | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)
if [[ -z "$CHAT_ID" ]]; then
  echo "ERROR: could not obtain a chat id from 'agent create-chat'" >&2
  exit 1
fi
echo "CHAT_ID: $CHAT_ID"

# Note: read -r -d '' (not $(cat <<EOF)) because macOS bash 3.2 mis-parses a
# heredoc nested inside command substitution. read returns non-zero at EOF, so
# `|| true` keeps it happy under `set -e`.
read -r -d '' PROMPT <<'EOF' || true
You are reviewing the changes in the range RANGE_PLACEHOLDER in this workspace for
compliance with the project's own documented standards.

Step 1: Read ./CLAUDE.md in full. If it names another file as binding or canonical
(for example GUIDE.md), read that file too. These documents define the rules; treat
every rule, constraint, naming convention, and required pattern they describe as a
checklist item. If no CLAUDE.md exists, fall back to a general code-quality review.

Step 2: Run `git diff --stat RANGE_PLACEHOLDER` and `git diff --name-only RANGE_PLACEHOLDER`
to see what changed in the range under review, then read every changed file in full.

Step 3: Cross-check each changed file against every applicable rule from Step 1. Be
specific: cite the rule and the file location for each finding.

If any issues need fixing, output EXACTLY this line first (no other text before it on
that line):
PLAN_NEEDED: yes
Then describe each issue and the concrete fix, numbered.

If no issues are found, output EXACTLY this line first (no other text before it on that
line):
PLAN_NEEDED: no
Then tell a programming joke.
EOF

# The heredoc is single-quoted (no expansion, for macOS bash 3.2); inject the range here.
PROMPT="${PROMPT//RANGE_PLACEHOLDER/$RANGE}"

agent --print --yolo --trust --resume "$CHAT_ID" --model "$MODEL" --workspace "$WORKSPACE" "$PROMPT"
