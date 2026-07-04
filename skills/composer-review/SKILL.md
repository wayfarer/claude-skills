---
name: composer-review
description: Review a git commit range with an external Cursor agent (Composer 2.5 by default) against the workspace's CLAUDE.md standards, then apply fixes in the same chat session if needed. Usage: /composer-review [model] [--range <rev-range>].
---

# Composer Review

Run an external Cursor agent (Composer 2.5 by default) against the last git commit:
review it for compliance with the project's documented standards, then execute
remediation if needed. Works in any workspace that has a `CLAUDE.md`.

## Usage

`/composer-review [model] [--range <rev-range>]`

`[model]` is optional. With no argument, defaults to `composer-2.5`. Accepts semantic
names — spacing and case are normalized before resolution:

| You type | Resolves to |
|---|---|
| *(omitted)* | `composer-2.5` |
| `composer 2.5 fast` | `composer-2.5-fast` |
| `GPT 5.5` or `gpt-5.5` | `gpt-5.5-high` |
| `GPT 5.5 medium` | `gpt-5.5-medium` |
| `Opus 4.8` | `claude-opus-4-8-high` |
| `Fable 5` | `claude-fable-5-high` |
| `Sonnet 4.6` | `claude-4.6-sonnet-medium` |

Bare GPT and Opus/Fable family names default to the `high` tier; Sonnet's canonical
tier is `medium`. Run `agent models`
to see all valid IDs; any full ID is also accepted verbatim (the resolver prints a
`WARNING` to stderr when it passes a value through unrecognized, so typos surface).

`--range <rev-range>` is optional and selects what to review. It accepts any git
revision range and defaults to `HEAD~1..HEAD` (the last commit). Example:
`/composer-review --range main..HEAD` reviews everything on the current branch since
`main`.

## How it works

Four scripts live under this skill's `scripts/` directory. Reference them by this
skill's base directory (shown in the invocation header as
`Base directory for this skill: <SKILL_DIR>`), not by a project-relative path. Let
`SKILL_DIR` be that base directory.

- **`resolve-model.sh [semantic-name]`** — normalizes the model argument to a canonical
  `agent --model` ID. Called once; the resolved ID is passed to both harnesses.
- **`validate-range.sh [workspace] [rev-range]`** — checks that the range is a valid git
  range before the slow agent run, so a typo fails fast in-session. Exits 1 with an error
  on a bad range.
- **`composer-plan.sh [workspace] [model-id] [rev-range]`** — creates a dedicated chat
  session, then runs `agent --print --yolo --trust --resume <chat-id> --model <model-id>`.
  The plan prompt instructs the agent to read the workspace's `CLAUDE.md` (and any file it
  designates as binding) and check the range (default `HEAD~1..HEAD`, the last commit)
  against every rule documented there.
  Output starts with `CHAT_ID: <uuid>` (from the script), followed by the agent's
  response, which always starts with `PLAN_NEEDED: yes` or `PLAN_NEEDED: no`.
- **`composer-execute.sh <chat-id> [workspace] [model-id]`** — runs
  `agent --print --yolo --trust --resume <chat-id> --model <model-id>` in the same
  session to apply fixes and commit.

Both phases use the same resolved model and the same `CHAT_ID`, so the execute phase
always has the plan in context. Each invocation gets its own UUID-pinned session, so
multiple tasks can run concurrently in separate terminal tabs without collision.

## Instructions

When this skill is invoked:

**1. Ensure scripts are executable** (idempotent)
```bash
chmod +x "$SKILL_DIR"/scripts/resolve-model.sh "$SKILL_DIR"/scripts/composer-plan.sh "$SKILL_DIR"/scripts/composer-execute.sh "$SKILL_DIR"/scripts/validate-range.sh
```

**2. Split off `--range`, then resolve the model**
```bash
ARGS="$ARGUMENTS"; RANGE="HEAD~1..HEAD"
if [[ "$ARGS" == *"--range"* ]]; then
  RANGE=$(echo "$ARGS" | sed -E 's/.*--range[= ]+([^ ]+).*/\1/')
  ARGS=$(echo "$ARGS" | sed -E 's/--range[= ]+[^ ]+//')
fi
MODEL=$("$SKILL_DIR"/scripts/resolve-model.sh "$ARGS")
```
If `resolve-model.sh` exits 1, stop and show its error message to the user — do not
proceed.

**3. Validate the range** (fail fast before the slow agent run)
```bash
"$SKILL_DIR"/scripts/validate-range.sh "$PWD" "$RANGE"
```
If `validate-range.sh` exits 1, stop and show its error message to the user — do not
launch the background plan task.

**4. Run the plan harness as a background task**

Pick a deterministic output path and launch `composer-plan.sh` into it via the Bash tool
with `run_in_background: true`:
```bash
OUTPUT_FILE=$(mktemp /tmp/composer-plan.out.XXXXXX)
"$SKILL_DIR"/scripts/composer-plan.sh "$PWD" "$MODEL" "$RANGE" > "$OUTPUT_FILE" 2>&1
```
Inference typically takes 5–20 minutes; running in background lets you continue
responding to the user. Tell the user the task is running and you will report back when
it finishes. The background task re-invokes you automatically when it exits — do not
poll. (If you ever need to block on a condition, the `Monitor` tool is the right
primitive; there is no `Await` tool.)

When you are re-invoked on completion, read the output:
```bash
cat "$OUTPUT_FILE"
```

If the task exited non-zero, stop and show the output to the user — do not proceed.

**5. Parse the chat ID and verdict**
```bash
CHAT_ID=$(grep "^CHAT_ID:" "$OUTPUT_FILE" | head -1 | awk '{print $2}')
VERDICT=$(grep "^PLAN_NEEDED:" "$OUTPUT_FILE" | head -1 | awk '{print $2}')
```

If either value is empty, or `VERDICT` is neither `yes` nor `no`, stop and show the
output to the user — do not run the execute harness.

**6. Branch on verdict**

If `VERDICT` is `yes`:
```bash
"$SKILL_DIR"/scripts/composer-execute.sh "$CHAT_ID" "$PWD" "$MODEL"
```

If `VERDICT` is `no`, report that the last commit is clean and surface the joke from
the agent's output. Do not run the execute harness.

## Notes

- The model and `--range` are the only knobs. There is no env-var override — use the
  arguments. `--range` defaults to the last commit (`HEAD~1..HEAD`).
- The range is validated with git up front (`validate-range.sh`), so a typo'd range fails
  fast in-session instead of after a 5–20 minute agent run.
- The skill reviews against the **workspace's** `CLAUDE.md`, so it stays calibrated by
  whatever standards that project documents. Keep `CLAUDE.md` current.
- Bare GPT family names default to the `high` tier here (Cursor ships tiered model IDs),
  whereas `/codex-review` defaults to `medium` reasoning effort. The divergence is
  intentional — each skill follows its own CLI's idiom.
- Both harnesses use `--yolo` for full tool access. The plan phase needs `--yolo` so
  read-only commands like `git log` and file reads are not blocked; review-only intent
  is enforced by the prompt, not by tool gating.
- Requires the `agent` (Cursor Agent) CLI on `PATH`.
