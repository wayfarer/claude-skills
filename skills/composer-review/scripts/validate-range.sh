#!/usr/bin/env bash
# Validate a git revision range before launching the (slow) review agent, so a typo'd
# range fails fast in-session instead of after a multi-minute agent run.
# Exits 0 if the range is usable, 1 with an error message otherwise.
# Usage: validate-range.sh [workspace-path] [rev-range]
# With no range, defaults to HEAD~1..HEAD (the last commit).

set -euo pipefail

WORKSPACE="${1:-$(pwd)}"
RANGE="${2:-HEAD~1..HEAD}"

# Must be in a git repo with at least one commit.
if ! git -C "$WORKSPACE" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  echo "ERROR: no commits in '$WORKSPACE' to review." >&2
  exit 1
fi

# Root-commit carve-out: the default range references HEAD~1, which is absent on the
# repo's first commit. The plan harness substitutes the empty tree in that case, so
# treat the default range as valid here.
if [[ "$RANGE" == "HEAD~1..HEAD" ]] && ! git -C "$WORKSPACE" rev-parse -q --verify HEAD~1 >/dev/null 2>&1; then
  exit 0
fi

# Validate any other range/rev by asking git to enumerate it. rev-list errors on an
# unresolvable ref or malformed range; a valid-but-empty range (e.g. HEAD..HEAD) is fine.
if ! git -C "$WORKSPACE" rev-list "$RANGE" --max-count=1 -- >/dev/null 2>&1; then
  echo "ERROR: invalid git range '$RANGE'. Use a form like HEAD~1..HEAD or main..HEAD." >&2
  exit 1
fi
