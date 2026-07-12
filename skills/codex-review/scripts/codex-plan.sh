#!/usr/bin/env bash
# Harness: run an external OpenAI Codex agent to review a commit range (default: the
# last commit) against the workspace's own documented standards (CLAUDE.md and any file
# it designates as binding).
# Codex exec is one-shot (no resumable sessions), so the verdict + plan are captured to a
# temp file via --output-last-message; the execute phase picks that file up.
# The range is driven entirely through the prompt (the agent runs `git diff RANGE`
# itself), matching composer-review so both skills behave identically.
# Output always contains:
#   REVIEW_FILE: <path>     (first line, emitted by this script)
#   PLAN_NEEDED: yes|no     (from the agent, first line of the captured review)
# Usage: codex-plan.sh [workspace-path] [model-spec] [rev-range]
# model-spec is MODEL_ID or MODEL_ID:EFFORT (e.g. gpt-5.6-sol:high)

set -euo pipefail

WORKSPACE="${1:-$(pwd)}"
MODEL_SPEC="${2:-gpt-5.6-sol:medium}"
RANGE="${3:-HEAD~1..HEAD}"

# Root-commit safety: the default range references HEAD~1, which does not exist when
# HEAD is the repo's first commit. In that case, diff against the empty tree so the
# initial commit can still be reviewed.
if [[ "$RANGE" == "HEAD~1..HEAD" ]] && ! git -C "$WORKSPACE" rev-parse -q --verify HEAD~1 >/dev/null 2>&1; then
  RANGE="$(git -C "$WORKSPACE" hash-object -t tree /dev/null)..HEAD"
fi

# Parse model spec: split on : into model ID and optional reasoning effort
if [[ "$MODEL_SPEC" == *:* ]]; then
  MODEL_ID="${MODEL_SPEC%%:*}"
  REASONING_EFFORT="${MODEL_SPEC##*:}"
  EFFORT_ARGS=(-c "model_reasoning_effort=$REASONING_EFFORT")
else
  MODEL_ID="$MODEL_SPEC"
  EFFORT_ARGS=()
fi

REVIEW_FILE=$(mktemp /tmp/codex-review-XXXXXX.md)
echo "REVIEW_FILE: $REVIEW_FILE"

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

# Plan phase is review-only: -s read-only sandboxes out any file writes while still
# allowing reads and `git diff`/`git log`. The verdict + plan land in REVIEW_FILE via
# --output-last-message; we also echo it so the captured background output carries it.
codex exec \
  -C "$WORKSPACE" \
  -s read-only \
  -m "$MODEL_ID" \
  "${EFFORT_ARGS[@]}" \
  --ephemeral \
  -o "$REVIEW_FILE" \
  "$PROMPT"

cat "$REVIEW_FILE"
