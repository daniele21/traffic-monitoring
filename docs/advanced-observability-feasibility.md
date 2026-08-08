# Advanced Observability feasibility — B0

Status: **GO for a signed real-Mac prototype; not yet production-accepted.**

This document records the B0 result for application-level network observability on macOS. It does not change the evidence level of the lightweight core tracker until the signed provider is activated and validated on real hardware.

## Decision

A macOS `NEFilterDataProvider` packaged as a **system extension** remains the preferred B1 prototype path.

The real macOS 15.5 SDK used by CI established the important platform-specific shape:

- `NEFilterFlow.sourceAppIdentifier` is unavailable on macOS;
- `NEFilterFlow.sourceAppAuditToken` **does compile on macOS**;
- the audit token can be passed to Security Code Signing APIs to resolve a signing identifier, falling back to `Unknown application`;
- `NEFilterNewFlowVerdict` can request low-frequency statistics reports;
- `NEFilterReport` exposes inbound/outbound byte counts inside the provider;
- `NEFilterControlProvider` is unavailable on macOS in this SDK and is not part of the design;
- a Network Extension system extension requires its own `main.swift` and `NEProvider.startSystemExtensionMode()` entry point;
- a dedicated Mach/XPC service can be declared through `NEMachServiceName` and compiled inside the system-extension process;
- the main Traffic Monitoring app now contains an XPC client for that service.

The entire capability spike — provider, audit-token identity resolution, locality classifier, statistics aggregation, system-extension entry point and XPC service — compiles in CI on the same macOS SDK as the app.

The B0 decision is therefore:

> Proceed to **signed real-Mac B1 validation**, while keeping Advanced Observability optional and experimental. Do not call application byte evidence release-grade until activation, attribution, locality, byte reconciliation, XPC security, coverage and performance gates pass.

## Architecture selected for the prototype

```text
Traffic Monitoring.app
        │
        │ NSXPCConnection
        ▼
NEMachServiceName
        │
        ▼
TrafficMonitoringFilterDataProvider.systemextension
        │
        ├── NEFilterFlow
        │     ├── sourceAppAuditToken
        │     └── remote endpoint metadata
        │
        ├── Security Code Signing APIs
        │     └── signing identifier / Unknown application
        │
        ├── deterministic locality classifier
        │     └── loopback / localNetwork / external / unknown
        │
        ├── low-frequency NEFilterReport statistics
        │     └── inbound / outbound byte counters
        │
        └── in-memory aggregation
              └── JSON snapshot over XPC
```

No packet payload is required by this architecture.

## Source application

### macOS result

Do **not** use `sourceAppIdentifier` on macOS. The compiler rejects it as unavailable.

The macOS spike instead uses:

```text
NEFilterFlow.sourceAppAuditToken
        ↓
SecCodeCopyGuestWithAttributes
        ↓
SecCodeCopyStaticCode
        ↓
SecCodeCopySigningInformation
        ↓
signing identifier
```

If any step fails, identity remains:

```text
Unknown application
```

The audit token itself is not part of the durable application evidence model.

### Still to validate

On a signed real Mac we must verify identity behavior for:

- Safari / WebKit helper processes;
- command-line processes;
- native URLSession apps;
- XPC/helper processes;
- short-lived processes;
- unsigned/ad-hoc signed apps;
- system traffic;
- VPN enabled/disabled.

Do not automatically merge helper identities into their parent app until a deterministic rule is documented.

## Locality classification

The prototype uses endpoint metadata only and never creates a DNS request solely for classification.

Current classes:

- `loopback` — loopback IPv4/IPv6;
- `localNetwork` — RFC1918 IPv4, IPv4 link-local, IPv6 link-local and unique-local addresses;
- `external` — IP literals outside those ranges;
- `unknown` — missing endpoint, hostname-only endpoint or anything that cannot be classified deterministically.

`unknown` is a first-class evidence state.

Real-Mac tests must validate the representation returned by `NEFilterSocketFlow` for TCP/UDP, IPv4/IPv6, localhost, LAN and normal Internet traffic.

## Byte accounting

For accepted flows the Data Provider requests:

```text
shouldReport = true
statisticsReportFrequency = .low
```

The provider receives statistics reports and calculates deltas from the latest reported inbound + outbound byte counts for each flow identifier.

Current product state remains:

```text
ByteAccountingCapability.notValidated
```

The Applications UI therefore treats flow counts as experimental evidence and does not present byte values as authoritative until controlled-transfer reconciliation passes.

## macOS provider-to-app communication

The initial generic design assumed a `NEFilterControlProvider`. CI proved that class is unavailable for the macOS target, so it was removed.

The macOS-specific prototype instead uses a system-extension Mach/XPC service:

```text
Info.plist
NEMachServiceName = group.com.daniele21.trafficmonitoring.advanced-observability
```

