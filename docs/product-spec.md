# Product specification

This document defines the **current lightweight product**. Strategic positioning lives in `positioning.md`. Future application-level/locality observability is gated by `local-first-observability-plan.md` and is not part of the current v1 contract.

## Problem

macOS exposes current network activity but does not provide a simple persistent history that answers questions such as:

- How much network traffic did this Mac use today or this month?
- How much was used while connected to my phone hotspot?
- Which Wi-Fi networks account for most usage?
- How much was download versus upload?
- When did usage peak?

The app should answer those questions locally, continuously, and with minimal overhead.

There is also a broader strategic problem:

> Local-first products increasingly make claims about keeping work close to the user, but those claims are difficult to observe with simple end-user tooling.

Traffic Monitoring addresses the first problem today and establishes a privacy-minimized evidence foundation that may support the second problem later.

## Current product statement

> **Local network observability for macOS:** a privacy-first menu-bar utility that records physical-interface usage over time, attributes it to network context, and provides local historical analytics by period and network.

## Strategic direction

Traffic Monitoring belongs to an **Evidence & Observability** layer in a local-first software ecosystem.

The current product measures network-level evidence. A future optional advanced mode may evaluate source-application attribution and local-vs-external communication evidence, but only after separate platform, entitlement, privacy, performance, and distribution feasibility gates.

See `positioning.md` for messaging and `local-first-observability-plan.md` for the gated evolution plan.

## Current/v1 user outcomes

The user can:

1. Install and launch the app without creating an account.
2. Keep it running from the menu bar.
3. See live download/upload rate for the current physical network usage.
4. Keep cumulative historical usage locally across relaunches.
5. See total/download/upload for a selected period.
6. View usage trends over time.
7. Inspect usage peaks for the selected timeframe.
8. Compare usage grouped by detected network identity.
9. Filter or inspect common periods such as Today, 7D, 30D, Month, All Time, and custom ranges where implemented.
10. Identify likely Personal Hotspot/expensive usage via path metadata such as `isExpensive`.
11. Continue recording bytes even when SSID permission is unavailable.
12. Use a separate technical Monitor to understand live interface measurement without confusing raw counters with cumulative analytics.
13. Run without a cloud account or remote analytics backend.
14. Start automatically at login when login-item support is implemented and enabled.

## Two audiences

### Everyday Mac user

Primary need:

> Understand network usage across home Wi-Fi, hotspot, office networks, and wired connections.

The core app should remain simple and valuable for this audience indefinitely.

### Local-first builder

Strategic need:

> Collect trustworthy network evidence while testing privacy-first/local-first applications.

Current v1 provides network-context evidence only. Per-application/locality evidence is a future, explicitly gated track.

## What is measured

The canonical current metric is bytes transferred by tracked physical network interfaces while the app is running:

- download = received interface bytes;
- upload = transmitted interface bytes;
- total = download + upload.

This is **network-interface usage**, not guaranteed carrier-billable Internet traffic.

Local LAN transfers can be included. The UI must not claim exact ISP/mobile-plan billing parity or Internet-only usage from interface counters alone.

## Evidence level

Current v1 evidence is **interface/network-context evidence**.

It can support claims about:

- measured physical-interface byte movement;
- time and period of observed usage;
- detected network context;
- download/upload totals;
- trends and peaks;
- expensive/constrained metadata when supplied by macOS.

It cannot currently support definitive claims about:

- source application;
- remote destination;
- public Internet vs LAN/loopback locality;
- whether another application is guaranteed local-only/private.

## Attribution

Traffic is attributed to a network identity representing the connection context for the physical interface.

For Wi-Fi, the preferred identity uses the current SSID plus interface context. SSID access requires Location Services authorization on modern macOS; permission denial is a normal supported state.

For wired connections, use the strongest stable fingerprint available from public APIs and fall back conservatively when identity cannot be established.

For Personal Hotspot, `NWPath.isExpensive` is stored as metadata. It is a useful signal, not the sole definition of a network.

Unknown or degraded attribution must remain explicit rather than being silently merged into stronger evidence.

## Persistence model

Current product direction:

- high-frequency counter samples stay ephemeral;
- valid deltas accumulate in memory;
- persistence checkpoints are decoupled from sampling cadence;
- usage is stored in aggregate time buckets rather than one DB row per sample;
- current implementation uses efficient five-minute usage buckets and periodic checkpoints;
- local storage is SwiftData;
- normal relaunch should retain historical analytics.

Future evidence-quality work may add coverage/health metadata without turning persistence into a high-frequency event log.

