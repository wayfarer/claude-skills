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

- **composer-review** — drives an external Cursor agent (`agent` CLI, Composer 2.5
  by default) to review the last git commit against the workspace's own `CLAUDE.md`,
  then execute remediation. Project-agnostic: it reads whatever standards the current
  project documents.
- **subagent-model** — sets the model used for subagents spawned via the Agent tool
  for the remainder of a conversation.

## Setup on a new machine

```bash
git clone <remote> ~/Projects/claude-skills
# back up an existing real ~/.claude/skills first if present
ln -s ~/Projects/claude-skills/skills ~/.claude/skills
```
