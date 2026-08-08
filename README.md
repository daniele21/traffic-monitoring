# Traffic Monitoring

**Local network observability for macOS.**

Traffic Monitoring helps you understand how your Mac uses the network: how much data moves, when it moves, and across which network contexts — while keeping usage analytics on-device.

It started from a practical question: **how much data am I actually using when my Mac connects through my phone hotspot?** The project is evolving into a broader evidence and observability layer for local-first software, while keeping the core network-usage experience lightweight and useful on its own.

> Local-first should not only be claimed. Where technically possible, it should be observable and verifiable.

## What it does today

Traffic Monitoring currently provides network-level observability using public macOS APIs:

- continuously measures physical-interface download/upload traffic;
- attributes usage to Wi-Fi, Personal Hotspot, Ethernet, and other supported physical network contexts;
- reads Darwin 64-bit interface counters;
- enriches Wi-Fi usage with SSID identity when macOS permission allows it;
- records `isExpensive` / `isConstrained` network-path metadata;
- excludes common virtual/tunnel interfaces from physical-traffic accounting to avoid obvious VPN double counting;
- stores historical usage locally with SwiftData;
- aggregates traffic into efficient 5-minute usage buckets with periodic checkpoints;
- shows cumulative Overview analytics;
- shows time-based Trend analytics with configurable timeframe and peak detection;
- compares Usage by Network;
- keeps a separate technical Monitor for live interface diagnostics;
- runs as a native SwiftUI macOS menu-bar utility;
- can be built/tested and packaged as a downloadable `.app` through GitHub Actions.

Current analytics answer questions such as:

- How much network traffic did this Mac use today or this month?
- Which detected network accounted for the most usage?
- How much was downloaded vs uploaded?
- When did usage peak?
- How much traffic was observed on a likely phone hotspot / expensive connection?

## What it does **not** claim today

The current tracker measures **physical-interface network usage**.

It does not currently establish:

- which application generated a specific network flow;
- whether every observed byte stayed on the LAN or reached the public Internet;
- which remote destination received traffic;
- that another application is "private" or "local-only";
- exact ISP or mobile-carrier billing usage.

Local LAN transfers can be included in interface totals. The product deliberately distinguishes measured evidence from conclusions it cannot yet support.

## Strategic direction

Traffic Monitoring is not intended to become an AI runtime or a generic packet-inspection product.

Its role in a broader local-first ecosystem is **Evidence & Observability**:

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

The long-term research direction is to evaluate an **optional advanced observability mode** that could add source-application attribution and local-vs-external flow evidence without making content inspection the default.

That direction is explicitly gated by technical feasibility, macOS entitlements/system-extension requirements, distribution constraints, performance, and privacy review. It is not presented as a current capability.

See:

- [`docs/positioning.md`](docs/positioning.md) — strategic role, messaging, claims, and product principles;
- [`docs/local-first-observability-plan.md`](docs/local-first-observability-plan.md) — detailed staged evolution and go/no-go gates.

## Product principles

### Local by default

Usage history stays on the Mac. Core functionality does not require an account, cloud backend, or remote telemetry.

### Observe, don't inspect

Core analytics measure network behavior without storing packet contents, websites, DNS history, browsing history, or payloads.

### Evidence over claims

The product should show what was observed, what was inferred, and what was unavailable. Unknown or incomplete evidence is a valid state.

### Useful without advanced privileges

The core hotspot/network analytics experience must remain functional even if future advanced observability requires a separate opt-in system component.

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
                ▼
        in-memory accumulation
                │
                ├── ~15 s checkpoint
                └── 5 min usage buckets
                │
                ▼
          SwiftData local store
                │
                ▼
   Overview / Trend / Networks / Monitor
```

Future app-level observability, if accepted after a dedicated feasibility spike, should remain architecturally separate from this lightweight core.

## Run without installing Xcode

The easiest way to test the current app is to use the macOS build produced by GitHub Actions.

1. Open **Actions** → **CI** in this repository.
2. Open the latest successful run for the branch/commit you want to test.
3. Download the **TrafficMonitoring-macOS** artifact.
4. Unzip the downloaded artifact, then unzip `TrafficMonitoring.app.zip` inside it.
5. Launch `TrafficMonitoring.app`.

The development artifact is ad-hoc signed, not notarized. If macOS blocks it, follow [`docs/run-without-xcode.md`](docs/run-without-xcode.md) for the local-test steps and checksum verification.

The app runs as an `LSUIElement` menu-bar utility, so after launch look for its icon in the macOS menu bar.

## Local Xcode development

Full Xcode is optional for running the downloadable development artifact, but it remains the supported local workflow for interactive development/debugging.

The project definition is kept in `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open TrafficMonitoring.xcodeproj
```

Run the `TrafficMonitoring` scheme on macOS 14+.

## Core tests

Platform-independent tracking primitives can be tested with Swift Package Manager:

```bash
swift test
```

The package test harness intentionally keeps core counter/delta semantics deterministic without requiring a live Wi-Fi network.

## Measurement scope

The canonical current metric is bytes transferred through tracked physical network interfaces while Traffic Monitoring is running:

- **download** = received interface bytes;
- **upload** = transmitted interface bytes;
- **total used** = download + upload.

This is **network-interface usage**, not guaranteed carrier-billable Internet usage.

## Documentation

Documentation uses progressive disclosure so developers and coding agents do not need the full architecture in context for every task.

Start with:

- [`AGENTS.md`](AGENTS.md) — compact invariants and task-based document routing;
- [`docs/README.md`](docs/README.md) — documentation map;
- [`docs/implementation-plan.md`](docs/implementation-plan.md) — current core-product execution plan.

Strategic docs:

- [`docs/positioning.md`](docs/positioning.md)
- [`docs/local-first-observability-plan.md`](docs/local-first-observability-plan.md)

Technical docs:

- [`docs/product-spec.md`](docs/product-spec.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/tracking-engine.md`](docs/tracking-engine.md)
- [`docs/data-and-analytics.md`](docs/data-and-analytics.md)
- [`docs/ux.md`](docs/ux.md)
- [`docs/testing.md`](docs/testing.md)
- [`docs/decisions.md`](docs/decisions.md)

## Status note

The repository already contains persistent network analytics, but real-network reliability validation remains important before treating every measurement edge case as release-grade. The existing acceptance gates in `docs/implementation-plan.md` and `docs/m1-validation.md` remain authoritative for that work.