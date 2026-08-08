# AGENTS.md

## Purpose

Build **Traffic Monitoring**, a privacy-first macOS **local network observability** tool.

The core product measures physical-interface traffic, attributes usage to network context, persists local history, exposes network-level analytics, reports evidence quality/coverage, and supports user-controlled aggregate evidence export.

An **optional Advanced Observability prototype** now exists for app-level flow evidence. It is a separate macOS Network Extension system-extension path and is **not release-validated** until the signed real-Mac gates in `docs/b0-b2-implementation-status.md` pass.

This file is intentionally short. Do not load the whole documentation tree by default.

## Progressive disclosure

Read only the documents needed for the task:

| If you are working on… | Read |
|---|---|
| Positioning / public narrative / ecosystem role | `docs/positioning.md` |
| Product scope / current behavior | `docs/product-spec.md` |
| Visual identity / logo / palette / UI styling | `docs/brand.md` |
| A0–A2 status | `docs/a0-a2-implementation-status.md` |
| B0–B2 current status | `docs/b0-b2-implementation-status.md` |
| Advanced Observability platform feasibility | `docs/advanced-observability-feasibility.md` |
| Advanced Observability architecture decision | `docs/adr/0001-advanced-observability-content-filter.md` |
| Evidence quality / coverage / persistence | `docs/data-and-analytics.md` |
| JSON/CSV evidence export | `docs/evidence-export.md` |
| Broader app-attribution / audit roadmap | `docs/local-first-observability-plan.md` |
| Overall core architecture / boundaries | `docs/architecture.md` |
| Counters, interfaces, SSID, network changes, VPN | `docs/tracking-engine.md` |
| Menu bar and dashboard UI | `docs/ux.md` |
| Current implementation order / milestones | `docs/implementation-plan.md` |
| Tests, fixtures, validation | `docs/testing.md` |
| Documentation map only | `docs/README.md` |

For most changes, `AGENTS.md` + one or two targeted documents should be enough.

## Strategic invariants

1. Traffic Monitoring is **local network observability for macOS**, not an AI project for its own sake.
2. Its ecosystem role is **Evidence & Observability**, not a fourth local-AI runtime pillar.
3. Core physical-interface counters do **not** prove source application or Internet-vs-LAN locality.
4. Advanced Observability evidence must come only from the separately gated provider path; never infer `per-app`, `local`, or `external` from core counters.
5. The base network-usage product must remain useful when the system extension is absent, disabled, unapproved, or broken.
6. Unknown/incomplete evidence is a valid state. Prefer `Unknown application`, `unknown` locality, incomplete coverage, or `Not validated` over a false definitive result.
7. Never persist packet payloads, browsing content, message content, or raw audit tokens as an observability shortcut.
8. Advanced Observability is explicit opt-in and independently disableable.
9. Enabling the macOS content-filter configuration can disable another active content filter. The UI must warn the user before enabling it; never activate it silently.
10. No privacy-audit claim may be stronger than the validated provider coverage and evidence semantics.

## Core tracking invariants

1. Track traffic continuously while the app is running; hotspot use is not a special tracking mode.
2. Attribute deltas to the physical network/interface context that produced them.
3. Never double-count virtual VPN/tunnel interfaces on top of their physical carrier.
4. Wi-Fi SSID enriches attribution but is not required for counting. If unavailable, continue with explicit unknown Wi-Fi identity.
5. Counter resets, interface changes, sleep/wake, and app restart must never create negative or giant synthetic deltas.
6. Persist aggregates/buckets, not high-frequency raw samples.
7. Observation gaps remain gaps; never infer monitoring while the app was stopped/asleep/crashed.
8. The UI must distinguish network-interface usage from exact ISP/mobile-carrier billing usage.
9. Core data stays local unless the user explicitly exports it.
10. Prefer Apple public APIs; do not ship shell-command parsing as the production counter source.

## Current technical direction

### Core

- Swift + SwiftUI, macOS 14+.
- `MenuBarExtra`.
- Network path/context: `NWPathMonitor`.
- Wi-Fi metadata: CoreWLAN.
- Counters: Darwin/BSD public 64-bit interface statistics.
- Persistence: SwiftData.
- Charts: Swift Charts.

### Advanced Observability prototype

- Optional `NEFilterDataProvider` packaged as a macOS system extension.
- Source app primitive on macOS: `sourceAppAuditToken`, resolved through Security Code Signing APIs; not `sourceAppIdentifier`.
- Locality: loopback / localNetwork / external / unknown; do not create DNS traffic just to classify.
- Byte source: low-frequency `NEFilterReport` statistics; keep `ByteAccountingCapability.notValidated` until real-Mac reconciliation passes.
- Provider aggregates in memory before IPC.
- Provider → app evidence transport: Mach/XPC service declared by `NEMachServiceName`.
- XPC transfers aggregate evidence only, not packet payloads or raw audit tokens.
- Host activation: SystemExtensions framework + explicit user action.
- Filter configuration: `NEFilterManager`; `filterSockets` / `filterBrowsers` only after user consent.
- Ad-hoc CI builds may compile/package the provider but must not pretend they can activate a properly entitled system extension.

## Architecture boundaries

Core platform APIs stay behind small service boundaries; UI must not call CoreWLAN, BSD counter APIs, Network.framework, or SwiftData fetches directly.

Advanced provider code stays outside the core tracker and joins the app only through explicit Advanced Observability evidence models/controller. Never retrofit flow inspection into `InterfaceCounterReader` or core usage buckets.

## Development rules

- Make correctness observable with structured debug logging, without logging sensitive flow content.
- Use `UInt64` for byte counters/totals in domain code.
- On ambiguous transitions, prefer dropping an uncertain interval over misattributing traffic.
- Keep sampling and persistence cadences separate.
- Treat permission denial and provider unavailability as supported states.
- Add tests for state-machine, coverage, aggregation, export, locality, and evidence-contract changes.
- Preserve immutable network identity when changing a display alias.
- Increment export schema versions when breaking evidence contracts.
- For XPC production hardening, authenticate the connecting client before exposing provider evidence.
- Do not promote advanced byte accounting to `validated` from compile success alone.

## Definition of done

A change is complete when:

- relevant tests pass;
- core tracking still functions independently;
- user-facing claims match the actual evidence level;
- unknown/degraded states remain visible;
- privacy boundaries are preserved;
- the smallest authoritative documentation is updated;
- supported macOS/Xcode CI passes.

For Advanced Observability, compile success closes only the SDK/build gate. Signed activation, controlled source-app/locality/byte tests, XPC authentication, coverage, VPN/helper cases, performance, and distribution remain separate real-Mac gates until explicitly completed.

## Start here

- Core implementation → `docs/implementation-plan.md`.
- A0–A2 evidence/export → `docs/a0-a2-implementation-status.md`.
- Brand/UI styling → `docs/brand.md` + `docs/ux.md`.
- Advanced Observability implementation/status → `docs/b0-b2-implementation-status.md` + `docs/advanced-observability-feasibility.md`.
- Future audits/developer automation → `docs/local-first-observability-plan.md` only after B1/B2 evidence is validated.
