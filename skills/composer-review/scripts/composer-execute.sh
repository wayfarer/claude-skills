#!/usr/bin/env bash
# Harness: execute the remediation plan in an existing agent session.
# Usage: composer-execute.sh <chat-id> [workspace-path] [model-id]

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "ERROR: CHAT_ID required. Usage: composer-execute.sh <chat-id> [workspace-path] [model-id]" >&2
  exit 1
fi

CHAT_ID="$1"
WORKSPACE="${2:-$(pwd)}"
MODEL="${3:-composer-2.5}"

agent --print --yolo --trust --resume "$CHAT_ID" --model "$MODEL" --workspace "$WORKSPACE" \
  "Execute the remediation plan exactly as described above. Work through each numbered item in order, making all file edits. When every fix is applied, commit the changes with a concise commit message."
