# UX and information architecture

This document defines the current product-facing macOS experience. Counter semantics belong in `tracking-engine.md`; persistence/evidence semantics belong in `data-and-analytics.md`; the non-privileged process preview boundary belongs in `non-privileged-app-activity.md`.

## Experience goals

Traffic Monitoring should feel like a polished analytics product rather than a technical prototype.

Principles:

- glanceable first, detailed on demand;
- make the current network and selected period obvious;
- separate live rate from accumulated volume;
- use direct labels that do not require networking knowledge;
- keep the approved shield identity visible but restrained;
- use flat/native macOS surfaces even though the logo is dimensional;
- keep capability limits visible instead of turning unavailable features into mysterious errors;
- never imply packet inspection, exact carrier billing, complete app coverage, or a privacy verdict without matching evidence;
- optimize for a utility that can remain open for months without demanding attention.

## Main information architecture

```text
Traffic Monitoring
├── Overview
├── Trends
├── Networks
├── Applications   [Beta]
└── Monitor
```

The main window uses a native macOS sidebar. Analytics/evidence content is shown in the detail column.

`Monitor` is the only place where interface-level implementation detail belongs.

### Sidebar footer

Keep a small persistent status surface showing:

- current network;
- current download rate;
- current upload rate;
- Settings shortcut.

Do not turn the sidebar into a second dashboard.

## Brand application

Use the brand kit as follows:

- Midnight / Deep Navy → identity/hero framing and dark contrast;
- Royal / Network Blue → primary selected state and principal analytics series;
- Signal Cyan → live state, hotspot emphasis and meaningful peaks;
- semantic green/amber/red → status only;
- shield logo → app icon, menu-bar identity, selected identity/empty-state surfaces; do not repeat it in every card.

Product surfaces use rounded, flat cards with subtle borders/shadows and native macOS spacing. Do not reproduce the logo's bevel/gloss throughout the UI.

Reusable product components live under `TrafficMonitoring/Brand/`.

## Overview

Overview should answer immediately:

- how much data was used in the selected period?
- what network is active now?
- how much was download vs upload?
- what was the selected period's peak?
- how much of the period was actually observed?
- what is the current evidence quality?
- which networks contributed the most?
- is history being saved locally?

### Hero

The branded hero contains:

- selected period;
- `Total network usage`;
- current network;
- live download/upload rates.

Live values always include `/s`; period totals never do.

### Summary cards

Current preferred cards:

- `Downloaded`;
- `Uploaded`;
- `Highest usage hour` / `Highest usage day`;
- `Observed`.

Evidence quality appears as a dedicated status surface rather than being hidden inside About Data.

## Trends

Trends provides:

- shared period selector;
- `All networks` or one selected network;
- total/download/upload cards;
- selected-period peak;
- line chart using the brand network blue;
- Signal Cyan peak marker;
- largest network spike callout;
- evidence-quality status.

Today aggregates hourly; longer periods aggregate daily.

The chart represents transferred volume in each interval, not instantaneous throughput.

## Networks

Networks uses readable cards rather than a dense technical table as the primary presentation.

Each card can show:

- friendly display name;
- connection type;
- identity quality;
- hotspot/expensive badge when supported by macOS metadata;
- constrained badge when supported;
- total/download/upload;
- share of selected-period usage;
- last activity;
- Details action.

### Network detail

The detail sheet contains:

- total/download/upload/peak cards;
- identity quality and connection metadata;
- first/last observed timestamps;
- underlying technical identity;
- editable friendly alias;
- network-specific usage trend.

Aliases never mutate the technical network identity.

## Applications Beta

Applications intentionally presents two separate capability levels.

### 1. App Activity Preview

Available without Apple Developer Program or a privileged system component.

Shows best-effort process-level network totals while Applications is visible:

- process name;
- PID when available;
- downloaded;
- uploaded;
- total;
- latest refresh.

The UI must always say that this is an **activity preview, not privacy evidence**.

It must also explain that preview totals:

- can include activity from before Traffic Monitoring opened;
- do not distinguish loopback/LAN/Internet;
- are not persisted;
- are not included in evidence export;
- cannot prove an application is local-only.

