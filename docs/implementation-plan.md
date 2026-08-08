# Implementation plan

This is the execution document for coding agents. Read `../AGENTS.md` first, then only the detailed document referenced by the current milestone.

## Delivery strategy

Build correctness from the counter source upward. Do not start with a polished dashboard backed by fake or poorly understood metrics.

Sequence:

```text
Bootstrap
   ↓
Counter + network-context spike
   ↓
Deterministic tracking engine
   ↓
Persistence + reconciliation
   ↓
Menu-bar product loop
   ↓
Analytics dashboard
   ↓
Reliability / permissions / login launch
   ↓
Release hardening
```

Each milestone has an acceptance gate. Do not implement the next milestone until the current gate is met, except for trivial scaffolding that does not lock architectural decisions.

---

# M0 — Project bootstrap

**Goal:** create a clean native macOS application skeleton with test targets and dependency boundaries.

Read: `architecture.md`, `testing.md`.

## Tasks

- [ ] Create Xcode project for a Swift/SwiftUI macOS app.
- [ ] Set minimum deployment target to macOS 14 unless an explicit compatibility decision changes it.
- [ ] Create app bundle identifier and signing configuration suitable for local development.
- [ ] Add SwiftData container scaffolding without defining final schema prematurely.
- [ ] Create logical groups/directories:
  - `App/`
  - `Domain/`
  - `Platform/`
  - `Tracking/`
  - `Persistence/`
  - `Analytics/`
  - `Features/MenuBar/`
  - `Features/Dashboard/`
  - `Features/Settings/`
- [ ] Add unit-test target.
- [ ] Add a small shared configuration type for sample/checkpoint/bucket intervals.
- [ ] Add structured local logging categories.
- [ ] Ensure app can run as a menu-bar utility while still opening a normal analytics window.

## Acceptance gate

- App builds and launches on supported macOS.
- Menu-bar placeholder is visible.
- Empty analytics window can be opened.
- Unit-test target runs.
- No counter/network logic is embedded in SwiftUI views.

---

# M1 — Measurement feasibility spike

**Goal:** prove that public macOS APIs provide reliable 64-bit interface counters and enough context to associate them with physical connections.

Read: `tracking-engine.md`.

This milestone is deliberately diagnostic, not polished.

## 1. Interface counter reader

- [ ] Define `InterfaceCounterReader` protocol.
- [ ] Define `InterfaceCounterReading` with:
  - interface name;
  - received bytes;
  - transmitted bytes;
  - flags/type metadata needed for classification;
  - observation timestamp.
- [ ] Implement Darwin reader using public interface statistics.
- [ ] Confirm 64-bit safety on current macOS SDK/runtime.
- [ ] Enumerate all interfaces without crashing on unknown families.
- [ ] Ensure allocations from `getifaddrs` or alternative API are correctly freed.

## 2. Interface classification

- [ ] Define `InterfaceClassifier`.
- [ ] Identify physical Wi-Fi interfaces using CoreWLAN mapping where possible.
- [ ] Identify Ethernet/USB-style physical interfaces.
- [ ] Exclude `lo0`, `utun*`, AWDL/LLW, and other clearly virtual/system-only interfaces.
- [ ] Log classification reason in debug builds.

## 3. Network context

- [ ] Define `NetworkContextProviding` protocol.
- [ ] Integrate `NWPathMonitor`.
- [ ] Capture `isExpensive` and `isConstrained`.
- [ ] Integrate `CWWiFiClient.shared()` and retrieve SSID where authorized.
- [ ] Establish explicit `ssidUnavailable` context when not authorized or unavailable.
- [ ] Observe Wi-Fi/network path changes and emit context events.

## 4. Wired fingerprint spike

