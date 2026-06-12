#!/usr/bin/env bash
# Harness: run an external Cursor agent in plan mode to review the last git commit
# against the workspace's own documented standards (CLAUDE.md and any file it
# designates as binding).
# Creates a dedicated chat session and pins all work to it.
# Output always contains:
#   CHAT_ID: <uuid>       (first line, emitted by this script)
#   PLAN_NEEDED: yes|no   (from the agent, first line of its response)
# Usage: composer-plan.sh [workspace-path] [model-id]

set -euo pipefail

WORKSPACE="${1:-$(pwd)}"
MODEL="${2:-composer-2.5}"

CHAT_ID=$(agent create-chat)
echo "CHAT_ID: $CHAT_ID"

# Note: read -r -d '' (not $(cat <<EOF)) because macOS bash 3.2 mis-parses a
# heredoc nested inside command substitution. read returns non-zero at EOF, so
# `|| true` keeps it happy under `set -e`.
read -r -d '' PROMPT <<'EOF' || true
You are reviewing the last git commit in this workspace for compliance with the
project's own documented standards.

Step 1: Read ./CLAUDE.md in full. If it names another file as binding or canonical
(for example GUIDE.md), read that file too. These documents define the rules; treat
every rule, constraint, naming convention, and required pattern they describe as a
checklist item. If no CLAUDE.md exists, fall back to a general code-quality review.

Step 2: Run `git log -1 --stat` to see what the last commit changed, then read every
changed file in full.

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

agent --print --yolo --trust --resume "$CHAT_ID" --model "$MODEL" --workspace "$WORKSPACE" "$PROMPT"
