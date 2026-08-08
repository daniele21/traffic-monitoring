# A0–A2 implementation status

This is the compact execution/status document for the first three phases in `local-first-observability-plan.md`.

Use it to review what is actually implemented without loading the full advanced-observability roadmap.

## A0 — Repository repositioning

Status: **implemented on `positioning/local-first-observability`**.

Completed:

- [x] Primary descriptor: `Local network observability for macOS`.
- [x] Ecosystem role: `Evidence & Observability`, not an AI runtime pillar.
- [x] README separates current capabilities from future advanced observability.
- [x] `docs/positioning.md` is the authority for public claims.
- [x] `docs/product-spec.md` describes current network-level evidence boundaries.
- [x] `AGENTS.md` prevents agents from claiming per-app/locality evidence prematurely.
- [x] `docs/README.md` provides progressive-disclosure routing.
- [x] Advanced evolution is separately gated in `local-first-observability-plan.md`.

Intentionally post-merge:

- [ ] Update GitHub repository description/topics after the positioning is accepted on `main` so repository metadata never advertises a branch-only state.

## A1 — Evidence-quality core

Status: **implemented; CI + real-Mac validation remain quality gates**.

Implemented domain semantics:

- [x] `EvidenceQuality`: `identified`, `partiallyIdentified`, `unknownNetwork`, `trackingDegraded`.
- [x] Explicit network identity quality.
- [x] Observation coverage summary with selected/observed/healthy/degraded/unobserved time.
- [x] Observation gaps lower evidence quality rather than being silently treated as complete history.

Implemented persistence:

- [x] `EvidenceCoverageEntity` in SwiftData.
- [x] Coverage is accumulated in memory and persisted with normal checkpoints rather than one write per sample.
- [x] Long sampling gaps are capped and left visible as unobserved time.
- [x] Coverage reads combine persisted and pending values.

Implemented product/UI:

- [x] Analytics evidence-quality strip.
- [x] Observed-coverage percentage and unobserved duration.
- [x] `About this data` explanation.
- [x] Unknown Wi-Fi remains explicit when SSID is unavailable.
- [x] Network aliases persist without changing canonical identity keys.
- [x] Network detail view with total/download/upload, identity quality, first/last observed, expensive/constrained metadata, peak interval, and trend.

Implemented tests:

- [x] Coverage reconciliation.
- [x] Quality precedence.
- [x] Unknown/identified Wi-Fi identity classification.
- [x] Long gaps are not falsely counted as observed.
- [x] Alias changes presentation while identity remains stable.

Still required before calling evidence quality release-grade:

- [ ] Real-Mac multi-hour/multi-network validation.
- [ ] Sleep/wake coverage validation.
- [ ] Force-kill/relaunch coverage validation.
- [ ] Validate evidence-quality presentation with SSID permission granted/denied.

## A2 — Reproducible export

Status: **implemented; export contract is schema v1**.

Implemented:

- [x] Versioned JSON export.
- [x] CSV export.
- [x] User-visible preview before save.
- [x] Local user-initiated save through macOS save panel.
- [x] Observation period.
- [x] Aggregate total/download/upload/network count.
- [x] Evidence quality and coverage.
- [x] Canonical network identity and presentation name/alias.
- [x] Connection kind.
- [x] Download/upload/total per network.
- [x] `isExpensive` and `isConstrained` metadata.
- [x] Network identity quality.
- [x] App version and schema version.
- [x] Explicit measurement-scope boundary.
- [x] Deterministic JSON round-trip/reconciliation tests.
- [x] CSV escaping/field tests.

Excluded by design:

- packet payloads;
- destinations;
- DNS/browsing history;
- BSSID;
- app/process identity;
- advanced-observability fields.

Authoritative schema documentation: `evidence-export.md`.

## Gate before B0

A0–A2 do **not** authorize implementation of source-app attribution or local-vs-external flow classification.

Before B0 begins:

1. latest macOS CI must be green;
2. A1 evidence semantics must be manually exercised on a Mac;
3. current network-level product must remain independently useful;
4. B0 must remain an isolated feasibility spike with no new public claims.
