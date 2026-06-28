#!/usr/bin/env bash
set -euo pipefail

# Publish the current branch and open a change request if needed.
bash core/agents/skills/git-publish/scripts/push-branch.sh --set-upstream
bash core/agents/skills/change-request-publish/scripts/open-change-request.sh --fill
