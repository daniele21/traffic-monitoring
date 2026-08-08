# Traffic Monitoring

A privacy-first macOS menu-bar app for measuring network-interface traffic over time and understanding **where** that traffic was used.

The app is designed to continuously record download/upload usage across Wi-Fi, Personal Hotspot, Ethernet, and other supported physical connections, then provide historical analytics grouped by network and period.

## Planned v1

- native Swift/SwiftUI macOS app;
- menu-bar live network usage;
- persistent download/upload history;
- traffic attribution by Wi-Fi network / wired connection context;
- likely Personal Hotspot identification through connection metadata;
- Today / 7D / 30D / Month analytics;
- usage-over-time charts;
- usage ranking by network;
- local network aliases;
- fully local storage;
- graceful operation when Wi-Fi SSID permission is denied;
- VPN-safe physical-interface accounting to avoid double counting;
- launch at login.

## Measurement scope

Traffic Monitoring measures bytes transferred by the Mac's physical network interfaces while the app is running. It does **not** inspect packet contents, websites, DNS queries, or browsing history.

Because interface counters can include local-network traffic, totals should be understood as **network usage**, not guaranteed carrier/ISP billing usage.

## Documentation

The project documentation uses progressive disclosure so developers and coding agents do not need to load the full architecture for every task.

Start with:

- [`AGENTS.md`](AGENTS.md) — compact rules and task-based document routing.
- [`docs/README.md`](docs/README.md) — documentation map.
- [`docs/implementation-plan.md`](docs/implementation-plan.md) — phased execution plan.

Focused documents:

- [`docs/product-spec.md`](docs/product-spec.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/tracking-engine.md`](docs/tracking-engine.md)
- [`docs/data-and-analytics.md`](docs/data-and-analytics.md)
- [`docs/ux.md`](docs/ux.md)
- [`docs/testing.md`](docs/testing.md)
- [`docs/decisions.md`](docs/decisions.md)

## Current status

Planning and architecture defined. Implementation starts with **M0 — Project bootstrap**, followed by the **M1 measurement feasibility spike**. The measurement layer must be validated before persistence and dashboard work proceed.

See [`docs/implementation-plan.md`](docs/implementation-plan.md) for acceptance gates and task checklists.
