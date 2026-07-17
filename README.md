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
  Defaults to `gpt-5.6-sol` at medium reasoning effort; supports the full gpt-5.6
  family (sol/terra/luna) with full tier control (low/medium/high/xhigh/max), earlier
  GPT-5.x models, and o-series models. Requires the `codex` CLI on `PATH` (≥ 0.144.0
  for gpt-5.6) and valid OpenAI auth.
- **composer-review** — drives an external Cursor agent (`agent` CLI, Composer 2.5
  by default) to review a commit range against the workspace's own `CLAUDE.md`,
  then execute remediation. Reviews the last commit by default; pass `--range <rev-range>`
  to widen it. Project-agnostic: it reads whatever standards the current project documents.
- **subagent-model** — sets the model used for subagents spawned via the Agent tool
  for the remainder of a conversation.
- **tour-bus** — gives a brief "tour bus" explanation of any subject: one or two
  paragraphs of plain prose at sightseer altitude, grounded in the current
  conversation when relevant. Usage: `/tour-bus <subject or question>`.

## Setup on a new machine

```bash
git clone <remote> ~/Projects/claude-skills
# back up an existing real ~/.claude/skills first if present
ln -s ~/Projects/claude-skills/skills ~/.claude/skills
```
