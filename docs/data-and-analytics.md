# Data and analytics

This document is authoritative for persisted entities, aggregation semantics, and dashboard query definitions.

## Goals

- Persist enough detail for useful daily/hourly/network analytics.
- Avoid writing a record every sampling tick.
- Keep byte accounting exact within accepted tracker deltas.
- Make common dashboard queries cheap.
- Preserve network aliases and attribution history across restarts.

## Storage technology

Use SwiftData for v1 with a schema designed around three concepts:

1. network profiles;
2. connection sessions;
3. bounded usage buckets.

Use `UInt64` in domain code for byte values. If SwiftData persistence requires a signed integer representation, validate conversion boundaries and store as `Int64` only after proving values fit; never silently truncate or use floating point for canonical byte totals.

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

The in-memory accumulator receives validated deltas from `TrafficTracker`.

Close the current bucket when any of these occurs:

- 5-minute time boundary;
- network profile changes;
- physical interface changes/disappears;
- sleep;
- app termination;
- explicit tracker reset.

Persist checkpoints while a bucket is still open so a crash loses only a small bounded amount of history.

A checkpoint updates the current stored row rather than appending a duplicate record.

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

## Analytics service contract

Suggested API surface:

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

### Connected duration

Use session intervals clipped to the selected period. Avoid summing duration twice if concurrent physical interfaces are shown in an all-network total; duration is meaningful primarily in per-network detail.

### Session count

Count sessions that overlap the selected period, not only those that start inside it.

## Default time ranges

Provide reusable period builders for:

- Today;
- Last 7 days;
- Last 30 days;
- Current month;
- Previous month (optional in v1 UI);
- Custom date range.

Avoid embedding date arithmetic directly in views.

## Time-series granularity

Suggested automatic policy:

- Today → hourly;
- 7D / 30D / Month → daily;
- long custom ranges → weekly or monthly when necessary.

The service should return semantic points; the view should not reaggregate raw buckets.

## Network grouping

Dashboard rows group by `NetworkProfile.identityKey`, then render the current alias/display name.

Renaming a profile changes display only; historical records continue to refer to the same profile ID.

If SSID was unavailable and later becomes available, do not automatically merge old `ssid-unavailable` data into a named network because the attribution cannot be proven. A future manual merge feature may be considered.

## Expensive-network analytics

Store `isExpensive` on each bucket/session rather than only on the profile, because that path characteristic can change over time.

This enables queries such as:

```text
usage where isExpensive == true during current month
```

This is useful for likely mobile/hotspot consumption.

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

These invariants should have automated tests.

## Units and formatting

Canonical storage is bytes.

Formatting is presentation-only. Use one consistent convention in the UI and label it. Preferred initial convention: decimal network units (kB, MB, GB) because mobile plans are typically marketed in decimal GB.

Do not persist rounded MB/GB values.

## Retention

For v1, retain all local usage history.

The schema should allow later compaction, for example converting old 5-minute buckets into daily aggregates, but do not implement destructive compaction until real storage measurements justify it.

At 5-minute granularity the expected record volume is modest for a desktop app.

## Repository responsibilities

`UsageRepository` should own:

- upsert/find `NetworkProfile` by identity key;
- open/update/close sessions;
- open/update/close buckets;
- stale-session recovery;
- date-range reads for analytics;
- alias updates;
- optional delete/reset history operation.

Views should not perform raw SwiftData fetches.

## Crash recovery

At launch:

1. find sessions left open from the previous process;
2. close them at their `lastCheckpointAt`;
3. close any open bucket at its last checkpoint;
4. mark session end reason `crashRecovery`;
5. never bridge counters from that session to current counters.

This makes persisted history conservative rather than inventing unobserved bytes.

## Schema migration discipline

Before changing stored fields:

- document the semantic change;
- add/update migration strategy if persistent releases already exist;
- preserve byte totals and network-profile identity wherever possible;
- add fixture-based migration tests once the first public schema ships.
