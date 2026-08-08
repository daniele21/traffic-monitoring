<p align="center">
  <img src="TrafficMonitoring/Resources/BrandAssets.xcassets/BrandShield.imageset/shield.svg" width="150" alt="Traffic Monitoring shield logo" />
</p>

# Traffic Monitoring

**Local network observability for macOS.**

Traffic Monitoring helps you understand how your Mac uses the network: **how much data moves, when it moves, and across which network contexts** — while keeping usage analytics on-device.

It started from a practical question: **how much data am I actually using when my Mac connects through my phone hotspot?** It is evolving into the **Evidence & Observability** layer of a broader local-first software ecosystem without sacrificing the usefulness of the lightweight network-usage app.

> Local-first should not only be claimed. Where technically possible, it should be observable and verifiable.

## What works in the core product

Traffic Monitoring currently provides network-level observability using public macOS APIs:

- continuously measures physical-interface download/upload traffic;
- attributes usage to Wi-Fi, Personal Hotspot, Ethernet, and other supported physical network contexts;
- reads Darwin 64-bit interface counters;
- enriches Wi-Fi usage with SSID identity when macOS permission allows it;
- records `isExpensive` / `isConstrained` path metadata;
- excludes common virtual/tunnel interfaces from physical-traffic accounting to avoid obvious VPN double counting;
- persists historical usage locally with SwiftData;
- uses efficient 5-minute usage/coverage buckets with ~15-second checkpoints;
- shows Overview, Trend, Networks, network detail, and a separate technical Monitor;
- supports Today / 7 days / 30 days / This month / All time / Custom ranges;
- reports **evidence quality and observation coverage** instead of pretending every selected minute was observed;
- keeps unknown Wi-Fi identity explicit when SSID is unavailable;
- supports friendly network aliases without rewriting canonical identity;
- previews and exports versioned **JSON / CSV network evidence** only when the user asks;
- runs as a native SwiftUI menu-bar utility;
- is built, tested, Release-packaged, and made downloadable by GitHub Actions.

Core Analytics answers questions such as:

- How much network traffic did this Mac use today or this month?
- Which detected network accounted for the most usage?
- How much was downloaded vs uploaded?
- When did usage peak?
- How much traffic was observed on a likely expensive/hotspot path?
- How much of the selected period was actually observed?
- Was some traffic measured with incomplete network identity?

## Evidence, not just totals

Traffic Monitoring keeps usage and observation quality separate:

```text
Observed usage
    +
Observation coverage / identity quality
    =
Network-level evidence
```

Core evidence states:

- **Identified** — observed network context is identified and there are no known gaps for the interval;
- **Partially identified** — some time was not observed or some usage used weaker metadata;
- **Unknown network** — traffic was measured but a reliable Wi-Fi/network identity was unavailable;
- **Tracking degraded** — a counter/persistence/observation problem affected part of the evidence.

Sleep, app shutdown, crashes, and long observation gaps are not silently filled in as monitored time.

Use **About this data** in Analytics to inspect selected time, observed time, healthy observation, gaps, and measurement limitations.

## Reproducible network evidence export

The selected Analytics period can be previewed and saved as:

- **JSON schema v1** for structured tooling/documentation;
- **CSV** for spreadsheet workflows.

Exports include aggregate totals, coverage, evidence quality, network identity/display name, connection kind, download/upload/total, expensive/constrained flags, app/schema versions, and observation timestamps.

They deliberately exclude packet payloads, browsing content, destinations, DNS history, BSSID, and process/application identity.

See [`docs/evidence-export.md`](docs/evidence-export.md).

## Advanced Observability — experimental

The branch also contains an **opt-in B0/B1/B2 prototype** for app-level network evidence. This is intentionally separate from the core tracker.

Prototype architecture:

```text
Traffic Monitoring.app
        │
        │ aggregate snapshot over XPC
        ▼
Embedded Network Extension system extension
        │
        ├── sourceAppAuditToken
        ├── Security signing-identifier resolution
        ├── loopback / local / external / unknown classification
        ├── low-frequency flow statistics
        └── in-memory per-app aggregation
```

Implemented prototype surfaces:

- embedded macOS `NEFilterDataProvider` system-extension target;
- source application path based on `sourceAppAuditToken` with `Unknown application` fallback;
- deterministic locality classification with explicit `unknown`;
- low-frequency `NEFilterReport` byte accounting, currently marked **Not validated**;
- provider → app Mach/XPC aggregate-evidence bridge;
- opt-in **Applications** view with Disabled / Provider unavailable / Awaiting approval / Active / Degraded states;
- per-application Local / External / Unknown evidence and detail view;
- Settings lifecycle to request system-extension activation, surface macOS approval, configure `NEFilterManager`, and disable the filter;
- no fake application rows when the provider is unavailable.

All source/build/package gates pass in CI, including the embedded system-extension bundle. That is **not** equivalent to signed runtime validation.

### Why the downloadable development build may show `Provider unavailable`

