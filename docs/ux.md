# UX and information architecture

This document defines the v1 menu-bar and analytics experience. It does not define counter semantics; see `tracking-engine.md` and `data-and-analytics.md`.

## UX principles

- Glanceable first, detailed on demand.
- Make the current network obvious.
- Keep live-rate wording distinct from cumulative-usage wording.
- Use direct labels that answer a user question without requiring networking knowledge.
- Never imply packet inspection or exact carrier billing.
- Permission failures should degrade gracefully instead of blocking the app.
- Optimize for a utility that can remain open for months without demanding attention.

## App structure

```text
Menu bar
  ├─ Connected now
  ├─ Download now / Upload now
  ├─ Used since opening
  ├─ Open Analytics
  ├─ Settings
  └─ Quit

Analytics window
  ├─ Analytics
  │   ├─ Overview
  │   ├─ Trend
  │   └─ Networks
  └─ Monitor
      └─ Technical interface diagnostics

Settings
  ├─ General
  ├─ Privacy / Wi-Fi identification
  └─ Data
```

The technical counter table belongs under **Monitor**, not in the default analytics view.

## Copy hierarchy

Use wording that clearly separates instantaneous speed from accumulated volume.

### Live values

Preferred:

- `Connected now`
- `Download now`
- `Upload now`

These values are rates and should include `/s`.

### Accumulated values

Preferred:

- `Total used`
- `Downloaded`
- `Uploaded`
- `Used since opening`
- `Usage by network`
- `Networks used`

These values are transferred volume and must not include `/s`.

Do not expose `Raw`, `Delta`, interface names, counter semantics, or similar implementation language in the default analytics experience. Those terms are allowed only in **Monitor**.

## Menu-bar item

Default label should remain compact.

Possible default:

```text
↓ 2.3 MB/s
```

or, if screen space is limited:

```text
↕ 2.5 MB/s
```

Provide a setting to show:

- icon only;
- total current rate;
- download rate;
- current session usage.

Do not put multiple changing values into the menu-bar title by default.

## Menu-bar popover

Current hierarchy:

```text
Connected now
Home Wi-Fi

Download now       2.3 MB/s
Upload now         180 kB/s
Used since opening 1.42 GB

[ Open Analytics ]

Settings…
Quit
```

Period totals remain primarily in Analytics until the persistence UX is validated on real networks.

When `isExpensive == true`, add a restrained metadata badge such as `Likely hotspot`; do not make an absolute carrier claim.

When SSID is unavailable:

```text
Wi-Fi network
Name unavailable
```

with a secondary action such as `Enable Wi-Fi identification…` if Location permission can be requested/opened.

## Dashboard analytics

### Header

- title: `Network Usage`;
- default section: `Analytics`;
- secondary section: `Monitor`.

Inside Analytics, use three user-facing views:

- `Overview` — cumulative totals and the most-used networks;
- `Trend` — usage over time, network filtering, and peak periods;
- `Networks` — full comparison table across detected networks.

The time-period selector is shared across analytics views:

- `Today`
- `7 days`
- `30 days`
- `This month`
- `All time`
- `Custom`

`Custom` exposes direct `From` and `To` date controls.

### Summary cards

Four clear values are allowed when useful:

- `Total used`;
- `Downloaded`;
- `Uploaded`;
- `Networks used`.

In Trend, replace `Networks used` with the selected period's peak metric when useful:

- `Highest usage hour` for Today;
- `Highest usage day` for longer periods.

### Overview

Overview should answer, without interaction:

- how much data was used in the selected period?
- how much was download vs upload?
- how many networks contributed?
- which networks consumed the most?
- is history actually being saved locally?

Current supporting labels include:

- `Most used networks`
- `Saved locally`

The local-storage status is intentionally visible while persistence is still being validated so a storage failure cannot silently look like durable history.

### Usage trend

Use Swift Charts backed by persisted usage buckets.

The current chart uses transferred-volume bars rather than a throughput line. This keeps the meaning clear: bar height represents data used in that hour/day, not instantaneous network speed.

Trend supports:

- all networks together;
- one selected network;
- hourly points for Today;
- daily points for longer periods;
- a visible peak marker;
- a `Largest network spike` callout identifying the network responsible for the largest individual network/time interval.

When all networks are shown, keep each network visually distinguishable and provide a legend.

Preferred peak copy:

```text
Highest usage hour
3.4 GB
8 Aug, 14:00
```

or:

```text
Highest usage day
18.2 GB
8 Aug 2026
```

### Usage by network

Rank descending by total bytes.

Columns/row content:

