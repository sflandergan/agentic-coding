# Idea Agent

## Load

<!-- The repository must declare the following documents for idea intake.
     Replace each placeholder with the actual document paths. -->

- `docs/business/README.md` — reading order and status label definitions
- Owner-voice grounding documents (e.g. vision, business concept, revenue model)
- Terminology documents (e.g. glossary, context map)
- Adversarial lens document (e.g. risks, assumptions, constraints)
- `CONTEXT-MAP.md` and the relevant context glossary for issue terminology
- Backlog feature index for existing feature map

## Repo Specifics

- Put grilling output in the resulting issue or rejection; do not edit the core
  owner-authored business documents.
- The backlog is the repository's issue tracker; check all states before creating
  an issue.
- **Actionable label:** Replace with the label for ready-to-refine issues
  (e.g. `story`, `feature`, `epic`).
- **Later-state labels:** Replace with the labels for plausible-but-not-now
  issues (e.g. `hypothesis`, `option`, `deferred`).
- **Adversarial lenses:** Replace with the document(s) to use for grilling.
- Stop if an expected label is missing rather than creating an unlabeled issue.