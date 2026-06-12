#!/usr/bin/env bash
# Resolve a semantic model name to a canonical agent CLI model ID.
# Usage: resolve-model.sh [semantic-name]
# With no argument, prints the default: composer-2.5
# Exits 1 and prints an error if the input is unrecognized.

set -euo pipefail

input="${*:-}"

# Normalize: lowercase, collapse whitespace to hyphens, strip leading/trailing hyphens
normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -s ' \t' '-' | sed 's/^-*//;s/-*$//')

case "$normalized" in
  # Default / explicit Composer 2.5
  ""|"composer"|"composer-2"|"composer-2.5")
    echo "composer-2.5" ;;
  "composer-2.5-fast"|"composer-fast")
    echo "composer-2.5-fast" ;;

  # GPT-5.5 — default tier: high
  "gpt-5.5"|"gpt5.5"|"gpt-5-5")
    echo "gpt-5.5-high" ;;
  "gpt-5.5-low")          echo "gpt-5.5-low" ;;
  "gpt-5.5-medium")       echo "gpt-5.5-medium" ;;
  "gpt-5.5-high")         echo "gpt-5.5-high" ;;
  "gpt-5.5-extra-high"|"gpt-5.5-xhigh")
    echo "gpt-5.5-extra-high" ;;

  # GPT-5.4 — default tier: high
  "gpt-5.4"|"gpt5.4")    echo "gpt-5.4-high" ;;
  "gpt-5.4-low")         echo "gpt-5.4-low" ;;
  "gpt-5.4-medium")      echo "gpt-5.4-medium" ;;
  "gpt-5.4-high")        echo "gpt-5.4-high" ;;
  "gpt-5.4-xhigh"|"gpt-5.4-extra-high")
    echo "gpt-5.4-xhigh" ;;

  # GPT-5.2 — default tier: high
  "gpt-5.2"|"gpt5.2")    echo "gpt-5.2-high" ;;
  "gpt-5.2-high")        echo "gpt-5.2-high" ;;

  # Claude Opus 4.8 — default tier: high
  "opus-4.8"|"opus4.8"|"claude-opus-4-8"|"opus-4-8"|"opus")
    echo "claude-opus-4-8-high" ;;
  "opus-4.8-thinking"|"opus-4.8-think")
    echo "claude-opus-4-8-thinking-high" ;;

  # Claude Fable 5 — default tier: high (note: NO ZDR)
  "fable-5"|"fable5"|"claude-fable-5"|"fable")
    echo "claude-fable-5-high" ;;
  "fable-5-thinking"|"fable-5-think")
    echo "claude-fable-5-thinking-high" ;;

  # Claude Sonnet 4.6
  "sonnet-4.6"|"sonnet4.6"|"claude-4.6-sonnet"|"sonnet")
    echo "claude-4.6-sonnet-medium" ;;
  "sonnet-4.6-thinking"|"sonnet-4.6-think")
    echo "claude-4.6-sonnet-medium-thinking" ;;

  # Pass-through: if it already looks like a full model ID (contains at least one dot or two hyphens), trust it
  *"."*|*"-"*"-"*)
    echo "$normalized" ;;

  *)
    echo "ERROR: unrecognized model '${input}'. Run \`agent models\` to see valid IDs." >&2
    exit 1 ;;
esac
