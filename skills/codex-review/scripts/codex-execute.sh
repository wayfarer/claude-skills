#!/usr/bin/env bash
# Harness: apply the remediation plan produced by codex-plan.sh.
# The review file is piped into codex exec via stdin so the agent has full context.
# Usage: codex-execute.sh <review-file> [workspace-path] [model-id]

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "ERROR: REVIEW_FILE required. Usage: codex-execute.sh <review-file> [workspace-path] [model-id]" >&2
  exit 1
fi

REVIEW_FILE="$1"
WORKSPACE="${2:-$(pwd)}"
MODEL="${3:-o3}"

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo "ERROR: review file not found: $REVIEW_FILE" >&2
  exit 1
fi

codex exec \
  -C "$WORKSPACE" \
  -s workspace-write \
  -m "$MODEL" \
  --ephemeral \
  "The following code review identified issues that need fixing. Execute the remediation plan exactly as described — work through each numbered item in order, making all file edits. When every fix is applied, commit the changes with a concise commit message.

$(cat "$REVIEW_FILE")"
