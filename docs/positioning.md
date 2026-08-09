# Positioning

This document is the authoritative source for how Traffic Monitoring should be described, prioritized, and connected to the broader local-first ecosystem.

## One-line positioning

> **Local network observability for macOS.**

## Product promise

Traffic Monitoring helps people understand how their Mac uses the network: how much data moves, when it moves, and across which network contexts — while keeping usage analytics on-device.

The long-term direction is broader than a bandwidth counter. Traffic Monitoring should become an **evidence and observability layer for local-first software**, helping users and builders understand which behaviors stay local and which involve external network communication.

That future must be earned through implemented evidence. Do not describe unimplemented app-level or locality-aware capabilities as available today.

## Strategic role

Traffic Monitoring is **not** a fourth local-AI runtime pillar and should not be presented as an AI project merely because it belongs to a local-first ecosystem.

Its role is:

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

The strategic contribution is simple:

> Local-first should not only be claimed. Where technically possible, it should be observable and verifiable.

Traffic Monitoring is the network-side expression of that principle.

## Why this project exists

The original product problem remains useful and should stay visible:

> When a Mac moves between home Wi-Fi, work networks, and a phone hotspot, it is surprisingly hard to answer how much traffic was used on each network over time.

That problem creates a practical consumer utility.

The project becomes strategically stronger when it also asks:

> What evidence can a user or developer collect about how software behaves on the network without turning the product into a packet-inspection or surveillance tool?

The evolution is therefore:

```text
Network usage visibility
        ↓
Historical network analytics
        ↓
Network observability
        ↓
Optional application attribution
        ↓
Local vs external communication evidence
        ↓
Privacy / local-first audit workflows
```

Only the first stages should be described as current until later stages are implemented and validated.

## Two product audiences

Traffic Monitoring should remain useful without requiring the user to care about local AI.

### 1. Everyday Mac user

Primary question:

> Where is my network data going in aggregate, and how much am I using on each connection?

Useful outcomes:

- understand phone-hotspot consumption;
- compare usage across Wi-Fi networks;
- see download vs upload;
- inspect trends and peaks;
- keep a private local history;
- identify expensive network usage.

Primary message:

> **Understand your network usage.**

### 2. Local-first builder

Primary question:

> What network evidence can I collect about an application while testing a local-first product?

Future useful outcomes, subject to technical feasibility and explicit scope gates:

- attribute network flows to source applications;
- classify communication as loopback, local-network, or external where reliably possible;
- inspect a per-app activity timeline without storing payload contents;
- run a bounded privacy-audit session;
- export reproducible evidence for testing and documentation.

Future message:

> **See what stays local.**

Do not use this as the primary technical claim until locality-aware observability exists.

## Messaging hierarchy

### Repository title

**Traffic Monitoring**

### Primary descriptor

> **Local network observability for macOS.**

### Supporting description

> Understand how your Mac uses the network — with local history, usage by network, trends, and privacy-first analytics that stay on your device.

### Evolution statement

> Traffic Monitoring started as a way to measure usage across Wi-Fi and phone hotspots. It is evolving toward a broader observability layer for understanding and validating local-first application behavior.

### Future brand line

> **See what stays local.**

Use as a narrative line, not as evidence of a capability that has not been implemented.

## Evidence model

The project should distinguish three evidence levels.

### Level 1 — Interface evidence

Current architecture can establish:

- physical interface byte deltas;
- time of usage;
- attributed network identity/context;
- download/upload totals;
- trends and peaks;
- expensive/constrained path metadata.

This supports **network usage analytics**.

It does not establish which application created the traffic or whether traffic reached the public Internet.

### Level 2 — Flow evidence

Future opt-in architecture may establish, if a dedicated macOS flow-observability approach is technically and distribution-wise acceptable:

- source application identity;
- individual network-flow lifecycle;
- direction and protocol metadata;
- remote/local endpoint classification where available and reliable;
- aggregate bytes by application/locality category.

This supports **application network observability**.

### Level 3 — Audit evidence

Once Level 2 is proven, the product may expose bounded audit sessions such as:

```text
Application: ClosedRoom
Audit duration: 45 min
External traffic observed: 0 B
Local/LAN traffic observed: 182 MB
Unclassified traffic: 0 B
```

Wording must remain observational:

- preferred: `No external traffic detected during this audit`;
- avoid: `This app is guaranteed private`.

Traffic Monitoring can provide evidence about observed network behavior. It cannot prove every dimension of software privacy.

## Product principles

### Local by default

Traffic usage history remains on the Mac unless the user explicitly exports it.

No account or analytics backend is required for core functionality.

### Observe, do not inspect

The product should collect the minimum metadata required to answer observability questions.

Core mode must never persist:

- packet payloads;
- browsing content;
- message contents;
- full request/response bodies.

Advanced observability must be separately reviewed before collecting endpoints, hostnames, process identifiers, or other higher-sensitivity metadata.

### Evidence over claims

Show measured behavior and confidence/coverage rather than broad privacy statements.

### Useful without advanced privileges

The current network-usage product must remain useful even if the user never enables a future system extension or advanced observability mode.

### Explicit capability boundaries

The UI and docs must distinguish:

- measured;
- inferred;
- unavailable;
- unclassified.

Never silently convert incomplete evidence into a definitive privacy claim.

## Terminology

Prefer:

- `Network usage`
- `Local history`
- `Usage by network`
- `Current network`
- `Network activity`
- `Observed external traffic`
- `Observed local traffic`
- `Unclassified traffic`
- `Application attribution`
- `Audit session`

Avoid in primary UX unless technically exact:

- `Internet usage` when only physical-interface counters are known;
- `Data plan usage` when carrier billing semantics are unknown;
- `Private` as a binary verdict;
- `No cloud` without observing or controlling all relevant traffic paths;
- raw interface names such as `en0` outside Monitor/diagnostics;
- `packet inspection` as a product identity.

## Relationship to the current architecture

The existing lightweight tracker remains the product foundation:

```text
Physical interface counters
        +
Network context
        ↓
Attributed deltas
        ↓
5-minute usage buckets
        ↓
Local historical analytics
```

Future advanced observability should be a **separate optional capability**, not a retrofit that makes the base tracker privileged, fragile, or invasive.

Conceptually:

```text
Core mode                         Advanced mode (future)
---------                         ----------------------
Interface counters               Flow observability extension
Network identities               App / flow identities
Aggregate bytes                  Locality classification
Historical analytics             Per-app evidence
        │                                  │
        └──────── shared analytics/evidence layer ────────┘
```

See `local-first-observability-plan.md` for the phased technical/product plan.

## Claims we can make today

Safe current claims:

- traffic measurements and analytics are stored locally;
- the app measures physical-interface network usage;
- usage can be grouped by detected network context;
- the app does not need packet-content inspection for core analytics;
- current analytics include historical totals, trends, peaks, and network breakdowns where implemented;
- the product is designed around privacy-minimized local persistence.

Claims reserved for later evidence:

- per-application network usage;
- Internet vs LAN/loopback totals;
- external destination visibility;
- privacy audits;
- verification that another app stayed local.

## Recommended GitHub description

> Privacy-first macOS network observability: local usage history by network, evolving toward verifiable local-first app behavior.

## Recommended portfolio placement

Category:

> **Evidence & Observability**

Portfolio summary:

> A privacy-first macOS network observability tool that records local usage history across network contexts and explores how local-first software can produce verifiable network evidence without making content inspection the default.

This keeps Traffic Monitoring connected to the local-first mission without pretending that it is an AI runtime.