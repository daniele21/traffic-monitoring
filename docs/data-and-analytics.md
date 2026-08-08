# Data and analytics

This document is authoritative for current persisted entities, aggregation semantics, evidence coverage, and dashboard query definitions.

For export serialization, read `evidence-export.md`. For public claims, read `positioning.md`.

## Goals

- Keep byte accounting exact within accepted tracker deltas.
- Persist useful hourly/daily/network history without one row per sample.
- Preserve immutable network identities while allowing friendly aliases.
- Distinguish **usage totals** from **observation coverage**.
- Keep observation gaps and degraded metadata explicit.
- Make dashboard/export totals reconcile from the same evidence source.

## Current write path

```text
physical interface counters (~2 s)
        │
        ├── validated traffic delta
        └── observation heartbeat
                 │
                 ▼
       in-memory accumulation
                 │
        ┌────────┴────────┐
        ▼                 ▼
  UsageBucket       CoverageBucket
  5-minute          5-minute
        └────────┬────────┘
                 │
          ~15 s checkpoint
                 │
                 ▼
           SwiftData local
```

Sampling and persistence cadences remain deliberately separate.

## Current SwiftData entities

### NetworkProfileEntity

Purpose: recurring canonical network identity plus presentation metadata.

Current fields conceptually include:

```text
identityKey            unique immutable grouping key
networkName            last observed system/derived name
displayAlias?          user-controlled presentation override
connectionKind
interfaceName
firstSeenAt
lastSeenAt
lastKnownExpensive
lastKnownConstrained
```

Display precedence:

```text
user alias
  ↓
observed network name / SSID
  ↓
derived wired label
  ↓
generic label
```

An alias must never rewrite `identityKey` or merge historical identities.

### UsageBucketEntity

Purpose: canonical traffic totals for one network/interface context in an aligned short interval.

Current fields:

```text
bucketKey              unique
identityKey
networkName
connectionKind
interfaceName
startedAt
endedAt
downloadedBytes        persisted guarded Int64
uploadedBytes          persisted guarded Int64
isExpensive
isConstrained
lastObservedAt
```

Domain byte values remain `UInt64`. Persistence uses guarded `Int64` conversion and rejects overflow rather than truncating.

### EvidenceCoverageEntity

Purpose: describe how much time the tracker was actually observing and whether that observation was healthy/fully identified.

Current fields:

```text
bucketKey              unique 5-minute coverage bucket
startedAt
endedAt
activeSeconds
healthySeconds
metadataDegradedSeconds
trackingDegradedSeconds
unknownNetworkSeconds
lastObservedAt
```

Coverage is not a traffic sample and does not store network payload/content.

## Pending in-memory state

`LocalUsageStore` keeps unsaved traffic and coverage in memory until checkpoint.

Analytics reads combine persisted + pending state so the UI remains current without increasing write frequency.

A successful flush:

1. upserts network profiles;
2. upserts traffic buckets;
3. upserts coverage buckets;
4. saves once;
5. clears only successfully persisted pending values.

Failed persistence keeps pending state available for retry.

## Coverage semantics

### Why coverage exists

If Analytics selects 8 hours but Traffic Monitoring only ran for 90 minutes, a total of `2 GB` must not imply that all 8 hours were observed.

Coverage therefore answers:

> How much of this selected period was actually observed, and with what evidence quality?

### Heartbeat aggregation

The tracking loop records a coverage heartbeat while it is running.

Coverage is accumulated in memory and saved with normal checkpoints. It does **not** create one SwiftData row every ~2 seconds.

### Long gaps

A long interval between two samples may mean:

- sleep;
- app termination;
- crash;
- scheduler suspension;
- unavailable counters.

The store caps the amount of one interval that can be counted as continuously observed. The remaining time stays **unobserved**.

Current default cap:

```text
maximumContinuousObservationGap = 10 seconds
```

This is conservative by design: prefer incomplete evidence over invented coverage.

## Evidence quality

Current states:

```text
identified
partiallyIdentified
unknownNetwork
trackingDegraded
```

Current precedence:

1. tracking error/persistence problem → `trackingDegraded`;
2. unknown Wi-Fi/network identity → `unknownNetwork`;
3. weaker metadata identity or observation gap → `partiallyIdentified`;
4. otherwise → `identified`.

The evidence-quality state complements, rather than replaces, the numeric coverage values.

