---
name: grill-with-docs
description: Use when a design, plan, spec, or business idea must be stress-tested against the authoritative docs the calling workflow's role doc names — sharpens terminology and, when allowed, updates glossaries and decision records inline.
disable-model-invocation: true
---

Run a `/grilling` session about the artifact at hand.

## Target docs

The active role doc (under `docs/agents/`) names the authoritative docs for the
session: glossaries, decision records (ADRs), or business-context docs. In a
workflow session those docs are usually already loaded — do not re-read them.
If no role doc is loaded (standalone invocation), ask the user which docs are
authoritative before grilling. Do not guess the doc layout — the role doc is
the map.

## Doc updates

- **Engineering artifacts** (designs, plans, feature docs): additionally apply
  the `/domain-modeling` skill — challenge terms against the glossary and
  update glossaries and ADRs inline as decisions crystallise, following its
  formats.
- **Business ideas and other non-engineering artifacts**: run `/grilling`
  only; do not invoke `/domain-modeling`.
- **Owner-voice docs** (e.g. business-context docs): never edit them. The
  grilling output lands in the calling workflow's artifact (an issue, a spec, or
  the reasoned rejection).