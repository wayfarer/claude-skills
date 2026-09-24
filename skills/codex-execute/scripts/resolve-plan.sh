#!/usr/bin/env bash
# Locate the plan file to hand to Codex and describe it.
# With a path: validate it. With no path: pick the newest ~/.claude/plans/*.md and
# flag it as guessed so the caller confirms before launching a 5-20 minute run.
# Output:
#   PLAN_FILE: <abs path>
#   PLAN_TITLE: <first "# " heading, or the basename>
#   PLAN_GUESSED: yes|no
#   PLAN_WARN: <note>          (only when the plan lacks a section the reviewer relies on)
# Usage: resolve-plan.sh [plan-path]
# Exits 1 with an error if no usable plan is found.

set -euo pipefail

PLAN_ARG="${1:-}"
GUESSED="no"

if [[ -z "$PLAN_ARG" ]]; then
  PLANS_DIR="$HOME/.claude/plans"
  # ls -t is bash 3.2 / BSD safe; the glob is quoted-off so it expands here.
  PLAN_ARG=$(ls -t "$PLANS_DIR"/*.md 2>/dev/null | head -1 || true)
  if [[ -z "$PLAN_ARG" ]]; then
    echo "ERROR: no --plan given and no plans found under $PLANS_DIR." >&2
    exit 1
  fi
  GUESSED="yes"
fi

if [[ ! -f "$PLAN_ARG" ]]; then
  echo "ERROR: plan file not found: $PLAN_ARG" >&2
  exit 1
fi
if [[ ! -s "$PLAN_ARG" ]]; then
  echo "ERROR: plan file is empty: $PLAN_ARG" >&2
  exit 1
fi
if [[ "$PLAN_ARG" != *.md ]]; then
  echo "ERROR: plan file must be markdown (.md): $PLAN_ARG" >&2
  exit 1
fi

# Absolute path without relying on realpath (absent on stock macOS).
PLAN_FILE="$(cd "$(dirname "$PLAN_ARG")" && pwd)/$(basename "$PLAN_ARG")"

TITLE=$(grep -m1 '^# ' "$PLAN_FILE" | sed 's/^# *//' || true)
[[ -z "$TITLE" ]] && TITLE=$(basename "$PLAN_FILE")

echo "PLAN_FILE: $PLAN_FILE"
echo "PLAN_TITLE: $TITLE"
echo "PLAN_GUESSED: $GUESSED"

grep -qiE '^##+ *(changes|implementation)' "$PLAN_FILE" \
  || echo 'PLAN_WARN: no "## Changes" section; Codex will infer the work from the whole plan'
grep -qiE '^##+ *verification' "$PLAN_FILE" \
  || echo 'PLAN_WARN: no "## Verification" section; review will be by inspection only'
