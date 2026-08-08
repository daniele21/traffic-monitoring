# Product specification

This document defines the **current lightweight product**. Strategic positioning lives in `positioning.md`. Future application-level/locality observability is gated by `local-first-observability-plan.md` and is not part of the current contract.

## Problem

macOS exposes current network activity but does not provide a simple persistent history that answers questions such as:

- How much network traffic did this Mac use today or this month?
- How much was used while connected to my phone hotspot?
- Which Wi-Fi networks account for most usage?
- How much was download versus upload?
- When did usage peak?
- Was the app actually observing for the whole selected period?
- How confidently was a network identified?

The app should answer those questions locally, continuously, and with minimal overhead.

There is also a broader strategic problem:

> Local-first products increasingly make claims about keeping work close to the user, but those claims are difficult to observe with simple end-user tooling.

Traffic Monitoring addresses network-level evidence today and creates a privacy-minimized foundation that may support stronger observability later.

## Current product statement

> **Local network observability for macOS:** a privacy-first menu-bar utility that records physical-interface usage over time, attributes it to network context, reports observation quality, and provides local historical analytics and user-controlled evidence export.

## Strategic direction

Traffic Monitoring belongs to an **Evidence & Observability** layer in a local-first software ecosystem.

The current product measures network-level evidence. A future optional advanced mode may evaluate source-application attribution and local-vs-external communication evidence, but only after separate platform, entitlement, privacy, performance, and distribution feasibility gates.

See `positioning.md` for messaging and `local-first-observability-plan.md` for the gated evolution plan.

## Current user outcomes

The user can:

1. Install and launch the app without creating an account.
2. Keep it running from the menu bar.
3. See live download/upload rate for current physical network usage.
4. Keep cumulative historical usage locally across relaunches.
5. See total/download/upload for a selected period.
6. View usage trends and peaks over time.
7. Compare usage grouped by detected network identity.
8. Use Today, 7 days, 30 days, This month, All time, and custom ranges.
9. Identify likely Personal Hotspot/expensive usage via `isExpensive` metadata.
10. Continue recording bytes when SSID permission is unavailable while explicitly labeling network identity as unknown.
11. See evidence quality and observation coverage for the selected period.
12. Distinguish healthy observation, metadata-degraded time, tracking-degraded time, and unobserved gaps.
13. Assign persistent friendly aliases such as `Home`, `Office`, or `iPhone` without changing canonical identity.
14. Drill into one network for total/download/upload, first/last observation, peak interval, trend, and path metadata.
15. Preview and save a versioned JSON or CSV evidence export for the selected Analytics period.
16. Use a separate technical Monitor without confusing raw counters with cumulative analytics.
17. Run without a cloud account or remote analytics backend.

## Two audiences

### Everyday Mac user

Primary need:

> Understand network usage across home Wi-Fi, hotspot, office networks, and wired connections.

The core app should remain simple and valuable for this audience indefinitely.

### Local-first builder

Primary need today:

> Collect reproducible network-level evidence while testing privacy-first/local-first applications.

Current evidence can describe observed interface/network-context behavior and coverage. It cannot yet prove source application or Internet locality.

## What is measured

The canonical current metric is bytes transferred by tracked physical network interfaces while the app is observing:

- download = received interface bytes;
- upload = transmitted interface bytes;
- total = download + upload.

This is **network-interface usage**, not guaranteed carrier-billable Internet traffic.

Local LAN transfers can be included. The UI and exports must not claim exact ISP/mobile-plan billing parity or Internet-only usage from interface counters alone.

## Evidence model

Current evidence has two dimensions.

### Usage evidence

The product can support claims about:

- measured physical-interface byte movement;
- time and period of observed usage;
- detected network context;
- download/upload totals;
- trends and peaks;
- expensive/constrained metadata when supplied by macOS.

### Coverage / quality evidence

For a selected period the product reports:

- selected duration;
- observed duration;
- healthy observation duration;
- metadata-degraded duration;
- tracking-degraded duration;
- unknown-network duration;
- unobserved duration.

Current quality states:

```text
identified
partiallyIdentified
unknownNetwork
trackingDegraded
```

Observation gaps are not filled or inferred. Sleep, process termination, crashes, or long sampling gaps remain visible as incomplete coverage.

Current evidence cannot support definitive claims about:

- source application;
- remote destination;
- public Internet vs LAN/loopback locality;
- whether another application is guaranteed local-only/private.

## Attribution

Traffic is attributed to an immutable network identity representing the connection context for the physical interface.

For Wi-Fi, the preferred identity uses the current SSID plus interface context. Permission denial is a supported state and produces an explicit unknown Wi-Fi identity.

For wired connections, current fallback identity may be interface-level when a stronger network fingerprint is unavailable. Traffic on a weaker identity is represented as partially identified evidence.

`NWPath.isExpensive` and `isConstrained` are stored as observations. They are useful path signals, not definitive network classifications.

A user alias changes presentation only. It must never rewrite or merge the canonical identity key.

## Persistence model

Current implementation:

```text
~2 s interface sampling
      ↓
validated deltas + coverage heartbeat
      ↓
in-memory accumulation
      ↓
5-minute aggregate buckets
      ↓
~15 s SwiftData checkpoints
```