The system-extension entry point calls `NEProvider.startSystemExtensionMode()` before starting the custom XPC listener. The app uses `NSXPCConnection` to request an already-aggregated JSON snapshot.

This is intentionally one-way evidence export: the provider sends aggregate application/locality statistics, not payload content.

### Security gate

The current XPC listener is a **capability spike**. Before production it must reject callers whose code-signing identity does not match the expected Traffic Monitoring client requirement.

No release claim depends on the XPC bridge until that validation exists.

## Important macOS vs iOS sandbox distinction

Apple's general Content Filter documentation describes a very restrictive Filter Data Provider sandbox that blocks network, IPC and disk write operations. Apple DTS has clarified on the Developer Forums that this description was written before macOS filter-provider system extensions and that the quoted restriction does not apply in the same way to a macOS Network Extension system extension.

For Traffic Monitoring this means:

- do not assume iOS Data Provider architecture applies unchanged to macOS;
- validate macOS behavior on real signed builds;
- keep payloads out of IPC by product policy even if the macOS system-extension process technically permits IPC.

## Distribution / activation

Directly distributed macOS Network Extensions require additional packaging/signing work beyond the normal ad-hoc CI `.app`:

- Network Extension entitlement;
- system-extension packaging;
- Developer ID provisioning for direct distribution;
- `-systemextension` entitlement variant where required for Developer ID distribution;
- host-app system-extension installation capability;
- user approval / activation flow;
- content-filter configuration through `NEFilterManager`;
- notarized final packaging.

The existing downloadable CI app remains a safe core build. It does not pretend that an ad-hoc signature can activate the provider.

## B0 gate matrix

| Gate | Result | Notes |
|---|---|---|
| macOS Data Provider system-extension build | **GO** | compiles in CI |
| system-extension entry point | **GO** | `startSystemExtensionMode()` |
| source app primitive | **GO for prototype** | audit token, not `sourceAppIdentifier` |
| signing-identifier resolution | **GO at compile level** | real-process accuracy still needs testing |
| local/external classifier | **GO for prototype** | unknown remains explicit |
| flow statistics API | **GO at compile level** | byte reconciliation still required |
| XPC provider → app bridge | **GO at compile level** | runtime + client validation still required |
| payload-free design | **GO** | aggregate metadata only |
| base app independent | **GO** | Advanced mode remains opt-in |
| signed real-Mac activation | **OPEN** | cannot be proven by ad-hoc CI |
| attribution accuracy matrix | **OPEN** | B1 real-Mac gate |
| byte-accounting reconciliation | **OPEN** | B1 real-Mac gate |
| XPC client authentication | **OPEN** | required before production |
| provider coverage semantics | **OPEN** | required before audit conclusions |
| performance / wakeups | **OPEN** | required before always-on release |
| notarized distribution | **OPEN** | production packaging gate |

## Effect on B1

B1 may now proceed as a **signed prototype**.

Implemented prototype pieces:

- application evidence domain models;
- audit-token source identity path;
- deterministic locality classifier;
- statistics-report delta accumulation;
- in-memory per-app aggregation;
- provider XPC snapshot service;
- main-app XPC client;
- explicit stale/unavailable/unknown states.

B1 is not accepted as complete until real-Mac tests prove attribution and byte accounting.

## Effect on B2

The B2 product surface exists behind explicit opt-in:

```text
Analytics
Applications    experimental / opt-in
Monitor
```

Normal ad-hoc builds can safely show `Provider unavailable`; they never invent app rows.

When a signed provider is running, the app prefers the system-extension XPC snapshot. Byte values become authoritative only after the byte capability is promoted from `notValidated` to `validated` by the B1 gate.

## Next validation sequence

1. embed/sign the system extension in a dedicated signed development build;
2. activate it with macOS user approval;
3. configure `NEFilterManager` for socket filtering;
4. verify the XPC Mach service at runtime;
5. validate audit-token → signing-identifier mapping;
6. run controlled local / LAN / Internet transfers;
7. reconcile statistics bytes against controlled transfer sizes and core interface counters;
8. verify VPN/helper/WebKit/system-process cases;
9. measure idle CPU, wakeups and high-throughput overhead;
10. add XPC code-signing client validation;
11. only then decide whether B1/B2 are production-accepted.

## Apple references

- `NEProvider.startSystemExtensionMode()`
- `NEFilterFlow.sourceAppAuditToken`
- `NEFilterReport`
- `NEFilterNewFlowVerdict.statisticsReportFrequency`
- `NEFilterSocketFlow`
- `NEFilterProviderConfiguration.filterDataProviderBundleIdentifier`
- TN3134 — Network Extension provider deployment
- Apple Developer Forums guidance on macOS Network Extension system extensions and XPC
