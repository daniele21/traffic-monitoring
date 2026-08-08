# Traffic Monitoring

**Local network observability for macOS.**

Traffic Monitoring helps you understand how your Mac uses the network: **how much data moves, when it moves, and across which network contexts** — while keeping usage analytics on-device.

It started from a practical question: **how much data am I actually using when my Mac connects through my phone hotspot?** It is evolving into the **Evidence & Observability** layer of a broader local-first software ecosystem without sacrificing the usefulness of the lightweight network-usage app.

> Local-first should not only be claimed. Where technically possible, it should be observable and verifiable.

## What it does today

Traffic Monitoring currently provides network-level observability using public macOS APIs:

- continuously measures physical-interface download/upload traffic;
- attributes usage to Wi-Fi, Personal Hotspot, Ethernet, and other supported physical network contexts;
- reads Darwin 64-bit interface counters;
- enriches Wi-Fi usage with SSID identity when macOS permission allows it;
- records `isExpensive` / `isConstrained` path metadata;
- excludes common virtual/tunnel interfaces from physical-traffic accounting to avoid obvious VPN double counting;
- stores historical usage locally with SwiftData;
- aggregates traffic into efficient 5-minute usage buckets with ~15-second checkpoints;
- shows Overview, Trend, Networks, and a separate technical Monitor;
- detects usage peaks and supports Today / 7 days / 30 days / This month / All time / Custom ranges;
- reports **evidence quality and observation coverage** instead of pretending every selected minute was observed;
- keeps unknown Wi-Fi identity explicit when SSID is unavailable;
- supports persistent friendly aliases without changing canonical network identity;
- provides a per-network drill-down with totals, trend, peak, identity quality, first/last observation, and expensive/constrained metadata;
- previews and exports **versioned JSON or CSV evidence** locally and only when the user asks;
- runs as a native SwiftUI menu-bar utility;
- is built, tested, and packaged as a downloadable `.app` through GitHub Actions.

Current analytics answer questions such as:

- How much network traffic did this Mac use today or this month?
- Which detected network accounted for the most usage?
- How much was downloaded vs uploaded?
- When did usage peak?
- How much traffic was observed on a likely phone hotspot / expensive connection?
- How much of the selected period was actually observed?
- Was some traffic measured with incomplete network identity?

## Evidence, not just totals

A number is useful only if its observation boundary is clear.

Traffic Monitoring therefore keeps two ideas separate:

```text
Observed usage
    +
Observation coverage / identity quality
    =
Network-level evidence
```

The current evidence states are:

- **Identified** — network context was identified and there are no known coverage gaps in the selected interval;
- **Partially identified** — some time was not observed or some traffic used a weaker identity;
- **Unknown network** — traffic was measured but a Wi-Fi/network identity was unavailable;
- **Tracking degraded** — counter/persistence/observation errors affected part of the evidence.

Long pauses such as app shutdown, sleep, or a failed observation are not silently filled in as monitored time.

Use **About this data** in Analytics to see selected time, observed time, healthy observation, gaps, and measurement limitations.

## Reproducible evidence export

The selected Analytics period can be previewed and saved as:

- **JSON schema v1** for structured tooling/documentation;
- **CSV** for spreadsheets and simple analysis.

Exports include aggregate totals, coverage, evidence quality, network identity/display name, connection kind, download/upload/total, expensive/constrained flags, app version, schema version, and observation timestamps.

They deliberately exclude packet payloads, browsing content, destinations, DNS history, BSSID, and process/application identity.

See [`docs/evidence-export.md`](docs/evidence-export.md) for the schema contract.

## What it does **not** claim today

The current tracker measures **physical-interface network usage**.

It does not currently establish:

- which application generated a specific network flow;
- whether every observed byte stayed on the LAN or reached the public Internet;
- which remote destination received traffic;
- that another application is “private” or “local-only”;
- exact ISP or mobile-carrier billing usage.

Local LAN transfers can be included in interface totals. Traffic Monitoring deliberately distinguishes measured evidence from conclusions the current evidence source cannot support.

## Strategic role

