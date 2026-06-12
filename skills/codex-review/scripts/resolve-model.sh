#!/usr/bin/env bash
# Resolve a semantic model name to a canonical codex CLI model ID.
# Usage: resolve-model.sh [semantic-name]
# With no argument, prints the default: o3
# Exits 1 and prints an error if the input is unrecognized.

set -euo pipefail

input="${*:-}"

# Normalize: lowercase, collapse whitespace to hyphens, strip leading/trailing hyphens
normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -s ' \t' '-' | sed 's/^-*//;s/-*$//')

case "$normalized" in
  # Default / o3
  ""|"o3")
    echo "o3" ;;

  # o4-mini
  "o4-mini"|"o4mini")
    echo "o4-mini" ;;

  # o4 (full)
  "o4")
    echo "o4" ;;

  # o3-mini
  "o3-mini"|"o3mini")
    echo "o3-mini" ;;

  # GPT-5.5
  "gpt-5.5"|"gpt5.5"|"gpt-5-5")
    echo "gpt-5.5" ;;

  # GPT-5.4
  "gpt-5.4"|"gpt5.4"|"gpt-5-4")
    echo "gpt-5.4" ;;

  # GPT-5.4-mini
  "gpt-5.4-mini"|"gpt5.4-mini")
    echo "gpt-5.4-mini" ;;

  # GPT-5.3 codex spark
  "gpt-5.3-codex-spark"|"codex-spark"|"spark")
    echo "gpt-5.3-codex-spark" ;;

  # Pass-through: already looks like a full model ID
  *"."*|*"-"*"-"*)
    echo "$normalized" ;;

  *)
    echo "ERROR: unrecognized model '${input}'. Pass a full model ID or a known alias (o3, o4-mini, o4, o3-mini, gpt-5.5, gpt-5.4)." >&2
    exit 1 ;;
esac