See `non-privileged-app-activity.md` for the authoritative boundary.

### 2. Advanced Provider

The richer signed system-extension path remains visually separate.

When unavailable in an ad-hoc build, use product language such as:

> Signed provider not available in this build.

Do not show a large red setup failure for an entitlement that is intentionally absent.

When available, expose:

- provider state;
- Local / External / Unknown flows;
- byte-accounting capability;
- provider runtime diagnostics;
- application detail.

Unknown evidence remains Unknown. Byte totals stay non-authoritative until the B1 real-Mac reconciliation gate passes.

## Monitor

Monitor is explicitly a technical measurement view.

Above the technical table show:

- current network;
- download now;
- upload now;
- a concise explanation that interface totals and last-sample changes are not the same as usage attributed to a network.

Technical interface names, raw counters, and sampling deltas are allowed here but should not leak into Overview/Trends/Networks.

Preferred eventual technical labels are descriptive rather than shorthand, for example:

- `Interface total ↓`;
- `Interface total ↑`;
- `Last sample ↓`;
- `Last sample ↑`.

## Shared period controls

Analytics uses:

- Today;
- 7 days;
- 30 days;
- This month;
- All time;
- Custom.

Custom exposes direct From/To dates.

`About data` and `Export` remain visible shared actions because evidence quality and reproducibility are part of the product positioning.

## Menu-bar experience

The menu-bar item remains compact and monochrome/native.

The popover is branded but restrained:

```text
Traffic Monitoring
Current network

Download     2.3 MB/s
Upload       180 kB/s

Used since opening
1.42 GB

Open Traffic Monitoring
Settings
Quit
```

The shield may be used inside the popover; do not use a full-color dimensional icon as the menu-bar glyph itself.

## Settings

Settings uses three clear product groups:

### Tracking & data

- sampling cadence explanation;
- local-history status/behavior.

### Wi-Fi network names

- Location authorization status;
- why macOS requires Location permission for SSID;
- explicit statement that traffic still counts if permission is denied.

### Applications Beta

Split into:

**App Activity Preview**
- enable/disable;
- availability;
- live-only/persistence boundary;
- no locality claim.

**Advanced Provider**
- signed-build requirement;
- system component/provider/byte-accounting states;
- install/disable actions only if the current build actually has the required system-extension entitlement;
- content-filter coexistence warning.

An ad-hoc build must explain that the signed provider is unavailable by design, while core analytics and App Activity Preview remain usable.

## Empty / degraded states

### Fresh install

Show live values immediately and say that useful history will appear as usage accumulates.

### No network

Show `Offline` and zero live rate. Historical analytics remain available.

### Wi-Fi name unavailable

Use direct copy:

> Traffic is being counted, but different Wi-Fi networks cannot be separated by name.

### Persistence error

Show a visible warning because silently showing live values would imply durable history.

### Preview unavailable

Do not create fake process rows. Show a small unavailable state while leaving all core analytics usable.

### Signed provider unavailable

Do not use error styling when entitlement absence is expected. Reserve red/error styling for a provider that should be available but actually failed.

## Accessibility

- do not encode meaning only by color;
- pair status colors with text/icons;
- keep keyboard navigation for sidebar, pickers and actions;
- use monospaced digits for changing metrics where useful;
- allow native macOS text scaling;
- provide accessible labels for brand/decorative images;
- keep contrast readable in light and dark mode.

## Product terminology

Preferred:

- `Traffic Monitoring`;
- `Overview`;
- `Trends`;
- `Networks`;
- `Applications Beta`;
- `Monitor`;
- `Current network`;
- `Download now`;
- `Upload now`;
- `Total network usage`;
- `Total used`;
- `Downloaded`;
- `Uploaded`;
- `Observed`;
- `Data quality`;
- `App Activity Preview`;
- `Advanced Provider`;
- `Local` / `External` / `Unknown` only for the signed provider evidence source.

Avoid outside Monitor:

- `Raw`;
- `Delta`;
- `RX` / `TX`;
- interface names such as `en0`;
- `exact data usage`;
- `carrier usage`;
- `local-only` as a conclusion from App Activity Preview;
- `privacy verified` before audit semantics and validated coverage exist.
