# AGENTS.md

## Purpose

Build **Traffic Monitoring**, a privacy-first macOS **local network observability** tool.

The current product continuously measures physical-interface traffic, attributes usage to network context, persists local history, exposes network-level analytics, reports evidence quality/coverage, and supports user-controlled aggregate evidence export. The strategic direction is to strengthen Traffic Monitoring as an **Evidence & Observability** layer for local-first software without forcing AI or privileged traffic inspection into the core product.

Future application attribution, local-vs-external flow evidence, or privacy-audit workflows are a separate advanced track and must not be described as implemented until their feasibility gates pass.

This file is intentionally short. Do not load the whole documentation tree by default.

## Progressive disclosure

Read only the documents needed for the task:

| If you are working on… | Read |
|---|---|
| Positioning / public narrative / ecosystem role | `docs/positioning.md` |
| Product scope / current behavior | `docs/product-spec.md` |
| A0–A2 status | `docs/a0-a2-implementation-status.md` |
| Evidence quality / coverage / persistence | `docs/data-and-analytics.md` |
| JSON/CSV evidence export | `docs/evidence-export.md` |
| Advanced observability / app attribution / audit roadmap | `docs/local-first-observability-plan.md` |
| Overall architecture / boundaries | `docs/architecture.md` |
| Counters, interfaces, SSID, network changes, VPN | `docs/tracking-engine.md` |
| Menu bar and dashboard UI | `docs/ux.md` |
| Current implementation order / milestones | `docs/implementation-plan.md` |
| Tests, fixtures, validation | `docs/testing.md` |
| Why key technical choices were made | `docs/decisions.md` |
| Documentation map only | `docs/README.md` |

For most changes, `AGENTS.md` + one or two targeted documents should be enough.

## Strategic invariants

1. Traffic Monitoring is positioned as **local network observability for macOS**, not as an AI project for its own sake.
2. Its ecosystem role is **Evidence & Observability**, not a fourth local-AI runtime pillar.
3. Current interface counters do **not** prove which application generated traffic or whether traffic reached the public Internet.
4. Never use future claims such as `per-app usage`, `external traffic`, `privacy audit`, or `verified local-only` unless the corresponding advanced-observability gate has been implemented and validated.
5. The base network-usage product must remain useful without future advanced privileges, Network Extension, or system-extension approval.
6. Unknown/incomplete evidence is a valid product state. Prefer explicit uncertainty over a false definitive verdict.
7. Advanced observability must be opt-in, separately documented, privacy-minimized, and architecturally separable from the core tracker.
8. Evidence export serializes current aggregates; it must not silently broaden what the app collects.

## Core tracking invariants

1. Track traffic continuously while the app is running; hotspot use is not a special tracking mode.
2. Attribute deltas to the physical network/interface context that produced them.
3. Never double-count virtual VPN/tunnel interfaces on top of their physical carrier.
4. Never persist packet contents, destinations, DNS queries, browsing history, or payload metadata in the core tracker.
5. Wi-Fi SSID enriches attribution but is not required for counting. If permission is unavailable, continue tracking with an explicit unknown Wi-Fi identity.
6. Counter resets, interface changes, sleep/wake, and app restart must never create negative or giant synthetic deltas.
7. Persist aggregates/buckets, not high-frequency raw samples.
8. The UI must distinguish network-interface usage from exact ISP/mobile-carrier billing usage.
9. All user data stays local in the current product unless the user explicitly exports it.
10. Prefer Apple public APIs. Do not ship shell-command parsing (`netstat`, `ifconfig`, `route`, `airport`) as the production data source.
11. Observation gaps must remain gaps; never infer that the app observed traffic while it was stopped, asleep, crashed, or unable to read counters.

## Default technical direction

Current core:

- Language: Swift.
- UI: SwiftUI.
- Minimum target: macOS 14+ unless a documented decision changes it.
- Menu bar: `MenuBarExtra`.
- Network path/context: `Network.framework` (`NWPathMonitor`).
- Wi-Fi metadata: `CoreWLAN` through `CWWiFiClient`.
- Interface counters: Darwin/BSD public 64-bit interface statistics, behind a protocol.
- Persistence: SwiftData.
- Charts: Swift Charts.
- Login launch: `SMAppService` when implemented.
- No Network Extension, packet capture, privileged helper, or launch daemon in current core mode.

Advanced observability:

- do not assume a final platform architecture;
- evaluate macOS Network Extension/content-filter APIs only inside the gated feasibility track in `docs/local-first-observability-plan.md`;
- do not retrofit flow inspection into the existing interface-counter reader.

## Architecture boundaries

Keep platform APIs behind small interfaces so the tracking state machine is testable without real networking:

- `InterfaceCounterReading` / `InterfaceCounterReader`
- `NetworkContext` / `NetworkContextProviding`
- `TrafficTracker`
- `UsageRepository`
- `AnalyticsService`

UI must consume domain/service models, not call CoreWLAN, Darwin/BSD counter APIs, Network.framework, or SwiftData fetches directly.

If advanced observability is accepted later, its provider/extension models must remain separate from core counter models and join only through an explicit evidence/analytics boundary.

## Development rules

- Make correctness observable: add structured debug logging around baselines, discarded deltas, context transitions, sleep/wake, and persistence checkpoints.
- Use `UInt64` for byte counters and stored totals in domain code.
- Compute deltas only between readings from the same interface generation/context.
- On ambiguous transitions, prefer dropping one uncertain interval over misattributing or double-counting traffic.
- Keep sampling and persistence cadences separate.
- Avoid storing BSSID by default; SSID is enough for current Wi-Fi grouping.
- Treat SSID/location permission denial as a supported product state, not an error state.
- Add tests with each state-machine, coverage, aggregation, or export change.
- Update the smallest relevant doc when behavior or an architectural invariant changes.
- Do not label traffic `external`, `local`, or `per-app` from physical-interface counters alone.
- Do not add payload persistence as a shortcut for future observability features.
- Preserve immutable network identity when changing a user-facing alias.
- Increment the evidence export schema version when a breaking export contract changes.

## Definition of done for implementation changes

A change is complete when:

- behavior is covered by unit/integration tests where feasible;
- no invariant above is violated;
- tracking continues through expected error/permission states;
- relevant documentation is updated without duplicating content across files;
- build/tests pass on the supported macOS/Xcode toolchain;
- user-facing claims match the evidence level actually implemented;
- exports reconcile with the same aggregate totals shown by analytics.

## Start here

For current core implementation work, read `docs/implementation-plan.md` next.

For A0–A2 evidence work, read `docs/a0-a2-implementation-status.md` and the focused evidence document.

For strategic/product positioning work, read `docs/positioning.md`.

For any request involving app attribution, Internet-vs-local classification, privacy audits, Network Extension, or developer evidence automation, read `docs/local-first-observability-plan.md` before changing code.