```text
Network            Connection   Downloaded   Uploaded   Total used   Share   Last active
Home               Wi-Fi        12.1 GB      1.9 GB     14.0 GB      46%     8 Aug
Phone hotspot      Wi-Fi         8.8 GB      1.2 GB     10.0 GB      33%     7 Aug
Office LAN         Ethernet      5.7 GB      0.5 GB      6.2 GB      20%     6 Aug
```

On narrow layouts, keep only Network + Total used + Share and reveal detail on selection.

A small badge can identify `Likely hotspot / expensive` only when the underlying context supports that wording.

## Current persistent analytics implementation

Persistent analytics are now enabled in the development build.

The analytics views read local SwiftData history rather than only the current process session. Accepted traffic is accumulated into short time buckets and periodically checkpointed; see `data-and-analytics.md` for the exact storage semantics.

This implementation enables real testing of cumulative history across app relaunches, network changes, timeframes, trend aggregation, and per-network totals. It does **not** mean the full analytics/reliability milestones are accepted yet: the real-network M1 validation matrix, sleep/wake hardening, login launch, and remaining session-detail behavior are still pending.

If Wi-Fi identification permission is unavailable, usage remains counted but generic unnamed Wi-Fi history cannot safely be split or retroactively reassigned to named SSIDs.

## Network detail

Selecting a network should eventually open a detail destination/sheet containing:

- display alias;
- underlying SSID/connection identity when available;
- type;
- selected-period total/download/upload;
- usage-over-time chart;
- session count;
- connected duration;
- first/last seen metadata;
- rename action.

The current implementation provides network filtering in Trend and network comparison in Networks; a dedicated detail destination, session count/duration, and rename action remain pending.

For `ssid-unavailable` profiles, explain that historical traffic cannot safely be retroactively assigned to a named Wi-Fi network.

## Filters

Currently implemented:

### Period

- Today
- 7 days
- 30 days
- This month
- All time
- Custom

### Network

- All networks
- one selected network in Trend

Planned v1 filters after the current analytics surface is validated:

### Connection type

- All
- Wi-Fi
- Ethernet
- Other

### Cost metadata

Optional compact filter:

- All
- Likely hotspot only

Avoid a filter-builder UI in v1.

## Onboarding

Keep onboarding to at most a few concise steps.

### Step 1 — What the app measures

Explain:

- local network-interface traffic;
- history starts when the app is running;
- all data remains local.

### Step 2 — Wi-Fi identification permission

Explain Location permission only in terms of the feature it enables:

> macOS requires Location access to reveal the current Wi-Fi network name. The app uses it only to group traffic by Wi-Fi network and does not store your physical location.

Actions:

- `Allow Wi-Fi identification`
- `Not now`

The second action must remain fully functional with generic Wi-Fi profiles.

### Step 3 — Start at login

Recommend auto-start because history is only recorded while the app runs.

Do not hide this behavior.

## Settings

### General

- launch at login;
- menu-bar display metric;
- preferred data units if later needed.

### Privacy / network identification

- current SSID-identification permission state;
- explanation of why Location permission is needed;
- action to request/open System Settings as appropriate;
- statement that packet contents and destinations are not collected.

### Data

- local-history size estimate;
- reset all usage history with confirmation;
- export is future unless implemented.

## Empty / degraded states

### Fresh install

Dashboard should say that tracking has started and useful trends will appear as usage accumulates, while still showing live usage.

### No network

Show `Offline` and zero live rate. Keep historical dashboard usable.

### Location denied

Show traffic normally, grouped under generic Wi-Fi identities. Use direct copy:

`Traffic is being counted, but different Wi-Fi networks cannot be separated by name.`

Permission copy must not dominate the interface.

### Persistence error

This is materially different: if history cannot be saved, show a visible warning because silently displaying live traffic would imply durable tracking.

## Accessibility

- Do not encode download/upload solely by chart color.
- Add symbols/labels and accessible descriptions.
- Support Dynamic Type-equivalent macOS text scaling where SwiftUI provides it.
- Maintain keyboard navigation for dashboard controls.
- Format byte values with accessible full labels.

## Copy terminology

Preferred product-facing terms:

- `Network Usage`
- `Analytics`
- `Monitor`
- `Overview`
- `Trend`
- `Networks`
- `Connected now`
- `Download now`
- `Upload now`
- `Total used`
- `Downloaded`
- `Uploaded`
- `Used since opening`
- `Usage trend`
- `Highest usage hour`
- `Highest usage day`
- `Largest network spike`
- `Usage by network`
- `Saved locally`
- `Wi-Fi network`
- `Likely hotspot` only when uncertainty is clear

Avoid product-facing terms:

- `Raw`
- `Delta`
- `RX` / `TX`
- `Exact data usage`
- `Carrier usage`
- `Mobile plan used`

unless shown in a technical Monitor surface or a future carrier-side integration makes those statements true.
