# Advanced Observability feasibility — B0

Status: **GO for a signed real-Mac prototype; not production-accepted.**

This is the authoritative B0 platform result. Read `b0-b2-implementation-status.md` for execution status and the ADR for the architecture decision.

## Decision

Use an optional macOS `NEFilterDataProvider` packaged as a **system extension** for B1 validation.

Prototype path:

```text
Traffic Monitoring.app
        │
        │ NSXPCConnection
        ▼
NEMachServiceName
        │
        ▼
NEFilterDataProvider.systemextension
        │
        ├── sourceAppAuditToken
        ├── Security signing-identifier resolution
        ├── endpoint locality classification
        ├── low-frequency NEFilterReport statistics
        └── in-memory aggregate snapshot
```

The provider does not need packet-payload persistence.

## What CI proved against the real macOS SDK

- `NEFilterFlow.sourceAppIdentifier` is unavailable on macOS — do not use it.
- `NEFilterFlow.sourceAppAuditToken` compiles on macOS.
- Security Code Signing APIs compile for resolving a running source into a signing identifier.
- `NEFilterControlProvider` is unavailable on macOS — it is not part of this architecture.
- `NEFilterNewFlowVerdict` can request statistics reports.
- `NEFilterReport` inbound/outbound counts compile in the provider.
- a Network Extension system extension needs `NEProvider.startSystemExtensionMode()`.
- a Mach/XPC service declared with `NEMachServiceName` compiles in the system-extension process.
- the main app XPC client compiles.
- the system extension embeds into `TrafficMonitoring.app/Contents/Library/SystemExtensions` in the CI Release bundle.
- host activation/configuration code compiles using SystemExtensions + `NEFilterManager`.

Compile/package success is not runtime evidence.

## Source application

macOS prototype identity path:

```text
sourceAppAuditToken
    ↓
SecCodeCopyGuestWithAttributes
    ↓
SecCodeCopyStaticCode
    ↓
SecCodeCopySigningInformation
    ↓
signing identifier | Unknown application
```

Raw audit tokens are not part of the app evidence model and must not cross the provider boundary.

Real-Mac validation still needs Safari/WebKit, CLI tools, native apps, helpers/XPC, short-lived processes, unsigned apps, system traffic and VPN cases.

## Locality

Classes:

```text
loopback
localNetwork
external
unknown
```

Classification uses endpoint metadata and deterministic address rules. A hostname-only or otherwise ambiguous endpoint remains `unknown`; Traffic Monitoring must not trigger DNS merely to force a classification.

## Byte accounting

Provider behavior:

```text
allow flow
+ shouldReport = true
+ statisticsReportFrequency = low
```

The prototype treats report counters as cumulative per-flow values and derives deltas before per-app/locality aggregation.

Current capability remains:

```text
ByteAccountingCapability.notValidated
```

Do not promote to `validated` until controlled transfers reconcile on a signed real Mac.

## Provider → app evidence transport

The provider aggregates in memory and exposes a JSON snapshot over a dedicated Mach/XPC service.

IPC payload is limited to aggregate evidence such as:

- source signing identifier / Unknown application;
- flow counts by locality;
- aggregate byte counters;
- provider/byte-accounting state;
- observation timestamps.

It must not contain packet payloads or raw audit tokens.

Before production, the XPC listener must authenticate the connecting Traffic Monitoring client by code-signing identity.

## User activation / configuration

The host app now contains the prototype lifecycle:

1. user explicitly chooses **Install & Enable Advanced Observability**;
2. app submits `OSSystemExtensionRequest.activationRequest`;
3. macOS may require explicit user approval;
4. after activation, app loads `NEFilterManager` preferences;
5. configuration enables `filterSockets` and `filterBrowsers` and points to the embedded data-provider bundle;
6. user can disable the filter independently of core tracking.

The normal ad-hoc CI build can package the extension but is not expected to pass Apple entitlement/signature activation checks.

## Important product constraint — content-filter exclusivity

Apple documents that enabling an `NEFilterManager` configuration disables other active network content filters on the system.

Consequences:

- Advanced Observability must stay opt-in;
- activation must never happen silently at app launch;
- the UI must warn the user before enabling it;
- core Analytics must never depend on it;
- this interaction with security/filtering software is a **production acceptance gate**, not a cosmetic warning.

If this constraint makes the feature unsuitable for the intended product, B1/B2 must remain experimental or a less invasive evidence source must be researched.

## Packaging / distribution gates

Production direct distribution still requires validation of:

- Apple-granted Network Extension capability/provisioning;
- system-extension host install entitlement;
- Developer ID-appropriate Network Extension entitlement variant;
- same Team ID / valid signing relationship;
- app installed in an appropriate Applications location;
- system-extension approval/update/deactivation lifecycle;
- notarized final package;
- `NEFilterManager` permission on the intended distribution channel.

## B0 gate matrix

| Gate | Status |
|---|---|
| system-extension source/build | **GO** |
| extension embedded in app bundle | **GO** |
| macOS source-app primitive | **GO for prototype** |
| signing-identifier resolver | **GO at compile level** |
| local/external/unknown classifier | **GO for prototype** |
| flow statistics API | **GO at compile level** |
| provider → app XPC source/build | **GO at compile level** |
| host activation + filter configuration source/build | **GO** |
| payload-free architecture | **GO** |
| core independent of advanced mode | **GO** |
| explicit content-filter conflict warning | **GO** |
| signed activation on real Mac | **OPEN** |
| source-app accuracy matrix | **OPEN** |
| locality accuracy matrix | **OPEN** |
| byte reconciliation | **OPEN** |
| XPC client authentication | **OPEN** |
| provider coverage/restart semantics | **OPEN** |
| VPN/helper/WebKit behavior | **OPEN** |
| idle/high-throughput performance | **OPEN** |
| coexistence/product acceptability with other content filters | **OPEN** |
| Developer ID/notarized distribution | **OPEN** |

## Next validation sequence

1. make a properly entitled/signed development build;
2. install the app in `/Applications` and activate the embedded system extension;
3. approve it in macOS when requested;
4. enable the content-filter configuration;
5. prove XPC runtime connectivity;
6. validate audit-token → app signing identifier;
7. run controlled loopback/LAN/Internet transfers;
8. reconcile byte counts against known transfer sizes/core counters;
9. test Safari/WebKit/helpers/VPN/provider restart/app restart;
10. measure CPU, memory, wakeups and throughput overhead;
11. authenticate XPC callers;
12. evaluate content-filter exclusivity as a product/distribution constraint;
13. only then promote B1/B2 from prototype to production-accepted.

## References

Primary Apple surfaces:

- SystemExtensions — activation/deactivation and packaging
- `NEFilterManager`
- `NEFilterProviderConfiguration`
- `NEFilterFlow.sourceAppAuditToken`
- `NEFilterReport`
- `NEFilterNewFlowVerdict.statisticsReportFrequency`
- `NEFilterSocketFlow`
- TN3134 — Network Extension provider deployment
