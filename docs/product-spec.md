# Product specification

## Problem

macOS shows current network activity but does not provide a simple persistent history that answers questions such as:

- How much traffic did this Mac use today or this month?
- How much was used while connected to my phone hotspot?
- Which Wi-Fi networks account for most usage?
- How much was download versus upload?

The app should answer those questions locally, continuously, and with minimal overhead.

## Product statement

A privacy-first macOS menu-bar utility that records network-interface usage over time and attributes it to the network context in which the traffic occurred, with an analytics dashboard grouped by network and period.

## v1 user outcomes

The user can:

1. Install and launch the app without creating an account.
2. Keep it running from the menu bar.
3. See live download/upload rate and usage for the current connection.
4. See total usage for today and the current month.
5. Open a dashboard with usage over time.
6. Group/filter analytics by Wi-Fi network, Ethernet identity, connection type, and period.
7. Identify likely Personal Hotspot usage via network metadata such as `isExpensive`.
8. Rename networks with friendly aliases such as `Casa`, `Ufficio`, or `iPhone`.
9. Continue recording bytes even when SSID permission is unavailable.
10. Start automatically at login if enabled.

## What is measured

The canonical metric is bytes transferred by physical network interfaces while the app is running:

- download = received interface bytes;
- upload = transmitted interface bytes;
- total = download + upload.

This is **network-interface usage**, not guaranteed carrier-billable Internet traffic. Local LAN transfers can be included. The UI must not claim exact ISP or mobile-plan billing parity.

## Attribution

Traffic is attributed to a `NetworkProfile` representing the connection context for the physical interface.

For Wi-Fi, the preferred identity uses the current SSID plus interface context. SSID access requires Location Services authorization on modern macOS; permission denial is a normal supported state.

For wired connections, v1 should derive the strongest stable fingerprint available from public APIs (interface/service plus gateway/subnet context where reliable) and fall back to interface identity. Users can rename profiles.

For Personal Hotspot, `NWPath.isExpensive` is stored as metadata. It is a useful signal, not the sole definition of a network.

## Core screens

### Menu bar

Show a compact status plus quick metrics:

- current network name/alias;
- live rate;
- current session usage;
- today usage;
- optional current-month usage;
- open analytics;
- settings/quit.

### Analytics window

Show:

- total/download/upload for selected period;
- usage-over-time chart;
- ranked usage by network;
- network type / expensive status;
- drill-down into one network;
- filters for Today, 7D, 30D, Month, custom range;
- network aliases.

## v1 non-goals

Do not add these unless the product scope is explicitly changed:

- packet capture or payload inspection;
- browsing history, destination hosts, DNS history, or URLs;
- per-application traffic attribution;
- Network Extension / local VPN architecture;
- privileged helper or root daemon;
- cloud account, sync, or remote telemetry;
- exact reconstruction of usage before installation;
- exact carrier billing reconciliation;
- iPhone-side usage measurement;
- bandwidth throttling or firewall controls.

## Privacy position

The app is local-first by design.

Persist only information needed for usage analytics:

- timestamps;
- network profile identity/display name;
- interface/type metadata;
- byte totals;
- flags such as expensive/constrained;
- connection/session boundaries.

Do not persist packet contents, endpoints, domains, or BSSID by default.

## Performance targets

These are engineering targets, not hard external promises:

- idle CPU should remain negligible for a menu-bar utility;
- sampling must not materially affect battery life;
- memory should stay small and stable over multi-day runs;
- persistence should not write on every sample;
- dashboard queries for common periods should feel immediate with at least one year of local history.

## Success criteria for v1

v1 is ready when all of the following are true:

1. Byte totals remain monotonic and plausible across normal use.
2. Switching Wi-Fi networks creates correct attribution boundaries.
3. Ethernet and hotspot usage are represented without stopping the tracker.
4. VPN use does not cause obvious double counting.
5. Sleep/wake and counter resets do not produce synthetic usage spikes.
6. Data survives app restart and Mac restart.
7. Dashboard totals reconcile with stored usage buckets within rounding tolerance.
8. SSID permission denial still produces usable generic Wi-Fi tracking.
9. Manual validation against macOS interface counters shows acceptable agreement during controlled transfers.
10. No sensitive traffic content is collected.

## Future candidates

Possible later phases, intentionally excluded from v1:

- monthly mobile-plan budget and reset day;
- usage alerts/thresholds;
- CSV export;
- richer wired-network fingerprinting;
- optional per-app attribution using a separate, explicitly reviewed architecture;
- data retention controls;
- diagnostics bundle for bug reports.
