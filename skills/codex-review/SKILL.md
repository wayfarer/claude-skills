---
name: codex-review
description: Review a git commit range with an external OpenAI Codex agent (gpt-5.5 at medium reasoning effort by default) against the workspace's CLAUDE.md standards, then apply fixes if needed. Usage: /codex-review [model] [--range <rev-range>].
---

# Codex Review

Run an external OpenAI Codex agent against the last git commit (or any commit range):
review it for compliance with the project's documented standards, then execute
remediation if needed. Works in any workspace that has a `CLAUDE.md`.

## Usage

`/codex-review [model] [--range <rev-range>]`

`[model]` is optional. With no argument, defaults to `gpt-5.5` at medium reasoning
effort. Accepts semantic names — spacing and case are normalized before resolution:

| You type | Resolves to |
|---|---|
| *(omitted)* | `gpt-5.5` @ medium effort |
| `gpt-5.5` | `gpt-5.5` @ medium |
| `gpt-5.5 low` | `gpt-5.5` @ low |
| `gpt-5.5 high` | `gpt-5.5` @ high |
| `gpt-5.5 xhigh` | `gpt-5.5` @ xhigh |
| `gpt-5.4` | `gpt-5.4` @ medium |
| `gpt-5.4 low` / `medium` / `high` / `xhigh` | `gpt-5.4` @ that tier |
| `gpt-5.4-mini` | `gpt-5.4-mini` @ medium |
| `codex spark` | `gpt-5.3-codex-spark` @ medium |
| `o3` | `o3` (intrinsic reasoning, no effort flag) |
| `o4-mini` | `o4-mini` (intrinsic reasoning) |
| `o4` | `o4` (intrinsic reasoning) |
| `o3-mini` | `o3-mini` (intrinsic reasoning) |

Any full model ID or `MODEL:EFFORT` spec is also accepted verbatim (the resolver prints
a `WARNING` to stderr when it passes a value through unrecognized, so typos surface).

Reasoning effort (`low`/`medium`/`high`/`xhigh`) is passed to the Codex CLI as
`-c model_reasoning_effort=<tier>`. o-series models manage their own reasoning depth
and do not use this flag.

`--range <rev-range>` is optional and selects what to review. It accepts any git
revision range and defaults to `HEAD~1..HEAD` (the last commit). Example:
`/codex-review --range main..HEAD` reviews everything on the current branch since
`main`.

## How it works

Four scripts live under this skill's `scripts/` directory. Reference them by this
skill's base directory (shown in the invocation header as
`Base directory for this skill: <SKILL_DIR>`), not by a project-relative path. Let
`SKILL_DIR` be that base directory.

- **`resolve-model.sh [semantic-name]`** — normalizes the model argument to a canonical
  model spec (`MODEL_ID` or `MODEL_ID:EFFORT`). Called once; the resolved spec is
  passed to both harnesses.
- **`validate-range.sh [workspace] [rev-range]`** — checks that the range is a valid git
  range before the slow agent run, so a typo fails fast in-session. Exits 1 with an error
  on a bad range.
- **`codex-plan.sh [workspace] [model-spec] [rev-range]`** — runs `codex exec -s read-only`
  with a prompt that instructs the agent to read `CLAUDE.md`, diff the range (default
  `HEAD~1..HEAD`, the last commit) itself, and emit `PLAN_NEEDED: yes` or
  `PLAN_NEEDED: no` as the first line. The verdict + plan are captured to a temp file via
  `--output-last-message`. Output starts with `REVIEW_FILE: <path>` (emitted by the
  script), followed by the captured review.
- **`codex-execute.sh <review-file> [workspace] [model-spec]`** — runs
  `codex exec -s workspace-write` with the review output embedded in the prompt, so the
  agent has full context to apply fixes and commit.

Unlike Cursor Composer, Codex exec is one-shot (no `--resume` sessions). The two
phases communicate through the temp file written by the plan harness. Each invocation
gets its own `mktemp` review file, so multiple tasks can run concurrently without
collision. The range is driven through the prompt (the agent runs `git diff` itself),
exactly like composer-review.

## Instructions

When this skill is invoked:

**1. Ensure scripts are executable** (idempotent)
```bash
chmod +x "$SKILL_DIR"/scripts/resolve-model.sh "$SKILL_DIR"/scripts/codex-plan.sh "$SKILL_DIR"/scripts/codex-execute.sh "$SKILL_DIR"/scripts/validate-range.sh
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

Pick a deterministic output path and launch `codex-plan.sh` into it via the Bash tool
with `run_in_background: true`:
```bash
OUTPUT_FILE=$(mktemp /tmp/codex-plan.out.XXXXXX)
"$SKILL_DIR"/scripts/codex-plan.sh "$PWD" "$MODEL" "$RANGE" > "$OUTPUT_FILE" 2>&1
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

**5. Parse the review file path and verdict**

Parse the verdict from the review file, not from `$OUTPUT_FILE` — `codex exec` echoes
the prompt into its transcript, and the prompt itself contains `PLAN_NEEDED:` lines.
The review file holds only the agent's final message.
```bash
REVIEW_FILE=$(grep "^REVIEW_FILE:" "$OUTPUT_FILE" | head -1 | awk '{print $2}')
VERDICT=$(grep "^PLAN_NEEDED:" "$REVIEW_FILE" | head -1 | awk '{print $2}')
```

If either value is empty, or `VERDICT` is neither `yes` nor `no`, stop and show the
output to the user — do not run the execute harness.

**6. Branch on verdict**

If `VERDICT` is `yes`:
```bash
"$SKILL_DIR"/scripts/codex-execute.sh "$REVIEW_FILE" "$PWD" "$MODEL"
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
- Bare GPT family names default to `medium` reasoning effort here, whereas
  `/composer-review` defaults to Cursor's `high` tier. The divergence is intentional —
  each skill follows its own CLI's idiom.
- The plan harness uses `codex exec -s read-only` (file writes are sandboxed out while
  reads and `git diff`/`git log` are allowed); the execute harness uses
  `-s workspace-write` for full file access.
- The review temp file is written to `/tmp` and left in place after the run. Clean up
  with `rm /tmp/codex-review-*.md` if needed.
- Requires the `codex` CLI on `PATH` and valid OpenAI auth (`codex login`).
