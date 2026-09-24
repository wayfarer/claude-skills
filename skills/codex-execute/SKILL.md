---
name: codex-execute
description: >-
  Hand an implementation plan to an external OpenAI Codex agent (gpt-6-astra at high reasoning effort by default) to execute in the current workspace, then review its diff against the plan and the workspace's CLAUDE.md, remediate if needed, and commit. Usage: /codex-execute [model] [--plan <path>] [--commit].
---

# Codex Execute

Offload an approved plan to an external OpenAI Codex agent, then review what it did.
This is the inverse of `/codex-review`: there, Codex reviews Claude's commit; here,
Codex executes Claude's plan and Claude reviews the result. In both, Claude is the
ultimate decider: nothing is committed until Claude has read the diff.

## Usage

`/codex-execute [model] [--plan <path>] [--commit]`

`[model]` is optional and accepts the same aliases as `/codex-review` (see its table:
`astra`, `gpt-6`, `sol`, `terra`, `luna`, `gpt-5.5`, with `low`/`medium`/`high`/`xhigh`/
`max`/`ultra` tiers where the catalog offers them). The default is `gpt-6-astra`.
Execution is floored at `high`: a bare name or a `low`/`medium` tier runs at `high`,
while `xhigh`, `max` and `ultra` are kept as requested. Applying edits is the expensive
thing to get wrong; the cheap review pass lives in `/codex-review`.

`--plan <path>` names the plan file (markdown). Without it, the plan is resolved in
this order:

1. The plan file from this session's plan mode, if there is one (the path shown under
   "Plan File Info"). State the path to the user before proceeding.
2. Otherwise the newest file under `~/.claude/plans/`. This is a guess: show its title
   and confirm with the user before launching.

`--commit` asks Codex to commit its own work when done. Without it, Codex leaves the
changes uncommitted in the working tree and Claude commits after review. See Notes for
the sandbox implications.

## How it works

Five scripts live under this skill's `scripts/` directory. Reference them by this
skill's base directory (shown in the invocation header as
`Base directory for this skill: <SKILL_DIR>`), not by a project-relative path. Let
`SKILL_DIR` be that base directory.

- **`resolve-model.sh [semantic-name]`** — a symlink to codex-review's resolver, so the
  alias table has one source of truth. Prints `MODEL_ID` or `MODEL_ID:EFFORT`.
- **`resolve-plan.sh [plan-path]`** — validates the plan file, or picks the newest one
  under `~/.claude/plans/` when none is given. Prints `PLAN_FILE:`, `PLAN_TITLE:`,
  `PLAN_GUESSED: yes|no`, and `PLAN_WARN:` lines if the plan lacks a Changes or
  Verification section.
- **`check-workspace.sh [workspace]`** — fail-fast preflight: git repo with commits,
  `codex` on PATH, and no modified or staged tracked files (Codex's diff must be
  reviewable on its own). Prints `BASE_SHA:`, `BRANCH:`, `CODEX_VERSION:` and one
  `PRE_UNTRACKED:` line per untracked path that already existed.
- **`codex-run.sh <plan-file> [workspace] [model-spec] [--commit]`** — runs
  `codex exec -s workspace-write` with the plan embedded in the prompt (fed over stdin),
  no `--ephemeral` so the session can be resumed, and `-o` to capture the agent's final
  report. Prints `REPORT_FILE:`, `PROMPT_FILE:`, the transcript, then `SESSION_ID:`,
  `CODEX_EXIT:`, and the report. The report's first line is `STATUS: done`,
  `STATUS: partial` or `STATUS: blocked`, followed by `## Changes`, `## Deviations`,
  `## Verification` and `## Open questions`.
- **`codex-resume.sh <session-id> <feedback-file> [workspace] [model-spec]`** — runs
  `codex exec resume` on that session with Claude's review feedback embedded, so the
  agent fixes its own work with the original plan still in context. Same output shape.

## Instructions

When this skill is invoked:

**1. Ensure scripts are executable** (idempotent)
```bash
chmod +x "$SKILL_DIR"/scripts/resolve-plan.sh "$SKILL_DIR"/scripts/check-workspace.sh "$SKILL_DIR"/scripts/codex-run.sh "$SKILL_DIR"/scripts/codex-resume.sh
```