## Core screens

### Menu bar

Show compact live status and quick metrics:

- current network name/alias when available;
- live download/upload rate;
- quick cumulative usage where useful;
- open analytics;
- settings/quit.

### Analytics — Overview

Show:

- total used;
- downloaded;
- uploaded;
- number/ranking of detected networks;
- local storage status;
- selected timeframe.

### Analytics — Trend

Show:

- usage-over-time chart;
- automatic useful time granularity;
- network filter;
- highest usage hour/day for the selected range;
- largest network spike;
- download/upload totals for selected context.

### Analytics — Networks

Show:

- network name/identity;
- connection type;
- downloaded/uploaded/total;
- share of selected-period usage;
- last activity;
- likely expensive/hotspot state where applicable.

Future core work should add network drill-down and explicit evidence-quality/coverage states.

### Monitor

Keep the technical surface separate from primary analytics.

It may show:

- interface name;
- classification;
- raw cumulative RX/TX;
- latest delta;
- SSID/network context;
- path metadata;
- tracking health.

Technical labels such as raw counters or interface names should not become the main analytics vocabulary.

## Current v1 non-goals

Do not add these to the lightweight core unless product scope is explicitly changed:

- packet payload capture or content inspection;
- browsing history;
- persistent destination hosts/DNS history/URLs;
- per-application traffic attribution;
- Internet-vs-LAN flow classification;
- Network Extension / content-filter architecture;
- privileged helper or root daemon;
- privacy-audit verdicts;
- cloud account, sync, or remote telemetry;
- exact reconstruction of usage before installation;
- exact carrier billing reconciliation;
- iPhone-side usage measurement;
- bandwidth throttling or firewall controls.

Per-app attribution, locality classification, and audit workflows are not rejected permanently. They belong to the separately gated **Advanced Observability** track in `local-first-observability-plan.md`.

## Privacy position

The current app is local-first by design.

Persist only information needed for network-level usage analytics:

- timestamps/time buckets;
- network identity/display name;
- interface/type metadata;
- byte totals;
- flags such as expensive/constrained;
- connection/evidence-health metadata when justified.

Do not persist packet contents, request bodies, browsing content, or payloads.

Advanced observability may introduce higher-sensitivity metadata such as app identifiers or endpoints only after a dedicated privacy/data-flow review. The preferred design is classify/aggregate early and avoid long-term raw-flow retention.

## Performance targets

These are engineering targets, not hard external promises:

- idle CPU should remain negligible for a menu-bar utility;
- sampling must not materially affect battery life;
- memory should stay small and stable over multi-day runs;
- persistence should not write on every sample;
- no unbounded raw sample history;
- dashboard queries for common periods should feel immediate with at least one year of local history;
- storage growth should remain predictable and modest.

Any future advanced system component receives a separate performance budget and must not degrade the lightweight core experience.

## Success criteria for current v1

v1 is ready when all of the following are true:

1. Byte totals remain monotonic and plausible across normal use.
2. Switching Wi-Fi networks creates correct attribution boundaries when identity is available.
3. Ethernet and hotspot usage are represented without stopping the tracker.
4. VPN use does not cause obvious double counting.
5. Sleep/wake and counter resets do not produce synthetic usage spikes.
6. Data survives app restart and Mac restart.
7. Dashboard totals reconcile with stored usage buckets within documented rounding/range semantics.
8. SSID permission denial still produces usable generic Wi-Fi tracking.
9. Manual validation against macOS interface counters shows acceptable agreement during controlled transfers.
10. No sensitive traffic content is collected.
11. The UI clearly distinguishes live/raw technical counters from historical usage analytics.
12. The UI does not claim per-app, external-only, or carrier-billing evidence that the current data source cannot provide.

## Near-term core candidates

These strengthen evidence quality without changing the privilege model:

- network aliases;
- network drill-down;
- observation coverage / data-quality state;
- CSV export;
- versioned JSON evidence export;
- data retention controls;
- richer wired-network fingerprinting;
- diagnostics bundle for bug reports;
- mobile-plan budget/reset-day view built on a selected hotspot network.

## Advanced observability candidates

Future only, subject to the gates in `local-first-observability-plan.md`:

- source-application attribution;
- local/LAN/external/unknown flow classification;
- per-app activity timeline;
- bounded audit sessions;
- evidence export for a selected application;
- optional developer/CLI workflows;
- privacy-regression testing.

These must not be retrofitted into the core tracker by inferring semantics from physical-interface counters.