#!/usr/bin/env bash
# Harness: hand an implementation plan to an external OpenAI Codex agent and let it
# execute the plan in the workspace. Claude reviews the resulting diff afterwards.
# The plan is embedded in the prompt and fed to codex over stdin (`-`), so plan size is
# not bound by argv limits and stdin is never left as the Bash tool's dangling pipe.
# The session is persisted (no --ephemeral) so codex-resume.sh can send feedback into it.
# Output always contains, in order:
#   REPORT_FILE: <path>      (agent's final message, via --output-last-message)
#   PROMPT_FILE: <path>      (the exact prompt sent, for auditing)
#   ...codex transcript...
#   SESSION_ID: <uuid|unknown>
#   CODEX_EXIT: <code>
#   --- REPORT ---           followed by the report; its first line is STATUS: done|partial|blocked
# The script exits with codex's own exit code.
# Usage: codex-run.sh <plan-file> [workspace-path] [model-spec] [--commit]
# model-spec is MODEL_ID or MODEL_ID:EFFORT (e.g. gpt-6-astra:high)
# The body lives in main() so bash parses the whole file before running any of
# it: the agent has workspace-write access and may edit this very script when the
# workspace is this skills repo, and bash otherwise resumes reading the modified
# file at a stale byte offset after codex exec returns.
# Execution runs at least at high reasoning effort: a low/medium spec is raised to
# high here, while xhigh/max/ultra are kept as requested.

set -euo pipefail

main() {
  if [[ -z "${1:-}" ]]; then
    echo "ERROR: plan file required. Usage: codex-run.sh <plan-file> [workspace-path] [model-spec] [--commit]" >&2
    exit 1
  fi

  PLAN_FILE="$1"; shift
  WORKSPACE="$(pwd)"
  MODEL_SPEC="gpt-6-astra:high"
  COMMIT_MODE="no"
  local positional=0
  for arg in "$@"; do
    case "$arg" in
      --commit) COMMIT_MODE="yes" ;;
      *)
        positional=$((positional + 1))
        case $positional in
          1) WORKSPACE="$arg" ;;
          2) MODEL_SPEC="$arg" ;;
          *) echo "ERROR: unexpected argument '$arg'" >&2; exit 1 ;;
        esac ;;
    esac
  done

  if [[ ! -s "$PLAN_FILE" ]]; then
    echo "ERROR: plan file missing or empty: $PLAN_FILE" >&2
    exit 1
  fi

  # Parse model spec: split on : into model ID and optional reasoning effort.
  # Bare IDs get the high floor too, so the documented "at least high" rule holds.
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

  # With --commit, ask the sandbox to make .git writable so the agent can commit.
  # workspace-write otherwise refuses .git writes (observed: "sandbox prohibits writing
  # .git/index.lock"), which is exactly what the default mode relies on.
  COMMIT_ARGS=()
  if [[ "$COMMIT_MODE" == "yes" ]]; then
    COMMIT_ARGS=(--add-dir "$WORKSPACE/.git")
  fi

  # BSD mktemp (macOS) only substitutes Xs at the END of a template, so a
  # trailing suffix makes it treat the whole path as a literal name. Create the
  # file with the Xs last, then add the suffix. GNU mktemp is happy with this too.
  REPORT_FILE=$(mktemp /tmp/codex-execute-report-XXXXXX)
  mv "$REPORT_FILE" "$REPORT_FILE.md"; REPORT_FILE="$REPORT_FILE.md"
  PROMPT_FILE=$(mktemp /tmp/codex-execute-prompt-XXXXXX)
  mv "$PROMPT_FILE" "$PROMPT_FILE.md"; PROMPT_FILE="$PROMPT_FILE.md"
  TRANSCRIPT_FILE=$(mktemp /tmp/codex-execute-transcript-XXXXXX)
  mv "$TRANSCRIPT_FILE" "$TRANSCRIPT_FILE.log"; TRANSCRIPT_FILE="$TRANSCRIPT_FILE.log"
  echo "REPORT_FILE: $REPORT_FILE"
  echo "PROMPT_FILE: $PROMPT_FILE"

  # Note: read -r -d '' (not $(cat <<EOF)) because macOS bash 3.2 mis-parses a
  # heredoc nested inside command substitution. read returns non-zero at EOF, so
  # `|| true` keeps it happy under `set -e`. Single-quoted delimiter: no expansion;
  # placeholders are substituted below.
  read -r -d '' HEADER <<'EOF' || true
