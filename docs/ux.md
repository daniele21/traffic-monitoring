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
  ├─ Used since opening / period totals
  ├─ Open Analytics
  ├─ Settings
  └─ Quit

Analytics window
  ├─ Analytics
  │   ├─ Total used / Downloaded / Uploaded
  │   ├─ Usage by network
  │   └─ Network detail
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

Suggested hierarchy:

```text
Network Usage

Connected now
Home Wi-Fi

Download now       2.3 MB/s
Upload now         180 kB/s
Used since opening 1.42 GB

Today              3.81 GB
This month         18.7 GB

[ Open Analytics ]

Settings…
Quit
```

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
- secondary section: `Monitor`;
- once persistence is enabled, period picker: Today / 7 days / 30 days / This month / Custom.

### Summary cards

Four clear values are allowed when useful:

- `Total used`;
- `Downloaded`;
- `Uploaded`;
- `Networks used`.

Once persistent analytics are available, `Networks used` can move out if a more useful period metric replaces it.

### Usage over time

Use Swift Charts once persistent time buckets are available.

Default series:

- stacked or grouped download/upload bars for daily/hourly usage; or
- total bars with download/upload available as a display toggle.

Prefer bars for transferred volume. A line chart visually suggests a continuous rate and is less appropriate for interval totals unless explicitly showing throughput.

Chart tooltip/selection should show:

```text
8 Aug
Total used 3.4 GB
Downloaded 2.9 GB
Uploaded 0.5 GB
```

### Usage by network

Rank descending by total bytes.

Columns/row content:

```text
Network            Connection   Downloaded   Uploaded   Total used   Share
Home               Wi-Fi        12.1 GB      1.9 GB     14.0 GB      46%
iPhone             Wi-Fi         8.8 GB      1.2 GB     10.0 GB      33%
Office LAN         Ethernet      5.7 GB      0.5 GB      6.2 GB      20%
```

On narrow layouts, keep only Network + Total used + Share and reveal detail on selection.

A small badge can identify `Likely hotspot` only when the underlying context supports that wording.

## Current M1 analytics scaffold

Before persistent history is enabled, the analytics screen may show an in-memory validation summary grouped by network identity. It must be explicitly labeled as data **since the app was opened** and must not imply that Today/Month history survives a relaunch.

This scaffold exists to validate that accepted deltas are attributed to the expected Wi-Fi/network identity before persistence is built. It does not satisfy the M5 analytics milestone.

## Network detail

Selecting a network opens a detail destination/sheet containing:

- display alias;
- underlying SSID/connection identity when available;
- type;
- selected-period total/download/upload;
- usage-over-time chart;
- session count;
- connected duration;
- first/last seen metadata;
- rename action.

For `ssid-unavailable` profiles, explain that historical traffic cannot safely be retroactively assigned to a named Wi-Fi network.

## Filters

v1 filters:

### Period

- Today
- 7 days
- 30 days
- This month
- Custom

### Network

- All networks
- one or more profiles if UI complexity remains reasonable

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
- `Connected now`
- `Download now`
- `Upload now`
- `Total used`
- `Downloaded`
- `Uploaded`
- `Used since opening`
- `Usage by network`
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
