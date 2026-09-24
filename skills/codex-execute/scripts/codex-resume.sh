#!/usr/bin/env bash
# Harness: send reviewer feedback back into the Codex session that codex-run.sh
# started, so the agent fixes its own work with full context of the original plan.
# The feedback file is embedded in the prompt and fed over stdin (`-`).
# Output always contains, in order:
#   REPORT_FILE: <path>
#   PROMPT_FILE: <path>
#   ...codex transcript...
#   SESSION_ID: <uuid|unknown>   (as reported by the resumed transcript, for a mismatch check)
#   CODEX_EXIT: <code>
#   --- REPORT ---             followed by the report; first line STATUS: done|partial|blocked
# The script exits with codex's own exit code.
# Usage: codex-resume.sh <session-id> <feedback-file> [workspace-path] [model-spec]
# `codex exec resume` has no -C or -s flags: the workspace is selected by cd (resume
# filters sessions by cwd) and the sandbox by -c sandbox_mode.
# The body lives in main() so bash parses the whole file before running any of it;
# see codex-run.sh for why.
# Execution runs at least at high reasoning effort, like codex-run.sh.

set -euo pipefail

main() {
  if [[ -z "${1:-}" || -z "${2:-}" ]]; then
    echo "ERROR: session id and feedback file required. Usage: codex-resume.sh <session-id> <feedback-file> [workspace-path] [model-spec]" >&2
    exit 1
  fi

  SESSION_ID="$1"
  FEEDBACK_FILE="$2"
  WORKSPACE="${3:-$(pwd)}"
  MODEL_SPEC="${4:-gpt-6-astra:high}"

  if ! [[ "$SESSION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    echo "ERROR: '$SESSION_ID' is not a session UUID (see the SESSION_ID: line from codex-run.sh)." >&2
    exit 1
  fi
  if [[ ! -s "$FEEDBACK_FILE" ]]; then
    echo "ERROR: feedback file missing or empty: $FEEDBACK_FILE" >&2
    exit 1
  fi

  if [[ "$MODEL_SPEC" == *:* ]]; then
    MODEL_ID="${MODEL_SPEC%%:*}"
    REASONING_EFFORT="${MODEL_SPEC##*:}"
    case "$REASONING_EFFORT" in
      low|medium) REASONING_EFFORT="high" ;;
    esac
  else
    MODEL_ID="$MODEL_SPEC"
    REASONING_EFFORT="high"
  fi
  EFFORT_ARGS=(-c "model_reasoning_effort=$REASONING_EFFORT")

  # BSD mktemp only substitutes trailing Xs; add the suffix afterwards.
  REPORT_FILE=$(mktemp /tmp/codex-execute-report-XXXXXX)
  mv "$REPORT_FILE" "$REPORT_FILE.md"; REPORT_FILE="$REPORT_FILE.md"
  PROMPT_FILE=$(mktemp /tmp/codex-execute-prompt-XXXXXX)
  mv "$PROMPT_FILE" "$PROMPT_FILE.md"; PROMPT_FILE="$PROMPT_FILE.md"
  TRANSCRIPT_FILE=$(mktemp /tmp/codex-execute-transcript-XXXXXX)
  mv "$TRANSCRIPT_FILE" "$TRANSCRIPT_FILE.log"; TRANSCRIPT_FILE="$TRANSCRIPT_FILE.log"
  echo "REPORT_FILE: $REPORT_FILE"
  echo "PROMPT_FILE: $PROMPT_FILE"

  # read -r -d '' rather than $(cat <<EOF): macOS bash 3.2 mis-parses the latter.
  read -r -d '' HEADER <<'EOF' || true
You executed the implementation plan earlier in this session. The reviewer inspected
the working tree and returned the feedback below. Address every item, re-run the
affected commands from the plan's Verification section, and reply with the same report
format: first line exactly STATUS: done, STATUS: partial, or STATUS: blocked, then the
sections ## Changes, ## Deviations, ## Verification, ## Open questions.

The same rules apply as before: stay within the plan's scope, do not commit or
otherwise write to .git unless your original instructions told you to, and record any
judgement call under Deviations.
EOF

  {
    printf '%s\n\n<feedback>\n' "$HEADER"
    cat "$FEEDBACK_FILE"
    printf '\n</feedback>\n\nBegin now. Your final message starts with STATUS:.\n'
  } > "$PROMPT_FILE"

  cd "$WORKSPACE"
  set +e
  codex exec resume "$SESSION_ID" \
    -m "$MODEL_ID" \
    "${EFFORT_ARGS[@]}" \
    -c 'sandbox_mode="workspace-write"' \
    -o "$REPORT_FILE" \
    - < "$PROMPT_FILE" 2>&1 | tee "$TRANSCRIPT_FILE"
  CODEX_RC=${PIPESTATUS[0]}
  set -e

  RESUMED_ID=$(grep -m1 '^session id: ' "$TRANSCRIPT_FILE" | awk '{print $3}' || true)
  echo "SESSION_ID: ${RESUMED_ID:-unknown}"
  echo "CODEX_EXIT: $CODEX_RC"
  echo "--- REPORT ---"
  if [[ -s "$REPORT_FILE" ]]; then cat "$REPORT_FILE"; else echo "(empty report)"; fi
  exit "$CODEX_RC"
}

main "$@"