You are executing an implementation plan in this workspace (WORKSPACE_PLACEHOLDER).
The plan was written by another engineer and reviewed; carry it out faithfully, do not
redesign it. A reviewer will inspect your changes afterwards and decide whether to
commit them. Nobody can answer questions during the run.

Before editing, read ./CLAUDE.md in full, plus any file it designates as binding. Where
the plan is silent, follow those conventions.

Rules:
1. Execute the plan's Changes section exactly, in order. Add no features, refactors,
   comments, or files the plan does not call for.
2. Only touch files the plan names or clearly implies. If you must edit anything else,
   do the minimum and record it under Deviations.
3. If the plan is ambiguous or wrong about the code, take the most conservative
   reading, proceed, and record the choice under Deviations. If a step cannot be done,
   leave the tree coherent and report STATUS: partial or STATUS: blocked.
4. COMMIT_RULE_PLACEHOLDER
5. Do not delete or rewrite files you did not create in this run unless the plan says
   so. Do not touch ~/.claude, ~/.codex, or anything outside this workspace.
6. Run every command in the plan's Verification section. If one fails, fix the cause
   once if the fix is in scope; otherwise report it. If a command cannot run in the
   sandbox (network, permissions), record "not run: <reason>" rather than bypassing.

Your FINAL message is the report. It must start with EXACTLY one of:
STATUS: done
STATUS: partial
STATUS: blocked
Then these markdown sections, in order:
## Changes         - each file touched: path and what changed, one line each
## Deviations      - anything done differently from the plan, or "None"
## Verification    - each command run, verbatim, and its outcome
## Open questions  - anything the reviewer must decide, or "None"
Keep it factual and short. Do not paste large diffs.

The plan follows. Its source path is PLAN_PATH_PLACEHOLDER; the full text is here.
EOF

  if [[ "$COMMIT_MODE" == "yes" ]]; then
    COMMIT_RULE="When every step is done and verified, commit the changes with a concise commit message. Do not stash, branch, tag, rebase, or reset. If the commit is refused by the sandbox, say so under Open questions and add a final section \"## Proposed commit message\" containing the message you would have used."
    FOOTER="Begin now. Remember: your final message starts with STATUS:."
  else
    COMMIT_RULE="Do NOT commit, stage, stash, branch, tag, rebase, reset, or otherwise write to .git. The sandbox blocks it; do not work around the sandbox. Read-only git (status, diff, log, show) is fine."
    FOOTER="Begin now. Remember: no commits, and your final message starts with STATUS:."
  fi
  HEADER="${HEADER//WORKSPACE_PLACEHOLDER/$WORKSPACE}"
  HEADER="${HEADER//PLAN_PATH_PLACEHOLDER/$PLAN_FILE}"
  HEADER="${HEADER//COMMIT_RULE_PLACEHOLDER/$COMMIT_RULE}"

  {
    printf '%s\n\n<plan>\n' "$HEADER"
    cat "$PLAN_FILE"
    printf '\n</plan>\n\n%s\n' "$FOOTER"
  } > "$PROMPT_FILE"

  # No --ephemeral: the session must persist so codex-resume.sh can continue it.
  # tee keeps the transcript in the captured output AND in a file we can grep for
  # the session id. codex prints its header (including the session id) on stderr, so
  # stderr is merged before the pipe. PIPESTATUS[0] is codex's exit code, not tee's.
  set +e
  codex exec \
    -C "$WORKSPACE" \
    -s workspace-write \
    -m "$MODEL_ID" \
    "${EFFORT_ARGS[@]}" \
    ${COMMIT_ARGS[@]+"${COMMIT_ARGS[@]}"} \
    -o "$REPORT_FILE" \
    - < "$PROMPT_FILE" 2>&1 | tee "$TRANSCRIPT_FILE"
  CODEX_RC=${PIPESTATUS[0]}
  set -e

  SESSION_ID=$(grep -m1 '^session id: ' "$TRANSCRIPT_FILE" | awk '{print $3}' || true)
  echo "SESSION_ID: ${SESSION_ID:-unknown}"
  echo "CODEX_EXIT: $CODEX_RC"
  echo "--- REPORT ---"
  if [[ -s "$REPORT_FILE" ]]; then cat "$REPORT_FILE"; else echo "(empty report)"; fi
  exit "$CODEX_RC"
}

main "$@"
