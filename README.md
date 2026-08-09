<p align="center">
  <img src="TrafficMonitoring/Resources/BrandAssets.xcassets/BrandShield.imageset/shield.svg" width="150" alt="Traffic Monitoring shield logo" />
</p>

# Traffic Monitoring

**Local network observability for macOS.**

Traffic Monitoring helps you understand how your Mac uses the network: **how much data moves, when it moves, across which network contexts, and — in the Applications Beta — which processes show network activity** while keeping analytics on-device.

It started from a practical question: **how much data am I actually using when my Mac connects through my phone hotspot?** It is evolving into the **Evidence & Observability** layer of a broader local-first software ecosystem without sacrificing the usefulness of the lightweight network-usage app.

> Local-first should not only be claimed. Where technically possible, it should be observable and verifiable.

## Current product

Traffic Monitoring currently provides:

- continuous physical-interface download/upload measurement;
- Wi-Fi, Personal Hotspot, Ethernet, and supported physical network-context attribution;
- Darwin 64-bit interface counters;
- Wi-Fi SSID enrichment when macOS permission allows it;
- `isExpensive` / `isConstrained` path metadata;
- local SwiftData history with efficient 5-minute usage/coverage buckets and ~15-second checkpoints;
- branded native macOS navigation: **Overview, Trends, Networks, Applications Beta, Monitor**;
- Today / 7 days / 30 days / This month / All time / Custom ranges;
- evidence quality and observation coverage;
- explicit unknown Wi-Fi identity;
- friendly network aliases and network detail;
- versioned JSON / CSV **network evidence** export;
- a best-effort **App Activity Preview** that works without an Apple Developer Program;
- an optional signed **Advanced Provider** prototype for future richer app/locality evidence;
- GitHub Actions build, tests, Release packaging, and downloadable macOS artifact.

Core Analytics answers questions such as:

- How much network traffic did this Mac use today or this month?
- Which detected network accounted for the most usage?
- How much was downloaded vs uploaded?
- When did usage peak?
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

Use **About data** in Analytics to inspect selected time, observed time, gaps, and measurement limitations.

## Reproducible network evidence export

The selected Analytics period can be previewed and saved as:

- **JSON schema v1** for structured tooling/documentation;
- **CSV** for spreadsheet workflows.

Exports include aggregate totals, coverage, evidence quality, network identity/display name, connection kind, download/upload/total, expensive/constrained flags, app/schema versions, and observation timestamps.

They deliberately exclude packet payloads, browsing content, destinations, DNS history, BSSID, and application/process identity.

See [`docs/evidence-export.md`](docs/evidence-export.md).

## Applications Beta

Applications has **two deliberately separate capability levels**.

### App Activity Preview — works without Apple Developer Program

Traffic Monitoring can sample the local macOS process network summary and show best-effort:

- process name;
- PID when available;
- downloaded bytes;
- uploaded bytes;
- total bytes;
- latest preview refresh.

This uses the local macOS `nettop` process-summary interface and does **not** require a Network Extension, system-extension installation, Developer ID, or Apple Developer Program membership.

The preview is intentionally labeled **activity preview, not privacy evidence**. It cannot determine whether traffic was loopback, LAN, or Internet, its cumulative process totals can include activity from before Traffic Monitoring opened, and it is not persisted or included in evidence export.

See [`docs/non-privileged-app-activity.md`](docs/non-privileged-app-activity.md).

### Advanced Provider — experimental signed path

The repository also contains the B0/B1/B2 prototype for richer application-flow evidence:

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

Implemented source/build surfaces include:

- embedded macOS `NEFilterDataProvider` system-extension target;
- source application identity with `Unknown application` fallback;
- deterministic Local / External / Unknown classification;
- low-frequency flow byte accounting, currently **Not validated**;
- authenticated provider → app Mach/XPC aggregate bridge;
- provider lifecycle, macOS approval/configuration states and runtime diagnostics;
- Applications provider table/detail when signed evidence exists.

All source/build/package gates pass in CI, but that is **not** equivalent to signed runtime validation.

In the normal ad-hoc downloadable build, the UI detects that Apple's system-extension install entitlement is absent and presents the Advanced Provider as **Signed build required** rather than showing an expected entitlement absence as a broken feature.

macOS also allows one enabled Network Extension content-filter configuration at a time. The signed provider therefore never enables silently and keeps core analytics/App Activity Preview independent.

See:

- [`docs/b0-b2-implementation-status.md`](docs/b0-b2-implementation-status.md)
- [`docs/advanced-observability-feasibility.md`](docs/advanced-observability-feasibility.md)
- [`docs/advanced-observability-signed-runbook.md`](docs/advanced-observability-signed-runbook.md)

## What Traffic Monitoring does **not** claim

The validated core tracker measures **physical-interface network usage**. App Activity Preview adds best-effort process totals, but neither by itself establishes:

- whether every process byte stayed on the LAN or reached the public Internet;
- which remote destination received traffic;
- complete per-app coverage;
- that an application is `local-only` or privacy-verified;
- exact ISP/mobile-carrier billing usage.

The signed Advanced Provider must not be used for stronger claims until real-Mac tests validate source-app identity, locality, byte accounting, XPC security/coverage, helper/VPN behavior, and performance.

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

Core usage history and evidence coverage stay on the Mac. No account, analytics backend, or remote telemetry is required. Export is user-initiated. App Activity Preview is sampled locally and retained only in memory.

### Observe, don't inspect

The product is designed around metadata/aggregates, not packet-content retention. The preview uses process summaries; the signed provider IPC carries aggregate evidence, not raw payloads or raw audit tokens.

### Unknown is valid

Never turn incomplete evidence into a definitive result. `Unknown network`, `Unknown application`, unknown locality, degraded coverage, and `Not validated` byte accounting are first-class states.

### Useful without advanced privileges

Overview, Trends, Networks, Monitor, history/export, hotspot analytics, and App Activity Preview remain useful when the signed system extension is absent, disabled, unapproved, or never shipped.

## Architecture

```text
                         Traffic Monitoring.app
                                  │
          ┌───────────────────────┼─────────────────────────┐
          │                       │                         │
          ▼                       ▼                         ▼
   Core network usage      App Activity Preview       Advanced Provider
   ------------------      --------------------       -----------------
   64-bit counters         local nettop summary       optional system extension
   CoreWLAN / SSID         process / PID              audit-token app identity
   NWPath metadata         cumulative bytes           flow locality/statistics
          │                       │                         │
          ▼                       ▼                         ▼
   attributed deltas       live Applications UI          authenticated XPC
          │                 (not evidence export)             │
          ▼                                                 ▼
   5-minute usage + coverage                         signed provider evidence
   ~15 s checkpoints                                  (experimental)
          │
          ▼
   SwiftData local history
          │
     ┌────┼──────────┐
     ▼    ▼          ▼
 Overview Trends   Networks / detail
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
- [`docs/ux.md`](docs/ux.md) — product information architecture
- [`docs/non-privileged-app-activity.md`](docs/non-privileged-app-activity.md) — no-entitlement process preview boundary
- [`docs/a0-a2-implementation-status.md`](docs/a0-a2-implementation-status.md) — evidence/export status
- [`docs/b0-b2-implementation-status.md`](docs/b0-b2-implementation-status.md) — signed Advanced Provider status

CI proves deterministic semantics, buildability, the non-privileged `nettop` source contract, Release packaging, and system-extension embedding. Real-Mac validation remains mandatory for network reliability and signed Advanced Provider runtime evidence.
