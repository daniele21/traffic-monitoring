# Evidence export

This document is authoritative for the **current network-level evidence export** introduced in A2.

Read `positioning.md` first if you are changing claims. Read `data-and-analytics.md` if you are changing persisted metrics.

## Purpose

Traffic Monitoring can export the same aggregate evidence that powers the selected Analytics period so a user can:

- inspect the exact fields before saving;
- reproduce dashboard totals outside the app;
- attach a compact evidence file to testing notes or documentation;
- keep export explicitly user-controlled and local.

Export does **not** broaden collection. It serializes already-available network-level aggregates and coverage metadata.

## Formats

Current formats:

- JSON — structured, schema-versioned evidence document;
- CSV — one row per detected network for spreadsheet/tooling workflows.

The user previews the export before choosing a local destination with the macOS save panel.

## Schema version

Current JSON/CSV schema version:

```text
1
```

A breaking semantic or field-contract change must increment the schema version and update deterministic tests.

## JSON contract

Top-level fields:

```text
schemaVersion
generatedAt
appVersion
measurementScope
periodStart
periodEnd
totals
coverage
networks[]
```

### Totals

```text
downloadedBytes
uploadedBytes
totalBytes
networkCount
```

`totalBytes` must reconcile with the sum of every exported network row for the same document.

### Coverage

```text
quality
selectedSeconds
observedSeconds
healthySeconds
metadataDegradedSeconds
trackingDegradedSeconds
unknownNetworkSeconds
unobservedSeconds
```

Coverage describes **how complete the observation was**, not only how much traffic was measured.

### Network row

```text
identityKey
displayName
connectionKind
downloadedBytes
uploadedBytes
totalBytes
isExpensive
isConstrained
identityQuality
firstObservedAt
lastObservedAt
```

`displayName` may be a user alias. `identityKey` remains the canonical immutable grouping key.

## CSV contract

CSV carries the same core evidence in a flat one-row-per-network representation.

Current columns:

```text
schema_version
period_start
period_end
app_version
evidence_quality
observed_seconds
selected_seconds
network_identity
network_name
connection_kind
identity_quality
downloaded_bytes
uploaded_bytes
total_bytes
is_expensive
is_constrained
first_observed_at
last_observed_at
```

Names containing commas, quotes, or newlines must be RFC-style CSV quoted by doubling inner quotes.

## Measurement boundary

Every export embeds a measurement-scope statement equivalent to:

> Physical network-interface usage observed by Traffic Monitoring. Totals can include local-network traffic and are not exact ISP/carrier billing data.

Do not remove or weaken this boundary unless the underlying evidence source changes.

## Privacy boundary

A2 export includes aggregate network evidence only.

It must not include by default:

- packet payloads;
- request/response bodies;
- browsing content;
- remote destinations;
- DNS history;
- BSSID;
- unrelated device identifiers;
- process/application identity.

Future advanced-observability exports require their own schema and privacy review. Do not silently add advanced fields to schema v1.

## Reconciliation invariants

For one export document:

```text
export.totals.downloadedBytes == SUM(network.downloadedBytes)
export.totals.uploadedBytes   == SUM(network.uploadedBytes)
export.totals.totalBytes      == SUM(network.totalBytes)
export.totals.totalBytes      == downloadedBytes + uploadedBytes
```

The selected period and coverage values must match the Analytics state used to create the export.

## Current implementation

Domain:

- `EvidenceExportDocument`
- `EvidenceExportCoverage`
- `EvidenceExportNetwork`
- `EvidenceExportTotals`

Service:

- `EvidenceExportService`

UI:

- `EvidenceExportPreviewView`

Tests:

- `EvidenceExportServiceTests`

## Change rule

When changing export:

1. decide whether the change is additive or breaking;
2. update this document;
3. update schema version when semantics break compatibility;
4. update JSON round-trip and CSV fixture tests;
5. confirm dashboard/export totals still reconcile;
6. confirm no new sensitive field was introduced without product/privacy review.