**2. Split off `--plan` and `--commit`, then resolve the model**
```bash
ARGS="$ARGUMENTS"; PLAN_ARG=""; COMMIT_FLAG=""
if [[ "$ARGS" == *"--plan"* ]]; then
  PLAN_ARG=$(echo "$ARGS" | sed -E 's/.*--plan[= ]+([^ ]+).*/\1/')
  ARGS=$(echo "$ARGS" | sed -E 's/--plan[= ]+[^ ]+//')
fi
if [[ "$ARGS" == *"--commit"* ]]; then
  COMMIT_FLAG="--commit"
  ARGS=$(echo "$ARGS" | sed -E 's/--commit//')
fi
MODEL=$("$SKILL_DIR"/scripts/resolve-model.sh "$ARGS")
```
If `resolve-model.sh` exits 1, stop and show its error message to the user.

**3. Resolve the plan**

If `PLAN_ARG` is empty and this session has a plan file from plan mode, use that path
as `PLAN_ARG` and tell the user which plan you are handing over. Then:
```bash
"$SKILL_DIR"/scripts/resolve-plan.sh "$PLAN_ARG"
```
If it exits 1, stop and show the error. If it prints `PLAN_GUESSED: yes`, show
`PLAN_TITLE` and confirm with the user (`AskUserQuestion`) before going on; a wrong
plan costs a 5–20 minute run. If it prints a `PLAN_WARN` about Verification, tell the
user the review will be by inspection. Keep `PLAN_FILE`.

**4. Preflight the workspace**
```bash
"$SKILL_DIR"/scripts/check-workspace.sh "$PWD"
```
If it exits 1, stop and show the message. Suggest the user commit or stash; do not do
it for them. Keep `BASE_SHA` and the `PRE_UNTRACKED` list for the review step.

**5. Run the execute harness as a background task**
```bash
OUTPUT_FILE=$(mktemp /tmp/codex-execute.out.XXXXXX)
"$SKILL_DIR"/scripts/codex-run.sh "$PLAN_FILE" "$PWD" "$MODEL" $COMMIT_FLAG > "$OUTPUT_FILE" 2>&1
```
Launch via the Bash tool with `run_in_background: true`. Inference typically takes
5–20 minutes; running in background lets you continue responding to the user. Tell the
user the task is running and you will report back when it finishes. The background task
re-invokes you automatically when it exits; do not poll. (If you ever need to block on
a condition, the `Monitor` tool is the right primitive; there is no `Await` tool.)

**6. Read the result**
```bash
cat "$OUTPUT_FILE"
REPORT_FILE=$(grep "^REPORT_FILE:" "$OUTPUT_FILE" | head -1 | awk '{print $2}')
SESSION_ID=$(grep "^SESSION_ID:" "$OUTPUT_FILE" | head -1 | awk '{print $2}')
CODEX_EXIT=$(grep "^CODEX_EXIT:" "$OUTPUT_FILE" | head -1 | awk '{print $2}')
STATUS=$(head -1 "$REPORT_FILE" | awk '{print $2}')
```
Parse `STATUS` from the report file, never from `$OUTPUT_FILE`: `codex exec` echoes the
prompt into its transcript, and the prompt itself contains `STATUS:` lines.

**Always proceed to the review**, whatever `CODEX_EXIT` or `STATUS` say. Codex may have
edited files before failing, and the tree must not be left unexamined. A non-zero exit,
an empty report, or a `STATUS` other than `done` is context for the review, not a reason
to skip it.

**7. Review the work** (Claude is the decider)

- `git status --short`, `git diff --stat`, `git diff`. Untracked paths that are not in
  `PRE_UNTRACKED` were created by Codex.
- Without `--commit`: confirm `git rev-parse HEAD` still equals `BASE_SHA`. If it does
  not, Codex committed despite instructions; report that, review with
  `git diff BASE_SHA..HEAD`, and only `git reset --soft BASE_SHA` with the user's
  explicit confirmation.
- With `--commit`: expect HEAD to have advanced. Review with `git diff BASE_SHA..HEAD`
  and `git log BASE_SHA..HEAD`. If HEAD did not move, the sandbox refused the commit;
  the report should carry a `## Proposed commit message` section.
