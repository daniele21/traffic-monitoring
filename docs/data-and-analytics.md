# Data and analytics

This document is authoritative for persisted entities, aggregation semantics, and dashboard query definitions.

## Goals

- Persist enough detail for useful daily/hourly/network analytics.
- Avoid writing a record every sampling tick.
- Keep byte accounting exact within accepted tracker deltas.
- Make common dashboard queries cheap.
- Preserve network aliases and attribution history across restarts.

## Current implementation status

Persistent local analytics are now enabled in the development branch.

The implemented write path is:

```text
validated traffic delta (~2 s sampling)
  → in-memory accumulation by network/interface
  → aligned 5-minute UsageBucket
  → SwiftData checkpoint approximately every 15 seconds
```

Current persistence uses:

- `NetworkProfileEntity` keyed by immutable network `identityKey`;
- `UsageBucketEntity` keyed by network identity + physical interface + 5-minute bucket start;
- `LocalUsageStore` as the UI/application-facing persistence boundary.

A normal periodic checkpoint updates/upserts the current bucket instead of inserting one row per sample. A network-identity boundary triggers an immediate flush, and the menu-bar Quit path performs a final best-effort flush before termination.

A hard crash can still lose the small interval accumulated since the last successful checkpoint. The current target is therefore **bounded loss of roughly the checkpoint interval**, not a claim of zero-loss crash persistence. Failed saves keep pending in-memory deltas available for retry rather than clearing them.

Analytics reads combine persisted buckets with the still-pending in-memory bucket so the dashboard can remain current without increasing write frequency.

Current dashboard queries support:

- Today;
- Last 7 days;
- Last 30 days;
- Current month;
- All time;
- Custom date range;
- summary totals;
- usage ranked by network;
- hourly/daily trend aggregation;
- trend for all networks or one selected network;
- highest-usage hour/day and largest individual network/time spike.

`ConnectionSessionEntity` is **not yet implemented**. Session duration/count, crash-recovery end reasons, and a dedicated network-detail session history remain part of the target v1 architecture below. Therefore the current implementation is a substantial persistence/analytics slice, not completion of the full M3/M5 acceptance gates.

## Storage technology

Use SwiftData for v1 with a schema designed around three concepts:

1. network profiles;
2. connection sessions;
3. bounded usage buckets.

Use `UInt64` in domain code for byte values. If SwiftData persistence requires a signed integer representation, validate conversion boundaries and store as `Int64` only after proving values fit; never silently truncate or use floating point for canonical byte totals.

The current implementation follows this rule: domain/aggregation models use `UInt64`; persisted bucket byte counters use guarded `Int64` conversion and reject overflow rather than truncating.

## Entity: NetworkProfile

Represents a recurring network identity.

Suggested fields:

```text
id: UUID
identityKey: String (unique)
kind: wifi | ethernet | usb | other
interfaceName: String
ssid: String?
displayAlias: String?
firstSeenAt: Date
lastSeenAt: Date
lastKnownExpensive: Bool
lastKnownConstrained: Bool
```

Display-name precedence:

1. user alias;
2. SSID;
3. derived wired label;
4. generic connection label.

Do not use mutable display names as primary keys.

Current `NetworkProfileEntity` stores the identity key, current display/network name, connection kind, interface name, first/last seen timestamps, and last known expensive/constrained metadata. User aliases are still pending.

## Entity: ConnectionSession

Represents one contiguous period in which a physical interface remains associated with one network identity.

Suggested fields:

```text
id: UUID
networkProfileID: UUID
interfaceName: String
startedAt: Date
endedAt: Date?
lastCheckpointAt: Date
rxBytes: Int64
txBytes: Int64
isExpensive: Bool
isConstrained: Bool
endReason: networkChange | disconnect | sleep | appQuit | crashRecovery | other
```

Session totals are useful for network-detail UX and reconciliation, but time-series charts should be driven by usage buckets.

This entity is still pending in the current implementation. Do not infer connected duration or session counts from usage buckets alone.

## Entity: UsageBucket

Represents traffic accumulated over a short bounded time interval.

Default target width: 5 minutes, but split early whenever the network identity changes, the interface disappears, the app sleeps, or another attribution boundary occurs.

Suggested fields:

```text
id: UUID
sessionID: UUID
networkProfileID: UUID
interfaceName: String
startedAt: Date
endedAt: Date
rxBytes: Int64
txBytes: Int64
isExpensive: Bool
isConstrained: Bool
```

