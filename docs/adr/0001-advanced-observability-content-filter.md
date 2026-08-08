# ADR 0001 — Advanced Observability content-filter spike

Status: **Accepted as a negative production decision / retained as a capability experiment**

Date: 2026-08-08

## Context

Traffic Monitoring wants to explore optional app-level network evidence while preserving these invariants:

- the core network-usage product must remain useful without privileged components;
- payload/content persistence is not acceptable;
- source-app and locality uncertainty must stay explicit;
- advanced evidence must reach the main app through supported macOS APIs;
- the product must not become a VPN/proxy merely to satisfy portfolio positioning.

A macOS `NEFilterDataProvider` was selected for B0 because `NEFilterFlow` exposes source-app metadata and filter reports can expose flow byte counts.

## Initial proposal

The initial spike assumed:

```text
NEFilterDataProvider system extension
        ↓ reports
NEFilterControlProvider
        ↓ aggregate store
Traffic Monitoring app
```

## Evidence

The macOS SDK CI compile rejected the control-provider target because `NEFilterControlProvider` is unavailable on macOS.

Apple also documents the Filter Data Provider sandbox as blocking normal network access, IPC and disk writes. That sandbox means the Data Provider itself cannot simply write observed app-flow evidence to a shared store or send it to the host app.

The Data Provider capability itself remains useful for experimentation: source app identity and statistics can be observed inside the provider.

## Decision

Do **not** adopt the current Content Filter design as the production B1/B2 architecture.

Retain only an isolated Data Provider system-extension spike for capability/SDK checks.

Keep B1 domain models and B2 UI as experimental scaffolding with `Provider unavailable` as the correct normal-build state until a supported evidence handoff exists.

Do not add an undocumented file write, socket, IPC escape, payload log, or other workaround around the Data Provider sandbox.

## Alternatives

### Transparent proxy

Potential advantages:

- macOS deployment is supported;
- tunnel-provider family has host/provider messaging;
- provider participates directly in flows.

Concerns:

- materially more invasive traffic-path architecture;
- requires flow copying / proxy behavior for traffic it claims;
- source-app metadata is documented most clearly for per-app VPN contexts, not yet proven for our intended system-wide consumer use;
- added reliability/performance risk conflicts with the lightweight utility goal.

Decision: research later only if a focused spike proves the requirements without unacceptable product cost.

### Endpoint Security

Strong process identity, but not a general Internet socket byte-accounting API. Documented socket events focus on UNIX-domain sockets.

Decision: reject as the primary network evidence source.

### Packet filter

Can observe packets on macOS but does not directly solve reliable source-app attribution plus host evidence export.

Decision: reject as the primary B1 architecture for now.

## Consequences

Positive:

- core product remains simple and shippable;
- no false per-app claims;
- advanced UI can be designed/tested independently;
- platform blocker is visible rather than hidden.

Negative:

- B1 cannot be called end-to-end complete;
- B2 cannot show real provider data in normal builds;
- another architecture spike is required before Privacy Audit work.

## Revisit trigger

Revisit this ADR only when a supported macOS architecture can demonstrate all of:

1. system-wide or adequately scoped source-app attribution;
2. local/external/unknown classification;
3. aggregate byte accounting;
4. supported provider-to-app communication;
5. no payload persistence requirement;
6. acceptable always-on performance and distribution model.
