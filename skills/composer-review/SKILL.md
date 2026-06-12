# Composer Review

Run an external Cursor agent (Composer 2.5 by default) against the last git commit:
review it for compliance with the project's documented standards, then execute
remediation if needed. Works in any workspace that has a `CLAUDE.md`.

## Usage

`/composer-review [model]`

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

A bare family name (e.g. `GPT 5.5`) defaults to the `high` tier. Run `agent models`
to see all valid IDs; any full ID is also accepted verbatim.

## How it works

Three scripts live under this skill's `scripts/` directory. Reference them by this
skill's base directory (shown in the invocation header as
`Base directory for this skill: <SKILL_DIR>`), not by a project-relative path. Let
`SKILL_DIR` be that base directory.

- **`resolve-model.sh [semantic-name]`** — normalizes the model argument to a canonical
  `agent --model` ID. Called once; the resolved ID is passed to both harnesses.
- **`composer-plan.sh [workspace] [model-id]`** — creates a dedicated chat session,
  then runs `agent --print --plan --trust --resume <chat-id> --model <model-id>`. The
  plan prompt instructs the agent to read the workspace's `CLAUDE.md` (and any file it
  designates as binding) and check the last commit against every rule documented there.
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
chmod +x "$SKILL_DIR"/scripts/resolve-model.sh "$SKILL_DIR"/scripts/composer-plan.sh "$SKILL_DIR"/scripts/composer-execute.sh
```

**2. Resolve the model**
```bash
MODEL=$("$SKILL_DIR"/scripts/resolve-model.sh "$ARGUMENTS")
```
If `resolve-model.sh` exits 1, stop and show its error message to the user — do not
proceed.

**3. Run the plan harness and capture output**
```bash
PLAN_OUTPUT=$("$SKILL_DIR"/scripts/composer-plan.sh "$PWD" "$MODEL")
echo "$PLAN_OUTPUT"
```

**4. Parse the chat ID and verdict**
```bash
CHAT_ID=$(echo "$PLAN_OUTPUT" | grep "^CHAT_ID:" | head -1 | awk '{print $2}')
VERDICT=$(echo "$PLAN_OUTPUT" | grep "^PLAN_NEEDED:" | head -1 | awk '{print $2}')
```

**5. Branch on verdict**

If `VERDICT` is `yes`:
```bash
"$SKILL_DIR"/scripts/composer-execute.sh "$CHAT_ID" "$PWD" "$MODEL"
```

If `VERDICT` is `no`, report that the last commit is clean and surface the joke from
the agent's output. Do not run the execute harness.

## Notes

- The model is the only knob. There is no env-var override — use the argument.
- The skill reviews against the **workspace's** `CLAUDE.md`, so it stays calibrated by
  whatever standards that project documents. Keep `CLAUDE.md` current.
- The plan harness is read-only (`--plan`); it cannot edit files. The execute harness
  uses `--yolo` for full tool access.
- Requires the `agent` (Cursor Agent) CLI on `PATH`.
