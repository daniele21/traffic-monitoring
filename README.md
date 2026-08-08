# Traffic Monitoring

A lightweight, privacy-first macOS menu-bar app for measuring network-interface traffic and attributing usage to the network context where it occurred.

The app continuously records download/upload usage across Wi-Fi, Personal Hotspot, Ethernet, and other supported physical connections. Historical persistence and analytics are planned after the measurement layer is validated on real macOS networks.

## Current development state

The repository is implementing **M0 — Project bootstrap** and **M1 — Measurement feasibility** from `docs/implementation-plan.md`.

Implemented in the first development slice:

- native SwiftUI macOS app skeleton;
- menu-bar utility and analytics/diagnostic window;
- public-API Darwin 64-bit interface counter reader;
- CoreWLAN Wi-Fi interface/SSID enrichment;
- `NWPathMonitor` path metadata (`isExpensive`, `isConstrained`);
- physical/virtual interface classification;
- safe cumulative-counter delta calculation;
- diagnostic table with raw counters and live deltas;
- deterministic Swift core tests;
- macOS GitHub Actions build/test workflow;
- downloadable clean Release `.app` artifact from successful CI runs.

Persistence and historical analytics are intentionally deferred until the M1 real-network validation gate passes.

## Run without installing Xcode

The easiest way to test the current app is to use the macOS build produced by GitHub Actions.

1. Open **Actions** → **CI** in this repository.
2. Open the latest successful run for the branch/PR you want to test.
3. Download the **TrafficMonitoring-macOS** artifact.
4. Unzip the downloaded artifact, then unzip `TrafficMonitoring.app.zip` inside it.
5. Launch `TrafficMonitoring.app`.

The development artifact is ad-hoc signed, not notarized. If macOS blocks it, follow [`docs/run-without-xcode.md`](docs/run-without-xcode.md) for the safe local-test steps and checksum verification.

The app runs as an `LSUIElement` menu-bar utility, so after launch look for the network icon in the macOS menu bar rather than expecting a normal main window.

## Local Xcode development

Full Xcode is optional for simply running the downloadable development build, but it is still the supported local workflow for interactive development/debugging.

The project definition is kept in `project.yml` so the generated Xcode project does not become a large, noisy source-of-truth file.

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

The package test harness intentionally compiles only `Domain/` and `Tracking/`, keeping counter/delta semantics deterministic and testable without live networking.

## Measurement scope

Traffic Monitoring measures bytes transferred by the Mac's physical network interfaces while the app is running. It does **not** inspect packet contents, websites, DNS queries, destinations, or browsing history.

Because interface counters can include local-network traffic, totals are **network usage**, not guaranteed carrier/ISP billing usage.

## Documentation

The documentation uses progressive disclosure so developers and coding agents do not need to load the full architecture for every task.

Start with:

- [`AGENTS.md`](AGENTS.md) — compact rules and task-based document routing.
- [`docs/README.md`](docs/README.md) — documentation map.
- [`docs/implementation-plan.md`](docs/implementation-plan.md) — phased execution plan.

Focused documents:

- [`docs/run-without-xcode.md`](docs/run-without-xcode.md)
- [`docs/product-spec.md`](docs/product-spec.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/tracking-engine.md`](docs/tracking-engine.md)
- [`docs/m1-validation.md`](docs/m1-validation.md)
- [`docs/data-and-analytics.md`](docs/data-and-analytics.md)
- [`docs/ux.md`](docs/ux.md)
- [`docs/testing.md`](docs/testing.md)
- [`docs/decisions.md`](docs/decisions.md)
