# Documentation map

The documentation is organized for progressive disclosure: start with the smallest document that answers the current task and follow links only when needed.

## Reading paths

### Implementing the next milestone

1. `../AGENTS.md`
2. `implementation-plan.md`
3. Only the technical document referenced by that milestone
4. `testing.md` for the relevant acceptance tests

### Validating M1 on a real Mac

1. `m1-validation.md`
2. `tracking-engine.md` only if a scenario behaves unexpectedly

### Changing tracking behavior

1. `../AGENTS.md`
2. `tracking-engine.md`
3. `data-and-analytics.md` only if persistence or attribution changes
4. `decisions.md` only when revisiting an architectural choice

### Changing the UI

1. `../AGENTS.md`
2. `ux.md`
3. `data-and-analytics.md` only for metrics/query semantics

### Reviewing product scope

1. `product-spec.md`
2. `architecture.md`

## Documents

- `product-spec.md` — user problem, v1 scope, non-goals, success criteria.
- `architecture.md` — components, dependency direction, runtime data flow.
- `tracking-engine.md` — interface enumeration, byte counters, network identity, transitions, VPN, sleep/wake.
- `m1-validation.md` — compact real-Mac checklist for the current measurement feasibility gate.
- `data-and-analytics.md` — SwiftData entities, buckets, sessions, retention, queries.
- `ux.md` — menu-bar and dashboard information architecture.
- `implementation-plan.md` — phased delivery plan with acceptance gates.
- `testing.md` — unit/integration/manual validation strategy.
- `decisions.md` — compact architectural decision log.

## Documentation rule

Avoid repeating detailed content across files. A document should link to the authoritative document for a concept rather than restating it. Keep root-level files concise so coding agents can orient with minimal context.