- [ ] Investigate a public-API method to distinguish the same Ethernet adapter on different networks.
- [ ] Prefer gateway/subnet context if reliably accessible without shell parsing or packet inspection.
- [ ] Document observed reliability across at least two wired-network contexts if hardware is available.
- [ ] If reliability is insufficient, retain the v1 fallback `wired:<interface>:unknown-network` and rely on aliasing.

## 5. Diagnostic surface

Create a temporary debug panel/log view showing:

```text
interface
classification
raw cumulative RX
raw cumulative TX
SSID/network identity
isExpensive
isConstrained
```

Then calculate basic 2-second deltas for inspection.

## Manual validation

Perform controlled tests:

1. idle for several minutes;
2. download a known-size large file;
3. upload a known-size file;
4. switch between two Wi-Fi SSIDs;
5. connect through iPhone/phone hotspot;
6. enable a VPN;
7. disconnect/reconnect;
8. if available, test Ethernet plus Wi-Fi simultaneously.

Compare physical-interface movement with Activity Monitor and/or `netstat -ib` as development references.

## Acceptance gate

- Counter values are monotonic during a normal connection.
- Known transfer produces plausible RX/TX deltas on the expected physical interface.
- Wi-Fi SSID can be observed when permission is granted.
- Tracking remains possible when SSID is unavailable.
- Personal Hotspot produces useful context, including `isExpensive` where macOS reports it.
- VPN does not require counting `utun*` to observe the underlying physical bytes.
- Chosen production counter API is documented in `decisions.md` if different from initial direction.

**Stop condition:** if this gate fails, do not build persistence/dashboard. Resolve measurement semantics first.

---

# M2 — Deterministic tracking engine

**Goal:** convert cumulative readings into correct attributed deltas with all core transitions represented as pure/testable logic.

Read: `tracking-engine.md`, `testing.md`.

## Domain models

- [ ] `InterfaceDescriptor`
- [ ] `InterfaceCounterReading`
- [ ] `NetworkKind`
- [ ] `NetworkIdentity`
- [ ] `NetworkContext`
- [ ] `TrafficDelta`
- [ ] `TrackingEvent`
- [ ] `LiveUsageSnapshot`

## State machine

- [ ] Implement serialized `TrafficTracker` (prefer actor).
- [ ] Maintain one baseline per tracked physical interface.
- [ ] First observation establishes baseline only.
- [ ] Calculate RX/TX delta using monotonic counters.
- [ ] Use monotonic clock for elapsed time/rate.
- [ ] Reject counter regressions.
- [ ] Reject clearly implausible deltas using conservative configurable guard.
- [ ] Handle interface appearance/disappearance.
- [ ] Split attribution on network identity change.
- [ ] Keep simultaneous physical interfaces independent.
- [ ] Exclude virtual interfaces before accounting.

## Events

Support deterministic events for:

- periodic sample;
- context changed;
- interface changed;
- sleep;
- wake;
- app termination;
- persistence checkpoint request.

## Live state

Expose immutable live snapshot containing at least:

```text
current/active network presentation
aggregate live RX rate
aggregate live TX rate
session bytes by active network/interface
today/month placeholders supplied later by analytics
tracking health state
```

## Acceptance gate

All required edge-case tests in `tracking-engine.md` pass using synthetic readers/context providers. No test requires a real Wi-Fi network to validate delta semantics.

---

# M3 — SwiftData persistence and reconciliation

**Goal:** persist network profiles, sessions, and five-minute usage buckets without coupling storage to sampling frequency.

Read: `data-and-analytics.md`.

## Schema

- [ ] Implement `NetworkProfileEntity`.
- [ ] Implement `ConnectionSessionEntity`.
- [ ] Implement `UsageBucketEntity`.
- [ ] Add uniqueness/index strategy appropriate to SwiftData capabilities.
- [ ] Keep network identity key distinct from display alias.

## Repository

