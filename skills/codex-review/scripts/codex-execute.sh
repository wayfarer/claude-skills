#!/usr/bin/env bash
# Harness: apply the remediation plan produced by codex-plan.sh.
# The review file's contents are embedded in the prompt so the agent has full context.
# Usage: codex-execute.sh <review-file> [workspace-path] [model-spec]
# model-spec is MODEL_ID or MODEL_ID:EFFORT (e.g. gpt-5.6-sol:high)

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "ERROR: REVIEW_FILE required. Usage: codex-execute.sh <review-file> [workspace-path] [model-spec]" >&2
  exit 1
fi

REVIEW_FILE="$1"
WORKSPACE="${2:-$(pwd)}"
MODEL_SPEC="${3:-gpt-5.6-sol:medium}"

# Parse model spec: split on : into model ID and optional reasoning effort
if [[ "$MODEL_SPEC" == *:* ]]; then
  MODEL_ID="${MODEL_SPEC%%:*}"
  REASONING_EFFORT="${MODEL_SPEC##*:}"
  EFFORT_ARGS=(-c "model_reasoning_effort=$REASONING_EFFORT")
else
  MODEL_ID="$MODEL_SPEC"
  EFFORT_ARGS=()
fi

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo "ERROR: review file not found: $REVIEW_FILE" >&2
  exit 1
fi

codex exec \
  -C "$WORKSPACE" \
  -s workspace-write \
  -m "$MODEL_ID" \
  "${EFFORT_ARGS[@]}" \
  --ephemeral \
  "The following code review identified issues that need fixing. Execute the remediation plan exactly as described — work through each numbered item in order, making all file edits. When every fix is applied, commit the changes with a concise commit message.

$(cat "$REVIEW_FILE")"
