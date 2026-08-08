# AGENTS.md

## Purpose

Build a lightweight, privacy-first macOS app that continuously measures network-interface traffic and attributes usage to the network context in which it occurred. The primary UX is a menu-bar utility plus an analytics window grouped by time, network, connection type, download, and upload.

This file is intentionally short. Do not load the whole documentation tree by default.

## Progressive disclosure

Read only the documents needed for the task:

| If you are working on… | Read |
|---|---|
| Product scope / behavior | `docs/product-spec.md` |
| Overall architecture / boundaries | `docs/architecture.md` |
| Counters, interfaces, SSID, network changes, VPN | `docs/tracking-engine.md` |
| Persistence, identities, aggregation, analytics queries | `docs/data-and-analytics.md` |
| Menu bar and dashboard UI | `docs/ux.md` |
| Implementation order / current milestones | `docs/implementation-plan.md` |
| Tests, fixtures, validation | `docs/testing.md` |
| Why key technical choices were made | `docs/decisions.md` |
| Documentation map only | `docs/README.md` |

For most changes, `AGENTS.md` + one or two targeted documents should be enough.

## Core invariants

1. Track traffic continuously while the app is running; hotspot use is not a special tracking mode.
2. Attribute deltas to the physical network/interface context that produced them.
3. Never double-count virtual VPN/tunnel interfaces on top of their physical carrier.
4. Never persist packet contents, destinations, DNS queries, browsing history, or payload metadata.
5. Wi-Fi SSID enriches attribution but is not required for counting. If permission is unavailable, continue tracking with an explicit unknown Wi-Fi identity.
6. Counter resets, interface changes, sleep/wake, and app restart must never create negative or giant synthetic deltas.
7. Persist aggregates/buckets, not high-frequency raw samples.
8. The UI must distinguish network-interface usage from exact ISP/mobile-carrier billing usage.
9. All user data stays local in v1.
10. Prefer Apple public APIs. Do not ship shell-command parsing (`netstat`, `ifconfig`, `route`, `airport`) as the production data source.

## Default technical direction

- Language: Swift.
- UI: SwiftUI.
- Minimum target: macOS 14+ unless a documented decision changes it.
- Menu bar: `MenuBarExtra`.
- Network path/context: `Network.framework` (`NWPathMonitor`).
- Wi-Fi metadata: `CoreWLAN` through `CWWiFiClient`.
- Interface counters: Darwin/BSD public interface statistics, behind a protocol and validated against system tools during development.
- Persistence: SwiftData.
- Charts: Swift Charts.
- Login launch: `SMAppService` when implemented.
- No Network Extension, packet capture, privileged helper, or launch daemon in v1.

## Architecture boundaries

Keep platform APIs behind small interfaces so the tracking state machine is testable without real networking:

- `InterfaceCounterReading` / `InterfaceCounterReader`
- `NetworkContext` / `NetworkContextProviding`
- `TrafficTracker`
- `UsageRepository`
- `AnalyticsService`

UI must consume domain/service models, not call CoreWLAN, `getifaddrs`, or Network.framework directly.

## Development rules

- Make correctness observable: add structured debug logging around baselines, discarded deltas, context transitions, sleep/wake, and persistence checkpoints.
- Use `UInt64` for byte counters and stored totals.
- Compute deltas only between readings from the same interface generation/context.
- On ambiguous transitions, prefer dropping one uncertain interval over misattributing or double-counting traffic.
- Keep sampling and persistence cadences separate.
- Avoid storing BSSID by default; SSID is enough for v1 Wi-Fi grouping.
- Treat SSID/location permission denial as a supported product state, not an error state.
- Add tests with each state-machine or aggregation change.
- Update the smallest relevant doc when a behavior or architectural invariant changes.

## Definition of done for implementation changes

A change is complete when:

- behavior is covered by unit/integration tests where feasible;
- no invariant above is violated;
- tracking continues through expected error/permission states;
- relevant documentation is updated without duplicating content across files;
- build/tests pass on the supported macOS/Xcode toolchain.

## Start here

For a new implementation agent, read `docs/implementation-plan.md` next. Follow the current milestone and its acceptance criteria instead of implementing later phases opportunistically.
