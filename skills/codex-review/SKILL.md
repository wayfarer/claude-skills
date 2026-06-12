# Codex Review

Run an external OpenAI Codex agent (`codex exec review`) against the last git commit:
review it for compliance with the project's documented standards, then execute
remediation if needed. Works in any workspace that has a `CLAUDE.md`.

## Usage

`/codex-review [model]`

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

Any full model ID is also accepted verbatim.

Reasoning effort (`low`/`medium`/`high`/`xhigh`) is passed to the Codex CLI as
`-c model_reasoning_effort=<tier>`. o-series models manage their own reasoning depth
and do not use this flag.

## How it works

Three scripts live under this skill's `scripts/` directory. Reference them by this
skill's base directory (shown in the invocation header as
`Base directory for this skill: <SKILL_DIR>`), not by a project-relative path. Let
`SKILL_DIR` be that base directory.

- **`resolve-model.sh [semantic-name]`** — normalizes the model argument to a canonical
  model spec (`MODEL_ID` or `MODEL_ID:EFFORT`). Called once; the resolved spec is
  passed to both harnesses.
- **`codex-plan.sh [workspace] [model-spec]`** — runs `codex exec review --commit HEAD`
  with a custom prompt that instructs the agent to check `CLAUDE.md` and emit
  `PLAN_NEEDED: yes` or `PLAN_NEEDED: no` as the first line. The review is captured
  to a temp file via `-o`. Output starts with `REVIEW_FILE: <path>` (emitted by the
  script), followed by the agent's response.
- **`codex-execute.sh <review-file> [workspace] [model-spec]`** — runs
  `codex exec -s workspace-write` with the review output embedded in the prompt via
  stdin, so the agent has full context to apply fixes and commit.

Unlike Cursor Composer, Codex exec is one-shot (no `--resume` sessions). The two
phases communicate through the temp file written by the plan harness.

## Instructions

When this skill is invoked:

**1. Ensure scripts are executable** (idempotent)
```bash
chmod +x "$SKILL_DIR"/scripts/resolve-model.sh "$SKILL_DIR"/scripts/codex-plan.sh "$SKILL_DIR"/scripts/codex-execute.sh
```

**2. Resolve the model**
```bash
MODEL=$("$SKILL_DIR"/scripts/resolve-model.sh "$ARGUMENTS")
```
If `resolve-model.sh` exits 1, stop and show its error message to the user — do not
proceed.

**3. Run the plan harness and capture output**
```bash
PLAN_OUTPUT=$("$SKILL_DIR"/scripts/codex-plan.sh "$PWD" "$MODEL")
echo "$PLAN_OUTPUT"
```

**4. Parse the review file path and verdict**
```bash
REVIEW_FILE=$(echo "$PLAN_OUTPUT" | grep "^REVIEW_FILE:" | head -1 | awk '{print $2}')
VERDICT=$(echo "$PLAN_OUTPUT" | grep "^PLAN_NEEDED:" | head -1 | awk '{print $2}')
```

**5. Branch on verdict**

If `VERDICT` is `yes`:
```bash
"$SKILL_DIR"/scripts/codex-execute.sh "$REVIEW_FILE" "$PWD" "$MODEL"
```

If `VERDICT` is `no`, report that the last commit is clean and surface the joke from
the agent's output. Do not run the execute harness.

## Notes

- The model is the only knob. There is no env-var override — use the argument.
- The skill reviews against the **workspace's** `CLAUDE.md`, so it stays calibrated by
  whatever standards that project documents. Keep `CLAUDE.md` current.
- The plan harness uses `codex exec review` (read-only by Codex's own sandbox policy);
  the execute harness uses `-s workspace-write` for full file access.
- The review temp file is written to `/tmp` and left in place after the run. Clean up
  with `rm /tmp/codex-review-*.md` if needed.
- Requires the `codex` CLI on `PATH` and valid OpenAI auth (`codex login`).