A bucket belongs to exactly one network identity and one physical interface context.

The current `UsageBucketEntity` stores the immutable network identity key directly because the session layer is not yet present. Its unique bucket key combines network identity, interface name, and the aligned bucket start time. This representation must remain reconcilable when sessions/profile relationships are introduced later.

## Why both sessions and buckets

Sessions answer:

- how long was I connected?
- how many connection periods occurred?
- how much did this session use?

Buckets answer:

- how much was used per hour/day?
- what does the time-series chart show?
- how much fell inside an arbitrary date range?

Trying to derive arbitrary-period analytics only from long sessions would create inaccurate boundary allocations.

## Bucket lifecycle

The in-memory accumulator receives validated deltas from the tracker/measurement loop.

Close or flush the current bucket when any of these occurs:

- 5-minute time boundary;
- network profile changes;
- physical interface changes/disappears;
- sleep;
- app termination;
- explicit tracker reset.

Persist checkpoints while a bucket is still open so a crash loses only a small bounded amount of history.

A checkpoint updates the current stored row rather than appending a duplicate record.

Current implementation details:

- sampling remains approximately 2 seconds;
- persistence checkpoint target is approximately 15 seconds;
- buckets are aligned to 5-minute epoch boundaries;
- accepted deltas remain pending in memory until successfully saved;
- a network identity change forces a flush before subsequent attribution continues;
- normal menu-bar Quit flushes before app termination;
- the analytics read path includes both persisted and pending values without double-counting.

## Time semantics

Store timestamps as absolute `Date` values.

For analytics grouping, use the user's current Calendar/time zone at query/presentation time unless a future product requirement asks for historical-zone preservation.

Important cases:

- DST day may contain 23 or 25 hours;
- a bucket can cross midnight only if implementation fails to split on the configured bucket boundary; query logic must still clip correctly;
- custom-range summaries include only bucket overlap in the range.

Because 5-minute buckets can partially overlap an arbitrary start/end boundary, v1 may either:

1. include full overlapping buckets and document a maximum small boundary error; or
2. proportionally allocate a bucket by time.

Preferred v1: split common calendar boundaries during accumulation and use proportional allocation only for custom-range edge buckets. Canonical stored byte totals remain unchanged.

Current custom-range implementation includes whole overlapping buckets. Because buckets are only five minutes wide, this has a bounded edge error but still needs the planned clipping/proportional allocation work before the analytics milestone is considered complete.

## Analytics service contract

Target API surface:

```swift
protocol AnalyticsService {
    func summary(for period: DateInterval, filter: UsageFilter) async throws -> UsageSummary
    func timeSeries(for period: DateInterval, granularity: TimeGranularity, filter: UsageFilter) async throws -> [UsageTimePoint]
    func usageByNetwork(for period: DateInterval, filter: UsageFilter) async throws -> [NetworkUsageRow]
    func networkDetail(networkID: UUID, period: DateInterval) async throws -> NetworkDetailSummary
}
```

`UsageFilter` can include:

```text
network IDs
network kind
expensive only / exclude expensive / all
download / upload / total presentation mode
```

The canonical storage always keeps RX and TX separately.

The current implementation uses `HistoricalAnalyticsViewModel` plus the pure `UsageAnalyticsAggregator` over snapshots from `LocalUsageStore`. A dedicated long-lived `AnalyticsService` protocol remains a refactoring target once the persistence semantics are validated on real usage.

## Metric definitions

### Download

```text
SUM(rxBytes)
```

### Upload

```text
SUM(txBytes)
```

### Total

```text
SUM(rxBytes + txBytes)
```

### Network share

```text
networkTotal / allNetworkTotal
```

for the same selected period and filters.

### Peak period

For the currently selected period/filter:

```text
argmax(timeSeries.total)
```

Use hourly points for Today and daily points for longer built-in ranges. Product copy is `Highest usage hour` or `Highest usage day`, not a technical peak-rate label.

### Largest network spike

For the currently selected period/filter:

```text
argmax(networkTimeSeries.total)
```

This identifies the largest individual network/time bucket after hourly/daily aggregation. It is usage volume in an interval, not instantaneous throughput.

### Connected duration

Use session intervals clipped to the selected period. Avoid summing duration twice if concurrent physical interfaces are shown in an all-network total; duration is meaningful primarily in per-network detail.

### Session count

Count sessions that overlap the selected period, not only those that start inside it.

Connected duration/session count remain unavailable until `ConnectionSessionEntity` exists.

