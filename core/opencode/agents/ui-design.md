---
description: Produces approved presentation code and a final handoff for features that add or materially change a user interface.
mode: all
temperature: 0.7
permission:
  edit: allow
  question: allow
  bash:
    "test -x node_modules/.bin/*": allow

    "bash .agents/scripts/ui-design/preview.sh start": allow
    "bash .agents/scripts/ui-design/preview.sh probe": allow
    "bash .agents/scripts/ui-design/preview.sh stop": allow
    "npx playwright screenshot *": allow
    "npx playwright test *": deny

    "node .agents/skills/impeccable/scripts/context.mjs *": allow
    "node .agents/skills/impeccable/scripts/detect.mjs *": allow
    "node .agents/skills/impeccable/scripts/critique-storage.mjs *": allow
    "node .agents/skills/impeccable/scripts/live-server.mjs *": allow

    "git diff *": allow
    "git grep *": allow
    "git log *": allow
    "git show *": allow
    "git status *": allow
    "git branch": allow
    "git branch *": allow
    "git merge-base *": allow
    "git rev-parse *": allow
    "git ls-files *": allow

    "git add *": allow
    "git commit *": allow
    "git checkout *": allow
    "git mv *": allow
    "git rm *": allow
    "git pull *": allow
    "git pull": allow
    "git reset --soft *": allow
    "git reset --mixed *": allow

    "cat *": allow
    "ls *": allow
    "ls": allow
    "find *": allow
    "grep *": allow
    "head *": allow
    "tail *": allow
    "rg *": allow
    "jq *": allow
    "wc *": allow
    "sort *": allow
    "diff *": allow
    "file *": allow
    "stat *": allow
    "tr *": allow
    "cut *": allow
    "uniq *": allow
    "paste *": allow
    "cp *": allow
    "echo *": allow
    "pwd": allow
    "date *": allow
    "which *": allow
    "mkdir *": allow
    "touch *": allow

    "git push": deny
    "git push*": deny
    "git push * --force-with-lease *": ask
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny
    "*>*": ask
    "*<*": ask
    "echo * >*": deny

    "curl \"http://localhost:*\"": allow
    "curl \"http://127.0.0.1:*\"": allow
    "curl \"http://[::1]:*\"": allow
    "curl \"https://localhost:*\"": allow
    "curl \"https://127.0.0.1:*\"": allow
    "curl \"https://[::1]:*\"": allow
    "curl -s \"http://localhost:*\"": allow
    "curl -s \"http://127.0.0.1:*\"": allow
    "curl -s \"http://[::1]:*\"": allow
    "curl -s \"https://localhost:*\"": allow
    "curl -s \"https://127.0.0.1:*\"": allow
    "curl -s \"https://[::1]:*\"": allow
    "curl -fsS \"http://localhost:*\"": allow
    "curl -fsS \"http://127.0.0.1:*\"": allow
    "curl -fsS \"http://[::1]:*\"": allow
    "curl -fsS \"https://localhost:*\"": allow
    "curl -fsS \"https://127.0.0.1:*\"": allow
    "curl -fsS \"https://[::1]:*\"": allow
    "curl --fail --silent --show-error http://localhost:*": allow
    "curl --fail --silent --show-error http://127.0.0.1:*": allow
    "curl --fail --silent --show-error http://[::1]:*": allow
    "curl --fail --silent --show-error https://localhost:*": allow
    "curl --fail --silent --show-error https://127.0.0.1:*": allow
    "curl --fail --silent --show-error https://[::1]:*": allow
    "curl -I \"http://localhost:*\"": allow
    "curl -I \"http://127.0.0.1:*\"": allow
    "curl -I \"http://[::1]:*\"": allow
    "curl -I \"https://localhost:*\"": allow
    "curl -I \"https://127.0.0.1:*\"": allow
    "curl -I \"https://[::1]:*\"": allow
    "curl -Is \"http://localhost:*\"": allow
    "curl -Is \"http://127.0.0.1:*\"": allow
    "curl -Is \"http://[::1]:*\"": allow
    "curl -Is \"https://localhost:*\"": allow
    "curl -Is \"https://127.0.0.1:*\"": allow
    "curl -Is \"https://[::1]:*\"": allow

    "curl *>*": ask
    "curl *<*": ask
    "curl * -d *": ask
    "curl * --data *": ask
    "curl * --data-raw *": ask
    "curl * --data-binary *": ask
    "curl * --data-urlencode *": ask
    "curl * -F *": ask
    "curl * --form *": ask
    "curl * -T *": ask
    "curl * --upload-file *": ask
    "curl * -X POST *": ask
    "curl * -X PUT *": ask
    "curl * -X PATCH *": ask
    "curl * -X DELETE *": ask
    "curl * -K *": ask
    "curl * -o *": ask
    "curl * --output *": ask

    "curl \"http://localhost:*\" >/dev/null": allow
    "curl \"http://127.0.0.1:*\" >/dev/null": allow
    "curl \"http://[::1]:*\" >/dev/null": allow
    "curl \"https://localhost:*\" >/dev/null": allow
    "curl \"https://127.0.0.1:*\" >/dev/null": allow
    "curl \"https://[::1]:*\" >/dev/null": allow
    "curl -s \"http://localhost:*\" >/dev/null": allow
    "curl -s \"http://127.0.0.1:*\" >/dev/null": allow
    "curl -s \"http://[::1]:*\" >/dev/null": allow
    "curl -s \"https://localhost:*\" >/dev/null": allow
    "curl -s \"https://127.0.0.1:*\" >/dev/null": allow
    "curl -s \"https://[::1]:*\" >/dev/null": allow
    "curl -fsS \"http://localhost:*\" >/dev/null": allow
    "curl -fsS \"http://127.0.0.1:*\" >/dev/null": allow
    "curl -fsS \"http://[::1]:*\" >/dev/null": allow
    "curl -fsS \"https://localhost:*\" >/dev/null": allow
    "curl -fsS \"https://[::1]:*\" >/dev/null": allow
    "curl -I \"http://localhost:*\" >/dev/null": allow
    "curl -I \"http://127.0.0.1:*\" >/dev/null": allow
    "curl -I \"http://[::1]:*\" >/dev/null": allow
    "curl -I \"https://localhost:*\" >/dev/null": allow
    "curl -I \"https://127.0.0.1:*\" >/dev/null": allow
    "curl -I \"https://[::1]:*\" >/dev/null": allow
    "curl -s -o /dev/null \"http://localhost:*\"": allow
    "curl -s -o /dev/null \"http://127.0.0.1:*\"": allow
    "curl -s -o /dev/null \"http://[::1]:*\"": allow
    "curl -s -o /dev/null \"https://localhost:*\"": allow
    "curl -s -o /dev/null \"https://127.0.0.1:*\"": allow
    "curl -s -o /dev/null \"https://[::1]:*\"": allow
  task:
    "*": deny
    "explore": allow
    "ui-design-task": allow
  skill:
    "*": deny
    "ui-design": allow
    "ui-design-task": allow
    "impeccable": allow
---

You are the ui-design agent for this repository.
Invoke the `/ui-design` skill and follow it exactly.