Traffic Monitoring is not an AI runtime and should not become a packet-inspection product merely to fit an AI portfolio.

Its ecosystem role is **Evidence & Observability**:

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

The future research direction is an **optional advanced observability mode** that could add source-application attribution and local-vs-external flow evidence. That work is gated by a dedicated macOS feasibility, entitlement, distribution, privacy, and performance review. It is not a current capability.

See:

- [`docs/positioning.md`](docs/positioning.md) — strategic role and claim boundaries;
- [`docs/a0-a2-implementation-status.md`](docs/a0-a2-implementation-status.md) — compact status for positioning/evidence/export;
- [`docs/local-first-observability-plan.md`](docs/local-first-observability-plan.md) — advanced staged evolution and go/no-go gates.

## Product principles

### Local by default

Usage history and evidence coverage stay on the Mac. Core functionality requires no account, cloud backend, or remote telemetry. Export is explicitly user-initiated.

### Observe, don't inspect

The core product observes network behavior without storing packet contents, websites, DNS history, browsing history, or payloads.

### Evidence over claims

Show what was observed, how complete the observation was, and what remained unknown. Unknown or incomplete evidence is a valid product state.

### Useful without advanced privileges

Hotspot/network analytics must remain fully useful even if future per-app observability requires a separately enabled macOS system component.

## Current architecture

```text
macOS physical interfaces
        │
        ├── 64-bit RX/TX counters
        ├── Wi-Fi / SSID context
        └── NWPath metadata
                │
                ▼
        attributed deltas
                │
                ├── usage accumulation
                └── evidence coverage heartbeat
                │
                ▼
       5-minute aggregate buckets
          ~15 s checkpoints
                │
                ▼
          SwiftData local store
                │
                ├── Analytics
                │   ├── Overview
                │   ├── Trend
                │   ├── Networks / details
                │   └── Evidence quality
                │
                ├── JSON / CSV export
                └── Monitor
```

Future app-level observability, if accepted after its feasibility spike, must remain architecturally separate from this lightweight core.

## Run without installing Xcode

The easiest way to test the current app is the macOS build produced by GitHub Actions.

1. Open **Actions → CI** in this repository.
2. Open the latest successful run for the branch/commit you want to test.
3. Download **TrafficMonitoring-macOS**.
4. Unzip the artifact, then unzip `TrafficMonitoring.app.zip` inside it.
5. Launch `TrafficMonitoring.app`.

The development artifact is ad-hoc signed, not notarized. If macOS blocks it, follow [`docs/run-without-xcode.md`](docs/run-without-xcode.md).

Traffic Monitoring is an `LSUIElement` menu-bar app, so after launch look for its icon in the macOS menu bar.

## Local development

```bash
brew install xcodegen
xcodegen generate
open TrafficMonitoring.xcodeproj
```

Run the `TrafficMonitoring` scheme on macOS 14+.

Platform-independent core tests can also run with:

```bash
swift test
```

## Measurement scope

Canonical metrics are bytes transferred through tracked physical network interfaces while Traffic Monitoring is observing:

- **download** = received interface bytes;
- **upload** = transmitted interface bytes;
- **total used** = download + upload.

This is **network-interface usage**, not guaranteed carrier-billable Internet usage.

## Documentation

Documentation uses progressive disclosure. Start with:

- [`AGENTS.md`](AGENTS.md) — invariants and task routing;
- [`docs/README.md`](docs/README.md) — documentation map;
- [`docs/product-spec.md`](docs/product-spec.md) — current product contract.

Focused strategy/evidence docs:

- [`docs/positioning.md`](docs/positioning.md)
- [`docs/a0-a2-implementation-status.md`](docs/a0-a2-implementation-status.md)
- [`docs/evidence-export.md`](docs/evidence-export.md)
- [`docs/local-first-observability-plan.md`](docs/local-first-observability-plan.md)

The current branch implements A0, A1, and A2, but **real-Mac reliability/coverage validation remains a release-quality gate**. CI success proves build and deterministic semantics; it does not replace Wi-Fi/hotspot/sleep/relaunch validation on real hardware.
