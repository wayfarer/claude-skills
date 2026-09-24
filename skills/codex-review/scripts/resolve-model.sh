#!/usr/bin/env bash
# Resolve a semantic model name to a canonical codex CLI model spec.
# Output is MODEL_ID or MODEL_ID:EFFORT (colon-separated when effort applies).
# Usage: resolve-model.sh [semantic-name]
# With no argument, prints the default: gpt-6-astra:medium
# Exits 1 and prints an error if the input is unrecognized.
#
# The alias table mirrors the catalog the installed CLI reports via
# `codex debug models` (Codex CLI 0.154.0, 2026-09-24). Hidden catalog entries
# (gpt-reserve, codex-auto-review) are deliberately not aliased.

set -euo pipefail

input="${*:-}"

# Normalize: lowercase, collapse whitespace to hyphens, strip leading/trailing hyphens
normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -s ' \t' '-' | sed 's/^-*//;s/-*$//')

case "$normalized" in
  # Default / GPT-6 Astra bare — medium effort
  ""|"astra"|"gpt-6"|"gpt6"|"gpt-6-astra"|"gpt6-astra")
    echo "gpt-6-astra:medium" ;;

  # GPT-6 Astra with explicit tier
  "astra-low"|"gpt-6-low"|"gpt6-low"|"gpt-6-astra-low")                 echo "gpt-6-astra:low" ;;
  "astra-medium"|"gpt-6-medium"|"gpt6-medium"|"gpt-6-astra-medium")     echo "gpt-6-astra:medium" ;;
  "astra-high"|"gpt-6-high"|"gpt6-high"|"gpt-6-astra-high")             echo "gpt-6-astra:high" ;;
  "astra-xhigh"|"astra-extra-high"|"gpt-6-xhigh"|"gpt-6-extra-high"|"gpt6-xhigh"|"gpt-6-astra-xhigh"|"gpt-6-astra-extra-high")
    echo "gpt-6-astra:xhigh" ;;
  "astra-max"|"gpt-6-max"|"gpt6-max"|"gpt-6-astra-max")                 echo "gpt-6-astra:max" ;;
  "astra-ultra"|"gpt-6-ultra"|"gpt6-ultra"|"gpt-6-astra-ultra")         echo "gpt-6-astra:ultra" ;;

  # GPT-5.6 Sol bare — medium effort
  "gpt-5.6"|"gpt5.6"|"gpt-5-6"|"sol"|"gpt-5.6-sol"|"gpt5.6-sol")
    echo "gpt-5.6-sol:medium" ;;

  # GPT-5.6 Sol with explicit tier
  "gpt-5.6-low"|"gpt5.6-low"|"sol-low"|"gpt-5.6-sol-low")             echo "gpt-5.6-sol:low" ;;
  "gpt-5.6-medium"|"gpt5.6-medium"|"sol-medium"|"gpt-5.6-sol-medium") echo "gpt-5.6-sol:medium" ;;
  "gpt-5.6-high"|"gpt5.6-high"|"sol-high"|"gpt-5.6-sol-high")         echo "gpt-5.6-sol:high" ;;
  "gpt-5.6-xhigh"|"gpt-5.6-extra-high"|"gpt5.6-xhigh"|"sol-xhigh"|"gpt-5.6-sol-xhigh"|"gpt-5.6-sol-extra-high")
    echo "gpt-5.6-sol:xhigh" ;;
  "gpt-5.6-max"|"gpt5.6-max"|"sol-max"|"gpt-5.6-sol-max")             echo "gpt-5.6-sol:max" ;;
  "gpt-5.6-ultra"|"gpt5.6-ultra"|"sol-ultra"|"gpt-5.6-sol-ultra")     echo "gpt-5.6-sol:ultra" ;;

  # GPT-5.6 Terra — medium effort
  "terra"|"gpt-5.6-terra"|"gpt5.6-terra")
    echo "gpt-5.6-terra:medium" ;;

  # GPT-5.6 Terra with explicit tier
  "terra-low"|"gpt-5.6-terra-low")          echo "gpt-5.6-terra:low" ;;
  "terra-medium"|"gpt-5.6-terra-medium")    echo "gpt-5.6-terra:medium" ;;
  "terra-high"|"gpt-5.6-terra-high")        echo "gpt-5.6-terra:high" ;;
  "terra-xhigh"|"terra-extra-high"|"gpt-5.6-terra-xhigh"|"gpt-5.6-terra-extra-high")
    echo "gpt-5.6-terra:xhigh" ;;
  "terra-max"|"gpt-5.6-terra-max")          echo "gpt-5.6-terra:max" ;;
  "terra-ultra"|"gpt-5.6-terra-ultra")      echo "gpt-5.6-terra:ultra" ;;

  # GPT-5.6 Luna — medium effort (no ultra tier in the catalog)
  "luna"|"gpt-5.6-luna"|"gpt5.6-luna")
    echo "gpt-5.6-luna:medium" ;;

  # GPT-5.6 Luna with explicit tier
  "luna-low"|"gpt-5.6-luna-low")            echo "gpt-5.6-luna:low" ;;
  "luna-medium"|"gpt-5.6-luna-medium")      echo "gpt-5.6-luna:medium" ;;
  "luna-high"|"gpt-5.6-luna-high")          echo "gpt-5.6-luna:high" ;;
  "luna-xhigh"|"luna-extra-high"|"gpt-5.6-luna-xhigh"|"gpt-5.6-luna-extra-high")
    echo "gpt-5.6-luna:xhigh" ;;
  "luna-max"|"gpt-5.6-luna-max")            echo "gpt-5.6-luna:max" ;;

  # GPT-5.5 (legacy) bare — medium effort
  "gpt-5.5"|"gpt5.5"|"gpt-5-5")
    echo "gpt-5.5:medium" ;;

  # GPT-5.5 with explicit tier (low..xhigh only)
  "gpt-5.5-low"|"gpt5.5-low")             echo "gpt-5.5:low" ;;
  "gpt-5.5-medium"|"gpt5.5-medium")       echo "gpt-5.5:medium" ;;
  "gpt-5.5-high"|"gpt5.5-high")           echo "gpt-5.5:high" ;;
  "gpt-5.5-xhigh"|"gpt-5.5-extra-high"|"gpt5.5-xhigh")
    echo "gpt-5.5:xhigh" ;;

  # Pass-through: already looks like a full model ID or model:effort spec — trust it,
  # but warn on stderr so typos surface (stdout must stay exactly the resolved spec).
  *"."*|*"-"*"-"*|*":"*)
    echo "WARNING: '${input}' is not a known alias; passing through verbatim." >&2
    echo "$normalized" ;;

  *)
    echo "ERROR: unrecognized model '${input}'. Known aliases: astra / gpt-6 [low|medium|high|xhigh|max|ultra], gpt-5.6 / sol / terra [low|medium|high|xhigh|max|ultra], luna [low|medium|high|xhigh|max], gpt-5.5 [low|medium|high|xhigh]. Run 'codex debug models' to see the live catalog." >&2
    exit 1 ;;
esac
