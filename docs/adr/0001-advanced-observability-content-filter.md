# ADR 0001 — Advanced Observability macOS content-filter prototype

Status: **Accepted for signed prototype validation; not yet accepted for production**

Date: 2026-08-08

## Context

Traffic Monitoring wants optional app-level network evidence while preserving these invariants:

- the core network-usage product remains useful without privileged components;
- payload/content persistence is not acceptable;
- source-app and locality uncertainty stay explicit;
- advanced evidence reaches the main app through supported macOS mechanisms;
- the product should not become a VPN/proxy unless the evidence requirements genuinely demand it.

## Initial assumption and correction

The first spike assumed a cross-platform content-filter architecture:

```text
NEFilterDataProvider
        ↓
NEFilterControlProvider
        ↓
Traffic Monitoring app
```

The real macOS SDK rejected `NEFilterControlProvider` as unavailable on macOS. It also rejected `sourceAppIdentifier` on `NEFilterFlow`.

Those failures were useful platform evidence, not reasons to abandon the Content Filter approach.

Further macOS-specific validation established that:

- `sourceAppAuditToken` is available to the macOS Filter Data Provider;
- Security Code Signing APIs compile for resolving the running code into a signing identifier;
- flow statistics reporting compiles;
- a Network Extension system extension uses `NEProvider.startSystemExtensionMode()`;
- a custom `NEMachServiceName` / `NSXPCListener` bridge compiles in the same system-extension process;
- the main app can compile an `NSXPCConnection` client for that service.

Apple DTS has also clarified that older restrictive-sandbox language for Filter Data Providers was written before macOS system-extension providers and does not describe macOS behavior unchanged.

## Decision

Use the following architecture for **B1 signed prototype validation**:

```text
Traffic Monitoring.app
        │
        │ XPC snapshot request
        ▼
Network Extension system extension
        │
        ├── NEFilterDataProvider
        ├── sourceAppAuditToken
        ├── Security signing-identifier resolution
        ├── local/external/unknown classifier
        ├── low-frequency flow statistics
        └── in-memory aggregation
```

Do not use `NEFilterControlProvider` on macOS.

Do not persist packet payloads, request bodies, browsing content or raw audit tokens.

Provider → app IPC carries only the aggregate snapshot required by the Applications view.

## Why Content Filter remains preferred over a Transparent Proxy

The desired product is observability, not traffic forwarding.

A Transparent Proxy would make Traffic Monitoring participate more deeply in the traffic path and create a larger reliability/performance surface. The Content Filter prototype can potentially provide the required socket-flow metadata without copying application payload through our process.

Transparent Proxy remains a fallback research direction only if the signed Content Filter prototype cannot meet source-app, byte-accounting or IPC requirements.

## Why Endpoint Security is not the primary source

Endpoint Security is valuable for process identity but is not the selected general Internet socket byte-accounting source for this product.

It may later be considered as an optional identity-enrichment source only if a concrete gap justifies the additional entitlement and complexity.

## Security consequences

The XPC service is currently a B0 capability implementation. Before production:

- validate the connecting client code-signing identity;
- ensure the service cannot be used by arbitrary local processes to extract evidence;
- expose aggregates only;
- never expose raw audit tokens over IPC;
- avoid verbose logging of endpoints or application activity in release builds.

## Distribution consequences

A production provider requires more than CI compilation:

- Network Extension entitlement/provisioning;
- system-extension installation entitlement on the host;
- Developer ID appropriate Network Extension entitlement for direct distribution;
- user approval;
- `NEFilterManager` configuration;
- notarization;
- update/uninstall lifecycle.

The normal ad-hoc CI `.app` must remain usable for core tracking even when none of those are available.

## Acceptance before production

This ADR is promoted from prototype to production only when a real signed Mac proves:

1. expected source applications map correctly from audit token;
2. helper/WebKit/system/unknown cases are documented;
3. local/external/unknown classification agrees with controlled traffic;
4. statistics byte deltas reconcile with controlled transfers;
5. XPC survives app/provider restart and authenticates the host app;
6. provider coverage can be measured;
7. VPN behavior is understood;
8. idle CPU/wakeups and high-throughput overhead are acceptable;
9. activation/update/uninstall works in the intended distribution path.

## Consequences

Positive:

- keeps advanced observability separate from the lightweight core;
- avoids payload inspection by design;
- allows explicit unknown states;
- compiles end-to-end through the intended provider → XPC → UI boundary;
- does not force a proxy architecture prematurely.

Negative:

- requires privileged Apple capabilities and user approval;
- cannot be fully validated in ad-hoc GitHub Actions;
- adds a second process and IPC security surface;
- real-Mac validation is mandatory before any privacy-audit claim.
