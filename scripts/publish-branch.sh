#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper: this repo's self-maintenance agents still invoke
# scripts/publish-branch.sh. It delegates to the github-publish authored skill.
bash core/agents/skills/github-publish/scripts/push-branch.sh --set-upstream
bash core/agents/skills/github-publish/scripts/open-pr.sh --fill
