# Subagent Model

Sets the model used for all subagents spawned via the Agent tool for the remainder of this conversation.

## Usage

`/subagent-model [sonnet|opus|haiku|inherit]`

- `sonnet` — all subagents use claude-sonnet-4-6 regardless of parent model
- `haiku` — all subagents use claude-haiku-4-5 regardless of parent model
- `opus` — all subagents use claude-opus-4-8 regardless of parent model
- `inherit` — subagents inherit the parent model (default behavior)

## Instructions

When this skill is invoked:

1. Parse the argument. If no argument is given, confirm current subagent model setting and list options.
2. Acknowledge the new setting in one short sentence.
3. For the rest of this conversation, always pass the corresponding `model` parameter when calling the Agent tool:
   - `sonnet` → `model: "sonnet"`
   - `haiku` → `model: "haiku"`
   - `opus` → `model: "opus"`
   - `inherit` → omit the `model` parameter entirely
