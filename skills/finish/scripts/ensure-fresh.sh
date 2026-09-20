#!/usr/bin/env bash
# ensure-fresh.sh — Fetch base, check ancestry, rebase if behind.
#
# Usage: ensure-fresh.sh [--recheck]
#
# Fetches the base branch, checks whether HEAD contains the fetched base tip,
# and rebases if behind.  A successful rebase returns exit code 3 so the caller
# can distinguish "already fresh" (0) from "base moved, rebase performed" (3).
#
# Options:
#   --recheck  Recheck base freshness (for pre-publish verification).
#              Behaves identically to the initial check but signals to the
#              caller that this is a recheck after verification.
#
# Environment:
#   FRESHNESS_BASE  Base branch ref (default: origin/main).
#
# Exit codes:
#   0  Already fresh; no rebase was needed.
#   1  Rebase failed (conflicts must be resolved by the finish skill).
#   2  Fetch failed.
#   3  Rebase performed because the base had moved.

set -euo pipefail

base="${FRESHNESS_BASE:-origin/main}"
mode="${1:-initial}"

# Signal recheck mode to the git stub so it can use a different
# ancestry expectation (FRESH_RECHECK_IS_ANCESTOR vs FRESH_IS_ANCESTOR).
if [ "$mode" = "--recheck" ]; then
  export FRESHNESS_RECHECKING=1
fi

# Fetch the base branch tip.
git fetch origin "${base#origin/}" 2>/dev/null || exit 2

# Check whether HEAD contains the fetched base tip.
if git merge-base --is-ancestor "$base" HEAD 2>/dev/null; then
  # Already fresh — nothing to do.
  exit 0
fi

# HEAD is behind the base tip — rebase.
if ! git rebase "$base"; then
  printf 'Rebase failed; conflicts must be resolved before publication.\n' >&2
  exit 1
fi

printf 'rebased\n'
exit 3