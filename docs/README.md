# Documentation map

The documentation is organized for progressive disclosure: start with the smallest document that answers the current task and follow links only when needed.

## Reading paths

### Understanding the project positioning

1. `positioning.md`
2. `product-spec.md` only for current product scope
3. `local-first-observability-plan.md` only for future app/locality/audit evolution

### Reviewing A0–A2 status

1. `a0-a2-implementation-status.md`
2. `positioning.md` only if public claims are involved
3. `data-and-analytics.md` for persistence/coverage semantics
4. `evidence-export.md` for JSON/CSV schema work

### Reviewing UX/UI through Phase 4

1. `phase-1-4-implementation-status.md` — compact status of the branded UX overhaul, analytics refinement, Applications cleanup and non-privileged preview.
2. `ux.md` — authoritative product information architecture.
3. `non-privileged-app-activity.md` — authoritative App Activity Preview evidence boundary.
4. `brand.md` — visual identity rules.

### Reviewing Applications Beta

Applications now has two intentionally separate capability levels:

1. `non-privileged-app-activity.md` — App Activity Preview using the local macOS process summary; no Apple Developer Program required and no locality/privacy claim.
2. `b0-b2-implementation-status.md` — signed Advanced Provider implementation and remaining runtime gates.
3. `advanced-observability-feasibility.md` — macOS platform/entitlement architecture for the signed provider only.
4. `testing.md` — acceptance matrix before Advanced Provider evidence becomes authoritative.

Never use App Activity Preview rows to fill Advanced Provider gaps or to support `local-only` / privacy claims.

### Reviewing B0–B2 Advanced Observability

1. `b0-b2-implementation-status.md`
2. `advanced-observability-feasibility.md` for the current macOS platform result
3. `adr/0001-advanced-observability-content-filter.md` only when revisiting the architecture decision
4. `local-first-observability-plan.md` for the broader roadmap

B0 is **GO for a signed real-Mac prototype**, not production acceptance. The provider → app XPC path, client code-signature authentication, audit-token identity path, locality classification, statistics aggregation, runtime diagnostics and Applications UI compile in CI. No agent may present per-app Advanced Provider evidence as release-validated until signed activation, controlled-transfer reconciliation, coverage and performance gates pass.

### Running the app without Xcode

1. `run-without-xcode.md`
2. `m1-validation.md` only when validating measurement behavior

### Running signed Advanced Observability validation

1. `advanced-observability-signed-runbook.md` for operational build/activation/preflight steps
2. `testing.md` for the authoritative B1/B2 acceptance matrix
3. `b0-b2-implementation-status.md` when recording what actually passed
4. `advanced-observability-feasibility.md` only if the platform architecture itself behaves differently than expected

### Implementing the next core milestone

1. `../AGENTS.md`
2. `implementation-plan.md`
3. Only the technical document referenced by that milestone
4. `testing.md` for the relevant acceptance tests

### Planning advanced observability

1. `../AGENTS.md`
2. `non-privileged-app-activity.md` if changing the no-entitlement preview
3. `b0-b2-implementation-status.md` if changing the signed provider
4. `advanced-observability-feasibility.md`
5. `positioning.md` only if claims are changing
6. `local-first-observability-plan.md` only for the broader staged roadmap

### Changing evidence quality / coverage

1. `../AGENTS.md`
2. `data-and-analytics.md`
3. `a0-a2-implementation-status.md`
4. `testing.md`

### Changing evidence export

1. `../AGENTS.md`
2. `evidence-export.md`
3. `data-and-analytics.md` only if underlying metrics change
4. `positioning.md` only if the export changes the claim boundary

### Validating the current tracker on a real Mac

1. `m1-validation.md`
2. `tracking-engine.md` only if a scenario behaves unexpectedly

### Changing tracking behavior

1. `../AGENTS.md`
2. `tracking-engine.md`
3. `data-and-analytics.md` only if persistence or attribution changes
4. `decisions.md` only when revisiting an architectural choice

