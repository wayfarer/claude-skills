# Subagent Model

Sets the model used for all subagents spawned via the Agent tool for the remainder of this conversation.

## Usage

`/subagent-model [sonnet|opus|haiku|fable|inherit] | --status`

- `sonnet` — all subagents use the latest Sonnet
- `haiku` — all subagents use the latest Haiku
- `opus` — all subagents use the latest Opus
- `fable` — all subagents use the latest Fable
- `inherit` — subagents inherit the parent model (default behavior)
- `--status` — print the current session's subagent model without changing it

The named families always resolve to the most recent version of that model. Pass the bare alias (e.g. `model: "sonnet"`) to the Agent tool rather than a pinned model ID — the harness maps the alias to the newest release, so this stays current as new versions ship. For reference, the current latest per family are Sonnet 5 (`claude-sonnet-5`), Opus 4.8 (`claude-opus-4-8`), Haiku 4.5 (`claude-haiku-4-5`), and Fable 5 (`claude-fable-5`), but do not hardcode these IDs — always pass the alias.

## Instructions

When this skill is invoked:

0. **`--status` (standalone, read-only).** If the argument is `--status`, do **not** change any setting and do **not** treat it as a model name. Determine the current subagent model from the conversation so far (the most recent `/subagent-model` selection; if none was ever set, it is `inherit`). Render a formatted list of all selectable options, marking the current one as selected and leaving the rest visible-but-unselected, then stop — no acknowledgement of a new setting, no change to Agent-tool behavior. Use this format:

   ```
   Subagent model (this session)

     ● sonnet   — latest Sonnet   ← current
     ○ opus     — latest Opus
     ○ haiku    — latest Haiku
     ○ fable    — latest Fable
     ○ inherit  — parent model (default)
   ```

   The `●` and `← current` marker move to whichever option is active; every other option shows `○`.

1. Parse the argument. If no argument is given, confirm current subagent model setting and list options.
2. Acknowledge the new setting in one short sentence.
3. For the rest of this conversation, always pass the corresponding `model` parameter (using the bare alias) when calling the Agent tool:
   - `sonnet` → `model: "sonnet"`
   - `haiku` → `model: "haiku"`
   - `opus` → `model: "opus"`
   - `fable` → `model: "fable"`
   - `inherit` → omit the `model` parameter entirely