## Default time ranges

Provide reusable period builders for:

- Today;
- Last 7 days;
- Last 30 days;
- Current month;
- Previous month (optional in v1 UI);
- All time;
- Custom date range.

Avoid embedding date arithmetic directly in views.

Current `AnalyticsTimeframe` owns this period arithmetic. `Custom` normalizes From/To order and includes the full selected ending calendar day.

## Time-series granularity

Current policy:

- Today → hourly;
- 7D / 30D / Month / All time / Custom → daily.

A future refinement may switch very long custom/all-time ranges to weekly or monthly granularity for readability and query efficiency.

The aggregation layer returns semantic points; SwiftUI does not reaggregate raw 2-second samples.

## Network grouping

Dashboard rows group by network `identityKey`, then render the current display/network name.

Renaming a profile changes display only; historical records should continue to refer to the same identity.

If SSID was unavailable and later becomes available, do not automatically merge old `ssid-unavailable` data into a named network because the attribution cannot be proven. A future manual merge feature may be considered.

Current Wi-Fi identity remains based on interface + SSID when SSID is available. When permission is unavailable, traffic is safely grouped under the explicit unnamed Wi-Fi identity; it cannot later be retroactively assigned to a particular SSID.

## Expensive-network analytics

Store `isExpensive` on each bucket/session rather than only on the profile, because that path characteristic can change over time.

This enables queries such as:

```text
usage where isExpensive == true during current month
```

This is useful for likely mobile/hotspot consumption.

Current bucket storage retains `isExpensive` and `isConstrained`. The Networks UI can label such usage `Likely hotspot / expensive`, but `NWPath.isExpensive` remains a signal rather than proof of a phone hotspot.

## Concurrent interfaces

Byte totals across multiple physical interfaces are additive.

Example:

```text
Wi-Fi:    500 MB
Ethernet: 200 MB
Total:    700 MB
```

Do not attempt to deduplicate legitimate simultaneous physical traffic. Deduplication belongs earlier in the tracker by excluding virtual/tunnel layers.

## Reconciliation invariants

For any complete period and filter:

```text
summary.download == sum(timeSeries.download)
summary.upload   == sum(timeSeries.upload)
summary.total    == summary.download + summary.upload
sum(usageByNetwork.total) == summary.total
```

Allow only explicitly documented differences caused by custom-range partial-bucket allocation/rounding.

These invariants have deterministic aggregation tests. The local store also has a checkpoint test proving that a delta is counted once before and after moving from pending memory into SwiftData, preventing a common double-counting failure mode.

## Units and formatting

Canonical storage is bytes.

Formatting is presentation-only. Use one consistent convention in the UI and label it. Preferred initial convention: decimal network units (kB, MB, GB) because mobile plans are typically marketed in decimal GB.

Do not persist rounded MB/GB values.

## Retention

For v1, retain all local usage history.

The schema should allow later compaction, for example converting old 5-minute buckets into daily aggregates, but do not implement destructive compaction until real storage measurements justify it.

At 5-minute granularity the expected record volume is modest for a desktop app. The current design creates at most one row per active network/interface per 5-minute interval rather than one row every 2-second sample.

## Repository responsibilities

The persistence boundary should own:

- upsert/find `NetworkProfile` by identity key;
- open/update/close sessions;
- open/update/close buckets;
- stale-session recovery;
- date-range reads for analytics;
- alias updates;
- optional delete/reset history operation.

Views should not perform raw SwiftData fetches.

Current `LocalUsageStore` already owns profile/bucket upserts, checkpointing, pending-memory reconciliation, and date-range snapshot reads. Session lifecycle, alias updates, and reset-history operations remain pending.

## Crash recovery

Target full session-aware behavior at launch:

1. find sessions left open from the previous process;
2. close them at their `lastCheckpointAt`;
3. close any open bucket at its last checkpoint;
4. mark session end reason `crashRecovery`;
5. never bridge counters from that session to current counters.

The current bucket-only implementation is conservative in a simpler way: only successfully checkpointed deltas survive a hard process crash, and a relaunch starts measurement from fresh counter baselines. No bytes are invented for the unobserved gap. Full stale-session metadata recovery remains pending until sessions are implemented.

## Schema migration discipline

Before changing stored fields:

- document the semantic change;
- add/update migration strategy if persistent releases already exist;
- preserve byte totals and network-profile identity wherever possible;
- add fixture-based migration tests once the first public schema ships.