- [ ] Define `UsageRepository` protocol.
- [ ] Implement `SwiftDataUsageRepository`.
- [ ] Find/upsert network profile.
- [ ] Open/update/close session.
- [ ] Open/update/close current bucket.
- [ ] Update active bucket checkpoint rather than inserting every sample.
- [ ] Recover stale session/bucket after crash.
- [ ] Rename network alias.
- [ ] Reset local history with explicit confirmation at UI phase.

## Tracker integration

- [ ] In-memory accumulation receives every valid delta.
- [ ] Checkpoint approximately every 15 seconds.
- [ ] Close at 5-minute boundary.
- [ ] Close immediately at network/sleep/interface boundary.
- [ ] Flush best effort on normal app termination.
- [ ] Start from fresh counters after process restart.

## Reconciliation tests

Given known synthetic deltas:

```text
sum(bucket.rx) == sum(accepted rx deltas)
sum(bucket.tx) == sum(accepted tx deltas)
session total == sum(session buckets)
```

Test crash recovery does not add traffic between last checkpoint and relaunch.

## Acceptance gate

- Usage survives app relaunch.
- Repeated sampling does not create one DB row per sample.
- Network transitions create correct profile/session/bucket boundaries.
- Stored totals reconcile exactly with accepted deltas in automated tests.

---

# M4 — Menu-bar MVP

**Goal:** make the tracker useful without the analytics dashboard.

Read: `ux.md`.

## Tasks

- [ ] Implement `MenuBarExtra`.
- [ ] Show current network/alias.
- [ ] Show live download/upload rate.
- [ ] Show current session usage.
- [ ] Add quick Today total via initial analytics query.
- [ ] Add current-month total.
- [ ] Add `Open Analytics`, `Settings`, `Quit` actions.
- [ ] Handle offline state.
- [ ] Handle SSID unavailable state.
- [ ] Show restrained expensive/likely-hotspot indicator.
- [ ] Make menu-bar title mode configurable.

## Acceptance gate

A user can run the app for a day and answer:

- what network am I on?
- how fast am I using it now?
- how much did this session use?
- how much did the Mac use today?

without opening developer tools.

---

# M5 — Analytics service and dashboard

**Goal:** provide persistent historical analysis grouped by network and time.

Read: `data-and-analytics.md`, `ux.md`.

## Analytics layer

- [ ] Implement `AnalyticsService` separate from SwiftUI.
- [ ] Implement Today / 7D / 30D / Month / Custom period builders.
- [ ] Implement summary query: total/download/upload.
- [ ] Implement time series with automatic hour/day granularity.
- [ ] Implement usage-by-network ranking.
- [ ] Implement expensive-network filter.
- [ ] Implement network detail summary.
- [ ] Implement session count and clipped connected duration.

## Dashboard

- [ ] Period selector.
- [ ] Total/download/upload summary.
- [ ] Usage-over-time Swift Chart.
- [ ] Network ranking table/list with total/share.
- [ ] Type filter.
- [ ] Network filter or detail selection.
- [ ] Expensive-only filter if UX remains simple.
- [ ] Empty states.
- [ ] Network drill-down.
- [ ] Rename alias.

## Reconciliation gate

For deterministic seeded DB fixtures:

```text
summary == sum(time series) == sum(network rows)
```

within only documented range-boundary rounding.

## Acceptance gate

The user can reliably answer:

- How much did I use today / this month?
- Which network used the most data?
- How much was on my phone hotspot/expensive connection?
- How much was download vs upload?
- What is the trend by day/hour?

---

# M6 — Permissions, lifecycle, and reliability

**Goal:** make continuous tracking dependable in normal Mac usage.

Read: `tracking-engine.md`, `ux.md`, `testing.md`.

## Location / SSID

- [ ] Add CoreLocation authorization flow required for current Wi-Fi SSID on modern macOS.
- [ ] Add purpose string describing only Wi-Fi-name identification.
- [ ] Continue fully when permission denied.
- [ ] Add settings status/action.
- [ ] Verify app signing behavior on a clean/test user account.

## Login launch

