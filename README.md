# claude-skills

Version-controlled global skills for Claude Code. Each subfolder under `skills/`
is a self-contained skill (a `SKILL.md` plus any supporting scripts), available
in every project on this machine.

## How it's wired

`~/.claude/skills` is a symlink to this repo's `skills/` directory:

```bash
ln -s ~/Projects/claude-skills/skills ~/.claude/skills
```

Claude Code loads every skill under `~/.claude/skills/`, so anything committed
here is globally available. To add a skill, create `skills/<name>/SKILL.md`
(co-locate helper scripts under `skills/<name>/scripts/`) and commit it.

## Skills

- **codex-review** — runs an external OpenAI Codex agent (`codex exec`) to review a
  commit range against the workspace's own `CLAUDE.md`, then execute remediation if
  needed. Reviews the last commit by default; pass `--range <rev-range>` to widen it.
  Defaults to `gpt-6-astra` (medium reasoning effort to review, high to apply
  fixes); also aliases the gpt-5.6 family (sol/terra/luna) and legacy gpt-5.5, with
  full tier control (low/medium/high/xhigh/max, plus ultra where the catalog offers
  it). Requires the
  `codex` CLI on `PATH` (gpt-6-astra verified with 0.154.0) and valid OpenAI auth.
- **codex-execute** — the inverse of codex-review: hands an approved plan (a markdown
  file, by default this session's plan or the newest under `~/.claude/plans/`) to an
  external OpenAI Codex agent to execute in the workspace, then Claude reviews the
  diff against the plan and `CLAUDE.md`, remediates (directly, or by resuming the Codex
  session with feedback), and commits. Defaults to `gpt-6-astra` at high reasoning
  effort. Usage: `/codex-execute [model] [--plan <path>] [--commit]`.
- **composer-review** — drives an external Cursor agent (`agent` CLI, Composer 2.5
  by default) to review a commit range against the workspace's own `CLAUDE.md`,
  then execute remediation. Reviews the last commit by default; pass `--range <rev-range>`
  to widen it. Project-agnostic: it reads whatever standards the current project documents.
- **subagent-model** — sets the model used for subagents spawned via the Agent tool
  for the remainder of a conversation.
- **tour-bus** — gives a brief "tour bus" explanation of any subject: one or two
  paragraphs of plain prose at sightseer altitude, grounded in the current
  conversation when relevant. Repeat calls can name a landmark from a previous
  tour to zoom into it. Usage: `/tour-bus <subject or question>`.

## Setup on a new machine

```bash
git clone <remote> ~/Projects/claude-skills
# back up an existing real ~/.claude/skills first if present
ln -s ~/Projects/claude-skills/skills ~/.claude/skills
```
