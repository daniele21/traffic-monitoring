# Documentation map

The documentation is organized for progressive disclosure: start with the smallest document that answers the current task and follow links only when needed.

## Reading paths

### Understanding the project positioning

1. `positioning.md`
2. `product-spec.md` only for current product scope
3. `local-first-observability-plan.md` only for future app/locality/audit evolution

### Running the app without Xcode

1. `run-without-xcode.md`
2. `m1-validation.md` only when validating measurement behavior

### Implementing the next core milestone

1. `../AGENTS.md`
2. `implementation-plan.md`
3. Only the technical document referenced by that milestone
4. `testing.md` for the relevant acceptance tests

### Planning advanced observability

1. `../AGENTS.md`
2. `positioning.md`
3. `local-first-observability-plan.md`
4. `architecture.md` only when an accepted feasibility decision changes boundaries
5. `decisions.md` when recording a platform choice

Do not begin per-app attribution or locality-classification implementation before the B0 feasibility gate in `local-first-observability-plan.md` is documented as accepted.

### Validating the current tracker on a real Mac

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
4. `positioning.md` if user-facing labels change the product claim

### Reviewing current product scope

1. `product-spec.md`
2. `positioning.md`
3. `architecture.md`

## Documents

### Strategy

- `positioning.md` — authoritative positioning, ecosystem role, audiences, messaging, claims, and evidence levels.
- `local-first-observability-plan.md` — detailed phased evolution from network-level analytics toward optional app attribution, locality evidence, audits, and developer tooling.

### Current product

- `product-spec.md` — user problem, current/v1 scope, non-goals, success criteria.
- `architecture.md` — current components, dependency direction, runtime data flow.
- `tracking-engine.md` — interface enumeration, byte counters, network identity, transitions, VPN, sleep/wake.
- `m1-validation.md` — compact real-Mac checklist for measurement feasibility/reliability.
- `run-without-xcode.md` — download and launch the CI-built `.app` on a Mac without full Xcode.
- `data-and-analytics.md` — SwiftData entities, buckets, local persistence, and analytics queries.
- `ux.md` — menu-bar and dashboard information architecture.
- `implementation-plan.md` — current lightweight product delivery plan with acceptance gates.
- `testing.md` — unit/integration/manual validation strategy.
- `decisions.md` — compact architectural decision log.

## Authority rule

When documents overlap:

- positioning/public claims → `positioning.md`;
- current feature scope → `product-spec.md`;
- current engineering execution → `implementation-plan.md`;
- future app/locality/audit evolution → `local-first-observability-plan.md`;
- technical behavior → the focused architecture/tracking/data document.

## Documentation rule

Avoid repeating detailed content across files. A document should link to the authoritative document for a concept rather than restating it. Keep root-level files concise so coding agents can orient with minimal context.