# Architecture

Read this document when changing component boundaries or adding a new subsystem. Counter semantics live in `tracking-engine.md`; persistence semantics live in `data-and-analytics.md`.

## Architectural goals

- Native, small, low-overhead macOS utility.
- Tracking correctness independent from UI lifecycle details.
- Platform-specific APIs isolated behind protocols.
- Deterministic state machine that is unit-testable with synthetic readings.
- Local-only persistence in v1.
- Graceful degradation when optional metadata such as SSID is unavailable.

## Runtime overview

```text
macOS public APIs
      │
      ├──────── Network.framework ────────┐
      ├──────── CoreWLAN ─────────────────┤
      └──────── interface statistics ─────┤
                                          ▼
                              Platform Adapters
                         ┌──────────────────────┐
                         │ InterfaceCounterReader│
                         │ NetworkContextProvider│
                         │ LifecycleMonitor      │
                         └──────────┬───────────┘
                                    ▼
                              TrafficTracker
                     baseline → delta → attribution
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
             LiveUsageState                  UsageRepository
                    │                               │
                    ▼                               ▼
              MenuBar UI                    AnalyticsService
                                                    │
                                                    ▼
                                             Dashboard UI
```

## Modules

The initial Xcode project may start as one application target, but code should follow these logical modules/namespaces so extraction into packages remains possible later.

### App

Responsibilities:

- composition root;
- SwiftData container setup;
- start/stop tracker with application lifecycle;
- scene definitions (`MenuBarExtra`, analytics/settings windows);
- login-item preference integration.

Must not contain tracking logic.

### Platform

Owns macOS API adapters.

Suggested types:

- `DarwinInterfaceCounterReader`
- `AppleNetworkContextProvider`
- `WiFiContextProvider`
- `SystemLifecycleMonitor`

This layer may import Network, CoreWLAN, AppKit, Darwin, CoreLocation, and ServiceManagement.

### Domain

Pure Swift where possible.

Suggested types:

- `InterfaceCounterReading`
- `InterfaceDescriptor`
- `NetworkContext`
- `NetworkIdentity`
- `TrafficDelta`
- `TrackingEvent`
- `TrackingState`
- `UsagePeriod`

No UI or persistence framework should be required for domain calculations.

### Tracking

Owns the continuous measurement state machine.

Suggested types:

- `TrafficTracker`
- `InterfaceBaselineStore`
- `DeltaValidator`
- `NetworkAttributionResolver`
- `UsageBucketAccumulator`

The tracker consumes snapshots/events and produces validated attributed deltas.

### Persistence

Owns SwiftData models and repository implementations.

Suggested types:

- `NetworkProfileEntity`
- `ConnectionSessionEntity`
- `UsageBucketEntity`
- `SwiftDataUsageRepository`

Expose domain DTOs/protocols upward; do not leak `ModelContext` into the UI.

### Analytics

Owns read models and aggregation semantics.

Suggested types:

- `AnalyticsService`
- `UsageSummary`
- `UsageTimePoint`
- `NetworkUsageRow`
- `NetworkDetailSummary`

Queries should be independent of SwiftUI view composition.

### Features / UI

Suggested feature groups:

- `MenuBar`
- `Dashboard`
- `NetworkDetail`
- `Settings`
- `Onboarding`

Views observe view models/services and never read low-level counters directly.

## Dependency direction

```text
UI ───────► Analytics / Tracking facades
                 │
                 ▼
              Domain
                 ▲
                 │
Platform ────────┤
Persistence ─────┘
```

Rules:

- Domain does not depend on Platform, Persistence, or UI.
- Tracking depends on protocols, not concrete CoreWLAN/Darwin implementations.
- Analytics depends on repository protocols.
- UI may depend on presentation models and facades only.

## Main data flow

### Startup

1. Open local persistent store.
2. Recover/close any stale open session from a previous crash if necessary.
3. Request/inspect optional SSID authorization state.
4. Start network-context observation.
5. Take an initial interface-counter snapshot as baseline.
6. Start periodic sampling.
7. Publish live state to menu bar.

No usage is recorded from the first snapshot because there is no prior baseline.

### Sampling

At each sample tick:

1. Read physical interface counters.
2. Resolve current context for each trackable interface.
3. Compare with previous baseline.
4. Reject invalid/reset/discontinuous deltas.
5. Attribute valid bytes to a network identity.
6. Update in-memory live/session totals.
7. Accumulate into the current persistence bucket.
8. Persist on checkpoint cadence, boundary, or lifecycle event.
9. Replace baseline.

### Context transition

When Network.framework/CoreWLAN reports a meaningful connection change:

1. trigger an immediate counter read where possible;
2. close the old attribution interval;
3. persist/flush the old bucket/session;
4. resolve the new context;
5. establish a new baseline for the new context;
6. start a new session/bucket.

Prefer losing a tiny ambiguous interval over assigning it to the wrong network.

## Concurrency model

Use a single serialized owner for mutable tracking state. Preferred implementation is an `actor TrafficTracker` or equivalent serial execution context.

Platform callbacks and timers send events into this owner. SwiftUI receives immutable snapshots on `MainActor`.

Do not mutate baselines, sessions, or bucket accumulators from multiple queues.

## Timing model

Initial defaults, configurable internally:

- counter sample: every 2 seconds while awake;
- live rate calculation: derived from actual elapsed monotonic time between valid samples;
- persistence checkpoint: about every 15 seconds;
- analytics bucket target: 5-minute windows, split early on network/context transitions;

These values should live in a configuration type rather than magic constants.

## Failure model

The app should fail soft:

- no Location permission → track generic Wi-Fi identity;
- CoreWLAN returns nil → retain counting, mark SSID unavailable;
- one malformed interface → ignore that interface/read, continue others;
- persistence failure → log visibly in diagnostics and avoid pretending data is safely recorded;
- counter discontinuity → discard delta and reset baseline;
- network context ambiguity → use explicit unknown identity, never guess a previous SSID.

## No background helper in v1

Keep tracking in the signed user application/menu-bar process. This simplifies permissions and is especially important for Wi-Fi identity: modern macOS gates SSID access behind Location Services, and headless daemon approaches complicate or prevent that authorization path.

Auto-start at login should make the main app persistent enough for v1. A helper/agent can be reconsidered only if measurements show the app process cannot meet reliability requirements.

## External references

Apple APIs selected for the implementation:

- Network.framework `NWPathMonitor`: https://developer.apple.com/documentation/network/nwpathmonitor
- `NWPath.isExpensive`: https://developer.apple.com/documentation/network/nwpath/isexpensive
- CoreWLAN `CWInterface`: https://developer.apple.com/documentation/corewlan/cwinterface
- BSD `getifaddrs`: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/freeifaddrs.3.html
- SwiftUI `MenuBarExtra`: https://developer.apple.com/documentation/swiftui/menubarextra