The GitHub Actions `.app` is ad-hoc signed for local core testing. macOS system-extension activation additionally checks Apple entitlements, provisioning/signing, app location, and user approval.

Therefore the development artifact remains fully usable for core Analytics while honestly reporting Advanced Observability as unavailable when the provider cannot be activated.

### Content-filter warning

macOS allows one enabled Network Extension content-filter configuration at a time. Enabling this experimental mode can disable another active content filter.

Traffic Monitoring therefore:

- never enables Advanced Observability silently;
- asks for explicit confirmation;
- keeps core Analytics independent;
- lets the user disable the filter separately.

This coexistence constraint is still part of the production go/no-go decision.

See:

- [`docs/b0-b2-implementation-status.md`](docs/b0-b2-implementation-status.md)
- [`docs/advanced-observability-feasibility.md`](docs/advanced-observability-feasibility.md)
- [`docs/adr/0001-advanced-observability-content-filter.md`](docs/adr/0001-advanced-observability-content-filter.md)

## What Traffic Monitoring does **not** claim

The validated core tracker measures **physical-interface network usage**. It does not by itself establish:

- which application generated traffic;
- whether every byte stayed on the LAN or reached the public Internet;
- which remote destination received traffic;
- that another application is “private” or “local-only”;
- exact ISP/mobile-carrier billing usage.

The Advanced Observability prototype must not be used to make stronger claims until signed real-Mac tests validate source-app identity, locality, byte accounting, XPC coverage/security, helper/VPN behavior, and performance.

Safe wording remains observational: measured evidence + known coverage + explicit unknowns.

## Strategic role

Traffic Monitoring is not an AI runtime and should not become a packet-inspection product merely to fit an AI portfolio.

```text
Local-first ecosystem
├── Reusable AI infrastructure
│   ├── Local LLM Server
│   ├── Local ASR Server
│   └── Android Local LLM Harness
│
├── Reference applications
│   ├── ClosedRoom
│   └── Aura Finance
│
└── Evidence & observability
    └── Traffic Monitoring
```

Its contribution is the network side of a broader principle:

> **Evidence over claims.**

## Product principles

### Local by default

Core usage history and evidence coverage stay on the Mac. No account, analytics backend, or remote telemetry is required. Export is user-initiated.

### Observe, don't inspect

The product is designed around metadata/aggregates, not packet-content retention. Advanced provider IPC carries aggregate evidence, not raw payloads or raw audit tokens.

### Unknown is valid

Never turn incomplete evidence into a definitive result. `Unknown network`, `Unknown application`, `unknown` locality, degraded coverage, and `Not validated` byte accounting are first-class states.

### Useful without advanced privileges

Hotspot/network analytics remain fully useful when the system extension is absent, disabled, unapproved, or rejected by the future product go/no-go decision.

## Architecture

```text
                         Traffic Monitoring.app
                                  │
           ┌──────────────────────┴──────────────────────┐
           │                                             │
           ▼                                             ▼
   Core network usage                         Advanced Observability
   ------------------                         ----------------------
   64-bit interface counters                  optional system extension
   CoreWLAN / SSID                            audit-token app identity
   NWPath metadata                            flow locality
           │                                  flow statistics
           ▼                                             │
   attributed deltas                                    XPC
           │                                             │
           ▼                                             ▼
   5-minute usage + coverage                    Applications UI
   ~15 s checkpoints                            experimental evidence
           │
           ▼
   SwiftData local history
           │
     ┌─────┼──────────┐
     ▼     ▼          ▼
 Overview Trend    Networks / detail
     │
 JSON / CSV export
```

## Run without installing Xcode

1. Open **Actions → CI**.
2. Open the latest successful run for the branch/commit you want to test.
3. Download **TrafficMonitoring-macOS**.
4. Unzip the artifact, then unzip `TrafficMonitoring.app.zip`.
5. Launch `TrafficMonitoring.app`.

The artifact is ad-hoc signed, not notarized. Follow [`docs/run-without-xcode.md`](docs/run-without-xcode.md) if macOS quarantine blocks the development build.

Traffic Monitoring is an `LSUIElement` menu-bar app, so after launch look for its shield icon in the menu bar.

## Local development

```bash
brew install xcodegen
xcodegen generate
open TrafficMonitoring.xcodeproj
```

Run the `TrafficMonitoring` scheme on macOS 14+.

Core tests:

```bash
swift test
```

## Documentation

Start small:

- [`AGENTS.md`](AGENTS.md) — invariants and progressive-disclosure routing
- [`docs/README.md`](docs/README.md) — documentation map
- [`docs/product-spec.md`](docs/product-spec.md) — core product contract
- [`docs/brand.md`](docs/brand.md) — visual system
- [`docs/a0-a2-implementation-status.md`](docs/a0-a2-implementation-status.md) — evidence/export status
- [`docs/b0-b2-implementation-status.md`](docs/b0-b2-implementation-status.md) — Advanced Observability status

CI proves deterministic semantics, buildability, Release packaging, and system-extension embedding. Real-Mac validation remains mandatory for network reliability and Advanced Observability runtime evidence.