- Read the plan's Changes section and the workspace `CLAUDE.md`. Check that every plan
  item landed, that nothing outside the plan's scope changed, and that the project's
  conventions hold. Read `## Deviations` and `## Open questions` critically: a
  deviation is a judgement call Codex made on Claude's behalf.
- Run the plan's Verification commands yourself. Do not trust the report's
  `## Verification` section: the sandbox may have blocked network or tooling.

**8. Decide**

- **Accept.** Without `--commit`: `git add` the explicit reviewed paths (never `-A` or
  `.`), then commit with a message derived from the plan title and the workspace's
  commit conventions. With `--commit`: nothing to do if Codex committed; if the sandbox
  refused, commit with the proposed message from the report. Report `STATUS`, the
  commit, and any deviations to the user.
- **Remediate, small** (a missed line, a convention slip, a typo): edit directly,
  re-run verification, then accept. With `--commit`, land it as a follow-up commit.
- **Remediate, large** (a missed plan item, a wrong approach in one section): write the
  feedback as numbered items to a temp file and send it back into the session:
  ```bash
  FEEDBACK_FILE=$(mktemp /tmp/codex-execute-feedback-XXXXXX); mv "$FEEDBACK_FILE" "$FEEDBACK_FILE.md"; FEEDBACK_FILE="$FEEDBACK_FILE.md"
  # write the feedback into $FEEDBACK_FILE, then:
  OUTPUT_FILE=$(mktemp /tmp/codex-execute.out.XXXXXX)
  "$SKILL_DIR"/scripts/codex-resume.sh "$SESSION_ID" "$FEEDBACK_FILE" "$PWD" "$MODEL" > "$OUTPUT_FILE" 2>&1
  ```
  in the background, then return to step 6. At most two resume rounds; after that,
  finish by hand or reject. If `SESSION_ID` is `unknown` or the resume fails, fall back
  to writing a short remediation plan and running `codex-run.sh` on it, or fixing
  directly.
- **Reject.** Show the user the diff summary and the reason. Revert only after their
  explicit confirmation: `git checkout -- <tracked paths>` and `rm` only the
  Codex-created untracked paths (never pre-existing ones). With `--commit`,
  `git reset --soft BASE_SHA` first.

`STATUS: blocked`, an empty or garbled report: review the tree anyway, surface the
`## Open questions` to the user, do not commit, and offer either a resume round with
answers or a revert. `STATUS: partial`: finish the remainder directly if it is small,
otherwise resume with feedback naming the missing items.

## Notes

- The model, `--plan` and `--commit` are the only knobs. There is no env-var override.
- The workspace must have a clean tracked tree before the run so that Codex's diff is
  the whole diff. Pre-existing untracked files are fine and are listed up front.
- Codex's `workspace-write` sandbox refuses writes to `.git` (observed: "sandbox
  prohibits writing .git/index.lock"). That is why the default mode has Codex leave the
  tree uncommitted and Claude commit. `--commit` passes `--add-dir <workspace>/.git`,
  which widens the sandbox enough for `git commit` (verified on Codex CLI 0.154.0). If a
  future version still refuses, the prompt tells Codex to report a proposed commit
  message instead, and Claude commits with it.
- Codex runs with `approval: never` under `exec`: anything the sandbox refuses is
  denied, not prompted. Verification steps that need network will fail inside Codex;
  Claude re-runs them in step 7.
- The session is persisted (no `--ephemeral`) so `codex-resume.sh` can continue it.
  `codex exec resume` has no `-C`/`-s` flags: the harness `cd`s into the workspace and
  passes `-c sandbox_mode="workspace-write"`. Check the resumed transcript header shows
  `sandbox: workspace-write`; if it shows `read-only`, use the fallback in step 8.
- If the workspace is this skills repo, the agent can edit the harness while it runs.
  Both harnesses keep their body in `main()` so bash parses the whole file first.
- Temp files (`/tmp/codex-execute-*`) are left in place for auditing; the prompt file
  shows exactly what Codex was told. Clean up with `rm /tmp/codex-execute-*` if needed.
- Requires the `codex` CLI on `PATH` and valid OpenAI auth (`codex login`). Model
  availability follows the installed CLI's catalog (`codex debug models`); see the
  `/codex-review` notes.