### Changing the UI / brand

1. `../AGENTS.md`
2. `phase-1-4-implementation-status.md` for current implementation state
3. `brand.md` for visual identity
4. `ux.md` for information architecture and capability presentation
5. `non-privileged-app-activity.md` when changing Applications Preview semantics
6. `data-and-analytics.md` only for metrics/query semantics
7. `positioning.md` if user-facing labels change the product claim

### Reviewing current product scope

1. `product-spec.md`
2. `positioning.md`
3. `architecture.md`

## Documents

### Strategy

- `positioning.md` — authoritative positioning, ecosystem role, audiences, messaging, claims, and evidence levels.
- `local-first-observability-plan.md` — detailed phased evolution from network-level analytics toward optional app attribution, locality evidence, audits, and developer tooling.
- `a0-a2-implementation-status.md` — compact implementation/status view for repository positioning, evidence quality, and export.
- `phase-1-4-implementation-status.md` — compact current status of UX/UI overhaul through the non-privileged Phase 4 preview.
- `b0-b2-implementation-status.md` — compact current status of signed Advanced Observability implementation and remaining validation gates.
- `advanced-observability-feasibility.md` — B0 macOS feasibility result, prototype architecture, signing/distribution and evidence-source constraints.
- `advanced-observability-signed-runbook.md` — operational preflight, activation, runtime diagnostics, controlled validation and cleanup for the signed B1/B2 prototype.
- `non-privileged-app-activity.md` — Phase 4 best-effort process activity preview, source contract, privacy boundary and acceptance criteria.
- `adr/0001-advanced-observability-content-filter.md` — accepted architecture for signed prototype validation; production acceptance remains gated.
- `brand.md` — approved visual identity, palette, typography, product language, and chart styling.

### Current product

- `product-spec.md` — user problem, current/v1 scope, non-goals, success criteria.
- `architecture.md` — current components, dependency direction, runtime data flow.
- `tracking-engine.md` — interface enumeration, byte counters, network identity, transitions, VPN, sleep/wake.
- `m1-validation.md` — compact real-Mac checklist for measurement feasibility/reliability.
- `run-without-xcode.md` — download and launch the CI-built `.app` on a Mac without full Xcode.
- `data-and-analytics.md` — SwiftData entities, buckets, evidence coverage, local persistence, and analytics queries.
- `evidence-export.md` — versioned JSON/CSV network-evidence export contract and privacy boundary.
- `ux.md` — sidebar, analytics, Applications Beta, menu-bar and Settings information architecture.
- `implementation-plan.md` — current lightweight product delivery plan with acceptance gates.
- `testing.md` — unit/integration/manual validation strategy, including the signed B1/B2 matrix.
- `decisions.md` — compact architectural decision log.

## Authority rule

When documents overlap:

- positioning/public claims → `positioning.md`;
- current feature scope → `product-spec.md`;
- current engineering execution → `implementation-plan.md`;
- A0–A2 implementation status → `a0-a2-implementation-status.md`;
- UX/UI Phase 1–4 status → `phase-1-4-implementation-status.md`;
- signed B0–B2 current status → `b0-b2-implementation-status.md`;
- non-privileged process preview → `non-privileged-app-activity.md`;
- B0 platform feasibility → `advanced-observability-feasibility.md`;
- signed B1/B2 operational procedure → `advanced-observability-signed-runbook.md`;
- B1/B2 acceptance matrix → `testing.md`;
- export schema → `evidence-export.md`;
- future app/locality/audit evolution → `local-first-observability-plan.md`;
- visual identity → `brand.md`;
- product information architecture → `ux.md`;
- technical behavior → the focused architecture/tracking/data document.

## Documentation rule

Avoid repeating detailed content across files. A document should link to the authoritative document for a concept rather than restating it. Keep root-level files concise so coding agents can orient with minimal context.
