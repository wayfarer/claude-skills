#!/usr/bin/env bash
# Resolve a semantic model name to a canonical codex CLI model spec.
# Output is MODEL_ID or MODEL_ID:EFFORT (colon-separated when effort applies).
# Usage: resolve-model.sh [semantic-name]
# With no argument, prints the default: gpt-5.5:medium
# Exits 1 and prints an error if the input is unrecognized.

set -euo pipefail

input="${*:-}"

# Normalize: lowercase, collapse whitespace to hyphens, strip leading/trailing hyphens
normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -s ' \t' '-' | sed 's/^-*//;s/-*$//')

case "$normalized" in
  # Default / GPT-5.5 bare — medium effort
  ""|"gpt-5.5"|"gpt5.5"|"gpt-5-5")
    echo "gpt-5.5:medium" ;;

  # GPT-5.5 with explicit tier
  "gpt-5.5-low"|"gpt5.5-low")             echo "gpt-5.5:low" ;;
  "gpt-5.5-medium"|"gpt5.5-medium")       echo "gpt-5.5:medium" ;;
  "gpt-5.5-high"|"gpt5.5-high")           echo "gpt-5.5:high" ;;
  "gpt-5.5-xhigh"|"gpt-5.5-extra-high"|"gpt5.5-xhigh")
    echo "gpt-5.5:xhigh" ;;

  # GPT-5.4 bare — medium effort
  "gpt-5.4"|"gpt5.4"|"gpt-5-4")
    echo "gpt-5.4:medium" ;;

  # GPT-5.4 with explicit tier
  "gpt-5.4-low"|"gpt5.4-low")             echo "gpt-5.4:low" ;;
  "gpt-5.4-medium"|"gpt5.4-medium")       echo "gpt-5.4:medium" ;;
  "gpt-5.4-high"|"gpt5.4-high")           echo "gpt-5.4:high" ;;
  "gpt-5.4-xhigh"|"gpt-5.4-extra-high"|"gpt5.4-xhigh")
    echo "gpt-5.4:xhigh" ;;

  # GPT-5.4-mini — medium effort
  "gpt-5.4-mini"|"gpt5.4-mini")
    echo "gpt-5.4-mini:medium" ;;

  # GPT-5.3 codex spark — medium effort
  "gpt-5.3-codex-spark"|"codex-spark"|"spark")
    echo "gpt-5.3-codex-spark:medium" ;;

  # o-series: intrinsic reasoning, no effort flag
  "o3")       echo "o3" ;;
  "o4-mini"|"o4mini")  echo "o4-mini" ;;
  "o4")       echo "o4" ;;
  "o3-mini"|"o3mini")  echo "o3-mini" ;;

  # Pass-through: already looks like a full model ID or model:effort spec — trust it,
  # but warn on stderr so typos surface (stdout must stay exactly the resolved spec).
  *"."*|*"-"*"-"*|*":"*)
    echo "WARNING: '${input}' is not a known alias; passing through verbatim." >&2
    echo "$normalized" ;;

  *)
    echo "ERROR: unrecognized model '${input}'. Known aliases: gpt-5.5 [low|medium|high|xhigh], gpt-5.4 [low|medium|high|xhigh], gpt-5.4-mini, codex-spark, o3, o4, o4-mini, o3-mini." >&2
    exit 1 ;;
esac