Persisted current concepts:

- network profiles;
- usage buckets;
- evidence coverage buckets.

High-frequency raw samples remain ephemeral.

Coverage follows the same low-write principle as usage: heartbeat time accumulates in memory and is checkpointed in aggregate. Long gaps are capped rather than treated as observed time.

A hard crash can still lose a small interval since the last successful checkpoint. The product promises bounded local persistence, not zero-loss crash persistence.

## Core screens

### Menu bar

- current network name/alias when available;
- live download/upload rate;
- quick cumulative usage where useful;
- open Analytics;
- Settings / Quit.

### Analytics — Overview

- total used;
- downloaded;
- uploaded;
- detected network count/ranking;
- evidence quality / coverage;
- local storage status;
- selected timeframe.

### Analytics — Trend

- usage-over-time chart;
- network filter;
- highest usage hour/day;
- largest network spike;
- selected-context totals.

### Analytics — Networks

- network presentation name;
- evidence/identity quality;
- connection type;
- downloaded/uploaded/total;
- share;
- last activity;
- details action.

### Network detail

- total/download/upload;
- peak interval;
- identity quality;
- connection type;
- first/last observed;
- likely expensive/hotspot state;
- constrained state;
- trend;
- persistent alias editor.

### About this data

Explain:

- observation coverage;
- evidence quality;
- measurement scope;
- what is and is not measured;
- current claim limitations.

### Export evidence

The user can preview and locally save JSON or CSV for the selected Analytics period.

Authoritative schema: `evidence-export.md`.

### Monitor

Keep raw interface/counter diagnostics separate from product analytics.

## Current non-goals

Do not add these to the lightweight core unless scope is explicitly changed:

- packet payload capture or content inspection;
- browsing history;
- persistent destination hosts/DNS history/URLs;
- per-application traffic attribution;
- Internet-vs-LAN flow classification;
- Network Extension/content-filter architecture;
- privileged helper or root daemon;
- privacy-audit verdicts;
- cloud account, sync, or remote telemetry;
- exact reconstruction of usage before installation;
- exact carrier billing reconciliation;
- iPhone-side usage measurement;
- bandwidth throttling or firewall controls.

Per-app attribution, locality classification, and audit workflows belong to the separately gated Advanced Observability track.

## Export contract

A2 export is user-controlled and does not broaden collection.

Current schema v1 can include:

- observation period;
- aggregate total/download/upload/network count;
- evidence quality and coverage;
- canonical network identity;
- user-facing network name/alias;
- connection kind;
- per-network download/upload/total;
- `isExpensive` / `isConstrained`;
- network identity quality;
- first/last observed timestamps;
- app version;
- schema version;
- measurement-scope statement.

It must exclude by default:

- payloads;
- destinations;
- DNS/browsing history;
- BSSID;
- process/application identity;
- unrelated device metadata.

## Privacy position

The app is local-first by design.

Persist only data necessary for network-level usage, identity presentation, coverage, and evidence export. Export happens only after explicit user action.

Advanced observability may introduce higher-sensitivity metadata only after a separate privacy/data-flow review.

## Performance targets

- negligible idle CPU for a menu-bar utility;
- sampling should not materially affect battery life;
- stable memory over multi-day runs;
- no database write per sample;
- no unbounded raw sample history;
- predictable storage growth;
- common Analytics queries should feel immediate with long local history.

## Current success criteria

1. Byte totals remain monotonic and plausible across normal use.
2. Wi-Fi switches create correct attribution boundaries when identity is available.
3. Ethernet and hotspot use do not stop tracking.
4. VPN use does not cause obvious physical/tunnel double counting.
5. Sleep/wake and counter resets do not create synthetic usage spikes.
6. Usage survives app/Mac restart within documented checkpoint-loss bounds.
7. Dashboard totals reconcile with stored/pending usage buckets.
8. SSID denial produces usable explicit unknown-Wi-Fi evidence.
9. Evidence coverage does not count long observation gaps as monitored time.
10. Network aliases preserve canonical identity.
11. JSON/CSV export totals reconcile with Analytics/network totals.
12. Export contains only documented schema fields.
13. No sensitive traffic content is collected or exported.
14. UI clearly distinguishes raw technical counters from historical evidence.
15. UI does not claim per-app, external-only, or carrier-billing evidence from current sources.
16. Controlled real-Mac validation shows acceptable agreement and sensible coverage behavior.

## Remaining near-term core work

A0–A2 are implemented on the positioning branch, but release hardening still includes:

- real-Mac coverage validation across Wi-Fi/hotspot/sleep/relaunch;
- session-aware duration/count if implemented later;
- richer wired-network fingerprinting;
- data retention/reset controls;
- diagnostics bundle;
- mobile-plan budget/reset-day view if prioritized.

## Advanced observability candidates

Future only, subject to `local-first-observability-plan.md` gates:

- source-application attribution;
- local/LAN/external/unknown flow classification;
- per-app activity timeline;
- bounded audit sessions;
- application evidence export;
- optional developer/CLI workflows;
- privacy-regression testing.

These must not be inferred from physical-interface counters.
