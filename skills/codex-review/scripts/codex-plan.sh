#!/usr/bin/env bash
# Harness: run Codex in review mode against the last git commit to check compliance
# with the workspace's documented standards (CLAUDE.md and any file it designates).
# Captures the review to a temp file and prints its path so the execute phase can
# pick it up without a shared session (Codex exec is one-shot, not resumable).
# Output always contains:
#   REVIEW_FILE: <path>     (first line, emitted by this script)
#   PLAN_NEEDED: yes|no     (from the agent, in the captured review)
# Usage: codex-plan.sh [workspace-path] [model-id]

set -euo pipefail

WORKSPACE="${1:-$(pwd)}"
MODEL="${2:-o3}"

COMMIT_SHA=$(git -C "$WORKSPACE" rev-parse HEAD)
COMMIT_TITLE=$(git -C "$WORKSPACE" log -1 --format="%s")
REVIEW_FILE=$(mktemp /tmp/codex-review-XXXXXX.md)

echo "REVIEW_FILE: $REVIEW_FILE"

read -r -d '' PROMPT <<'EOF' || true
You are reviewing the last git commit in this workspace for compliance with the
project's own documented standards.

Step 1: Read ./CLAUDE.md in full. If it names another file as binding or canonical
(for example GUIDE.md), read that file too. These documents define the rules; treat
every rule, constraint, naming convention, and required pattern they describe as a
checklist item. If no CLAUDE.md exists, fall back to a general code-quality review.

Step 2: Cross-check every file changed in this commit against every applicable rule
from Step 1. Be specific: cite the rule and the file location for each finding.

If any issues need fixing, output EXACTLY this line first (no other text before it):
PLAN_NEEDED: yes
Then describe each issue and the concrete fix, numbered.

If no issues are found, output EXACTLY this line first (no other text before it):
PLAN_NEEDED: no
Then tell a programming joke.
EOF

codex exec review \
  -C "$WORKSPACE" \
  --commit "$COMMIT_SHA" \
  --title "$COMMIT_TITLE" \
  -m "$MODEL" \
  --ephemeral \
  -o "$REVIEW_FILE" \
  "$PROMPT"

cat "$REVIEW_FILE"