### Network identity quality

Current examples:

- named Wi-Fi via SSID → `identified`;
- Wi-Fi with `ssid-unavailable` → `unknownNetwork`;
- wired fallback such as `wired:enX:unknown-network` → `partiallyIdentified` when it contributes traffic;
- other generic physical identity → `partiallyIdentified` when it contributes traffic.

A zero-byte fallback interface does not by itself lower evidence quality for the whole period.

## Usage aggregation

Canonical metrics:

```text
download = SUM(downloadedBytes)
upload   = SUM(uploadedBytes)
total    = download + upload
```

### Network share

```text
networkTotal / allNetworkTotal
```

for the same selected period.

### Trend

Current granularity:

```text
Today                              hourly
7 days / 30 days / Month / All     daily
Custom                             daily
```

### Peak

```text
argmax(timeSeries.totalBytes)
```

Product labels are `Highest usage hour` or `Highest usage day`; this is interval volume, not instantaneous throughput.

### Largest network spike

```text
argmax(networkTimeSeries.totalBytes)
```

## Supported timeframes

Current `AnalyticsTimeframe` supports:

- Today;
- 7 days;
- 30 days;
- This month;
- All time;
- Custom.

For custom ranges the current usage query includes whole overlapping five-minute buckets. This creates a bounded edge error at arbitrary range boundaries and remains a future clipping refinement.

## Network aliases

Aliases are persisted on `NetworkProfileEntity`.

Rules:

- blank alias removes the override;
- alias changes presentation only;
- canonical identity remains unchanged;
- all historical usage for the identity displays the current alias;
- aliasing an unknown Wi-Fi identity does not retroactively prove which SSID produced that history.

## Network detail

The current detail view derives from selected-period snapshots and shows:

- total/download/upload;
- highest usage hour/day;
- trend;
- first/last observed;
- identity quality;
- connection kind;
- `isExpensive`;
- `isConstrained`;
- alias editor.

Connection-session count/duration remains unavailable until a dedicated session entity is implemented. Do not infer connected duration from usage buckets.

## Expensive / constrained metadata

These are stored on usage buckets because they describe the observed path at the time of traffic.

`isExpensive` may be useful for likely hotspot/mobile contexts, but it is not proof of a phone hotspot.

`isConstrained` is exported and shown in network detail when observed.

## Export data source

A2 JSON/CSV export uses the same selected-period snapshots, aggregator, network rows, and coverage summary as Analytics.

This creates the invariant:

```text
Analytics totals == export totals
```

Export schema details live in `evidence-export.md`.

## Reconciliation invariants

For a complete query result:

```text
summary.downloadedBytes == SUM(networkRows.downloadedBytes)
summary.uploadedBytes   == SUM(networkRows.uploadedBytes)
summary.totalBytes      == SUM(networkRows.totalBytes)
summary.totalBytes      == SUM(timeSeries.totalBytes)
```

For export:

```text
export.totals.totalBytes == SUM(export.networks.totalBytes)
```

For coverage:

```text
unobservedSeconds = MAX(0, selectedSeconds - observedSeconds)
observedRatio     = observedSeconds / selectedSeconds
```

Tests also verify that moving a pending usage/coverage bucket through a checkpoint does not double count it.

## Crash / relaunch semantics

Traffic already persisted before a hard crash survives. Pending traffic since the last successful checkpoint may be lost.

On relaunch:

- counter baselines start fresh;
- no bytes are invented across the process gap;
- the gap remains unobserved in coverage;
- previous persisted history remains queryable.

Full session-aware crash end reasons remain future work.

## Privacy boundary

Current persistence does not store:

- packet payloads;
- destinations;
- DNS history;
- browsing content;
- BSSID;
- source process/application identity.

Coverage stores durations/status only.

## Storage growth

The design creates at most roughly one usage row per active network/interface per five-minute interval plus one low-frequency coverage row per five-minute interval, rather than hundreds of raw samples.

Do not implement destructive compaction until real long-running storage measurements justify it.

## Change rules

When changing usage, coverage, identity, or persistence semantics:

1. update domain/persistence tests;
2. preserve byte reconciliation;
3. preserve explicit unknown/gap states;
4. avoid new high-frequency rows;
5. update this document;
6. update `evidence-export.md` if exported semantics change;
7. do not broaden product claims beyond `positioning.md`.