- [ ] Add `SMAppService` login-item registration.
- [ ] Make opt-in state visible and reversible.
- [ ] Verify restart → login → tracker starts without manual launch.

## Sleep/wake

- [ ] Observe sleep/wake.
- [ ] Checkpoint before sleep when possible.
- [ ] Reset baselines after wake.
- [ ] Verify no wake spike.

## Connectivity stress

- [ ] repeated Wi-Fi switches;
- [ ] hotspot on/off;
- [ ] VPN connect/disconnect;
- [ ] Ethernet plug/unplug;
- [ ] Wi-Fi + Ethernet simultaneously;
- [ ] captive portal/no Internet but link active;
- [ ] app quit/reopen;
- [ ] force kill/reopen.

## Health visibility

Add an internal tracking-health status:

```text
healthy
metadataDegraded
persistenceError
counterError
```

Only surface actionable/degraded states to users; keep verbose detail in local diagnostics.

## Acceptance gate

A multi-day run including sleep/wake and connection changes produces no unexplained large spikes, negative totals, database corruption, or VPN double counting.

---

# M7 — Release hardening

**Goal:** prepare a distributable v1.

## Quality

- [ ] Run all unit/integration tests.
- [ ] Add performance test for long synthetic history queries.
- [ ] Profile idle CPU, wakeups, memory, and DB writes with Instruments.
- [ ] Confirm no unbounded in-memory sample history.
- [ ] Confirm logs contain no traffic destinations/payloads.

## Packaging

- [ ] Production signing.
- [ ] Hardened Runtime as appropriate.
- [ ] App Sandbox decision verified against implemented APIs.
- [ ] Notarization path validated.
- [ ] Location permission behavior validated in signed/notarized build.
- [ ] Auto-update mechanism explicitly deferred or selected/documented.

## Product finish

- [ ] Onboarding.
- [ ] Privacy explanation.
- [ ] Reset-data flow.
- [ ] First-run empty states.
- [ ] Accessibility pass.
- [ ] Consistent decimal network-unit formatting.
- [ ] Version/about panel.

## Accuracy validation matrix

Document controlled tests with:

| Scenario | Expected behavior |
|---|---|
| Known download on Wi-Fi A | RX grows on Wi-Fi A only |
| Switch A → B | distinct network attribution |
| Phone hotspot | named SSID when authorized; expensive metadata when reported |
| VPN over Wi-Fi | physical Wi-Fi counted once |
| Ethernet transfer | wired profile receives bytes |
| Wi-Fi + Ethernet | independent physical deltas add correctly |
| Sleep/wake | no synthetic wake delta |
| Location denied | generic Wi-Fi tracking continues |
| Relaunch | old counters are not bridged to new process |

## Release gate

v1 ships only when the success criteria in `product-spec.md` are met and the measurement accuracy limitations are clearly represented in the UI/docs.

---

# Post-v1 backlog

Do not pull these into v1 without an explicit scope change:

## Mobile-plan mode

- configurable plan size;
- reset/billing day;
- opening balance for usage consumed before install;
- alerts at thresholds;
- dashboard focused on selected hotspot network.

## Export

- CSV of daily/network usage;
- diagnostics export without sensitive network details unless opted in.

## Storage compaction

- daily aggregates for old data if real storage measurements justify it.

## More precise wired identity

- improve gateway/network fingerprints based on findings from M1.

## Per-app usage

Requires a separate architecture/security review. Do not retrofit packet inspection into the core tracker.

---

# Agent execution notes

When implementing a milestone:

1. update checkboxes only for work actually completed;
2. do not mark acceptance gate complete from unit tests alone when manual network validation is required;
3. record a compact note under the milestone if reality differs from this plan;
4. change `decisions.md` when a foundational technical choice changes;
5. keep experimental spike code isolated until the API/semantics are proven;
6. prefer a conservative discarded interval to corrupted historical accounting.
