# Testing strategy

This document defines how correctness is proven without requiring every test to depend on live macOS networking.

## Testing pyramid

```text
Manual hardware/network validation
            ▲
       Integration tests
            ▲
   Deterministic unit tests
```

Most tracking semantics must be covered by deterministic unit tests. Real-network tests validate platform adapters and assumptions that mocks cannot prove.

## 1. Domain and tracker unit tests

Use fake implementations of:

- `InterfaceCounterReader`;
- `NetworkContextProviding`;
- clock/time source;
- `UsageRepository`.

Feed explicit sequences of events/readings and assert emitted deltas, state, and persistence calls.

### Required counter tests

- first reading produces no usage;
- monotonic RX/TX produces exact delta;
- upload-only and download-only traffic;
- zero delta;
- timer jitter uses actual elapsed time for rate;
- counter regression discards interval and resets baseline;
- implausible delta guard rejects corrupted reading;
- very large legitimate `UInt64` values do not overflow calculations.

### Required attribution tests

- same interface + same network continues session;
- same `en0` switches SSID A → SSID B;
- network disconnect/reconnect creates boundary;
- SSID becomes unavailable;
- permission unavailable never reuses stale SSID;
- `isExpensive` metadata is persisted for the relevant interval;
- simultaneous physical interfaces remain independent;
- virtual `utun*` interface is excluded from accounting.

### Required lifecycle tests

- sleep flushes and suspends;
- wake creates new baselines and no immediate delta;
- graceful stop flushes;
- crash recovery closes stale session at last checkpoint;
- relaunch never computes a cross-process counter delta.

## 2. Persistence tests

Use an isolated/in-memory SwiftData store where possible.

Test:

- network-profile upsert by identity key;
- alias rename does not change identity;
- current bucket checkpoint updates rather than duplicates;
- context transition closes previous bucket;
- five-minute boundary creates next bucket;
- session totals reconcile with bucket totals;
- stale session recovery;
- delete/reset history;
- query behavior with empty data;
- values near persistence numeric limits.

Once a public schema ships, keep a persistent fixture from each schema version and add migration tests.

## 3. Analytics fixture tests

Seed deterministic buckets/sessions across:

- multiple days;
- multiple networks;
- download/upload mixes;
- expensive and non-expensive connections;
- concurrent interfaces;
- month boundary;
- DST transition where practical.

Assert:

```text
summary.total = summary.download + summary.upload
summary = sum(network rows)
summary = sum(time-series points)
```

Test period clipping and custom-range boundary behavior explicitly.

## 4. Platform adapter tests

Platform APIs are not fully mockable, so keep adapters small and add targeted tests where useful.

### Interface reader

Verify:

- returns known active interface names;
- byte values are non-negative/monotonic during a stable connection;
- repeated reads do not leak memory;
- unknown interface families do not crash;
- excluded interfaces are classified as expected.

### CoreWLAN

Verify signed app behavior for:

- Location not determined;
- authorized;
- denied;
- current SSID;
- Wi-Fi disconnected;
- SSID switch.

Do not make CI depend on a specific SSID.

### NWPathMonitor

Verify context adapter produces events for practical path changes and captures expensive/constrained metadata.

## 5. Manual accuracy scenarios

Record results in a lightweight checklist before release.

### Controlled download

1. note baseline physical-interface bytes;
2. transfer a known-size file over the Internet;
3. compare app delta with interface-counter reference;
4. account for protocol overhead — exact file-size equality is not expected.

Expected: app/interface-counter values are close because both measure network bytes, and attribution goes to the expected network.

### Controlled upload

Same process focused on TX.

### Wi-Fi switch

1. generate traffic on Wi-Fi A;
2. switch to Wi-Fi B;
3. generate more traffic;
4. inspect dashboard.

Expected: separate profiles/session boundaries and no giant transition delta.

### Phone hotspot

Expected:

- usage is counted normally;
- SSID identifies the phone hotspot if authorized/available;
- expensive flag is shown if macOS reports it;
- switching back to Wi-Fi closes hotspot attribution.

### VPN

1. record usage without VPN;
2. enable VPN;
3. perform controlled transfer;
4. inspect physical and `utun*` counters in diagnostics.

Expected: persisted product total counts the underlying physical interface once.

### Sleep/wake

Expected: no synthetic spike immediately after wake.

### Force kill

Expected: at most the bounded uncheckpointed interval is lost; no synthetic bytes appear after restart.

## 6. Long-run reliability test

Before v1 release, perform a multi-day run that includes:

- multiple sleeps/wakes;
- at least two Wi-Fi networks;
- hotspot use;
- VPN toggle;
- app restart;
- network disconnect;
- dashboard queries.

Inspect:

- monotonic historical totals;
- no absurd single bucket;
- no permanently open stale sessions;
- DB size;
- CPU/wakeups;
- memory growth;
- persistence error logs.

## 7. Performance tests

### Tracker

Use synthetic event streams to ensure processing thousands/millions of samples does not accumulate raw history in memory.

### Database

Seed approximately one year of five-minute buckets across several networks and measure:

- current month summary;
- 30-day time series;
- usage by network;
- one-network detail.

Queries should remain interactive on target hardware.

### Energy

Use Instruments before release to inspect:

- CPU when idle;
- timer wakeups;
- database write frequency;
- memory stability.

If sampling every 2 seconds causes measurable energy cost, tune cadence based on data rather than intuition.

## 8. CI expectations

Once project files exist, CI should run at least:

- build for supported macOS target;
- unit tests;
- persistence/analytics integration tests;
- formatting/linting only if the project adopts a formatter/linter explicitly.

Do not create CI tests that require Location permission, a specific network, an iPhone hotspot, or Internet access.

## Bug regression rule

Every tracking/accounting bug should gain a deterministic regression fixture whenever the failure can be represented as a sequence of counters/context events. This keeps real-world edge cases from returning later.
