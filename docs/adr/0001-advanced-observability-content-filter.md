# ADR 0001 — Advanced Observability macOS content-filter prototype

Status: **Accepted for signed prototype validation; not yet accepted for production**

Date: 2026-08-08

## Context

Traffic Monitoring wants optional app-level network evidence while preserving these invariants:

- core network analytics remain useful without privileged components;
- payload/content persistence is not acceptable;
- source-app/locality uncertainty stays explicit;
- provider evidence reaches the main app through supported macOS mechanisms;
- activation is user-controlled;
- observability must not silently interfere with existing network/security configuration.

## Platform corrections discovered by the spike

The first cross-platform assumption was wrong in two places:

- `NEFilterControlProvider` is unavailable on macOS;
- `NEFilterFlow.sourceAppIdentifier` is unavailable on macOS.

The real macOS SDK instead supports the primitives used by the accepted prototype:

- `NEFilterFlow.sourceAppAuditToken`;
- Security Code Signing APIs for signing-identifier resolution;
- `NEFilterReport` statistics;
- `NEProvider.startSystemExtensionMode()`;
- Mach/XPC service in the system-extension process;
- main-app `NSXPCConnection` client;
- SystemExtensions activation lifecycle;
- `NEFilterManager` system-extension configuration.

## Decision

Use this architecture for **B1 signed prototype validation**:

```text
Traffic Monitoring.app
        │
        │ XPC aggregate snapshot
        ▼
com.daniele21.trafficmonitoring.filter.systemextension
        │
        ├── NEFilterDataProvider
        ├── sourceAppAuditToken
        ├── Security signing-identifier resolution
        ├── local / external / unknown classifier
        ├── low-frequency flow statistics
        └── in-memory per-app aggregation
```

The system extension is embedded in the host app bundle but Advanced Observability remains optional.

Do not use `NEFilterControlProvider` on macOS.

Do not persist packet payloads, browsing content, request bodies, or raw audit tokens.

## Activation decision

The host app may request activation only after explicit user action.

Prototype flow:

```text
user confirmation
    ↓
OSSystemExtensionRequest.activationRequest
    ↓
macOS user approval if required
    ↓
NEFilterManager configuration
    ↓
filterSockets + filterBrowsers
```

The user can disable the filter without disabling core Traffic Monitoring.

## Content-filter exclusivity

Apple documents that enabling one `NEFilterManager` content-filter configuration disables other active network content filters.

This is a material product constraint.

Decision:

- never enable Advanced Observability automatically;
- warn explicitly before enabling;
- keep core Analytics independent;
- keep coexistence with security/filtering software as a production go/no-go gate.

If this constraint is unacceptable for the intended audience, the prototype remains experimental even if source-app/byte accuracy succeeds.

## Why Content Filter remains preferred over Transparent Proxy for the prototype

Traffic Monitoring wants observability, not traffic forwarding.

A Transparent Proxy creates a larger traffic-path reliability and performance surface. The Content Filter prototype can potentially provide the required socket-flow metadata without copying application payload through Traffic Monitoring.

Transparent Proxy remains a fallback research direction only if a concrete signed B1 test proves Content Filter insufficient.

## Security consequences

Before production:

- authenticate the XPC client by code-signing identity;
- expose aggregate evidence only;
- never expose raw audit tokens over IPC;
- avoid endpoint/application activity logging in Release;
- test provider/app update and restart behavior;
- treat stale/incomplete provider evidence as degraded.

## Distribution consequences

A production provider requires more than CI compilation:

- Apple Network Extension capability/provisioning;
- system-extension installation entitlement on the host;
- Developer ID-appropriate Network Extension entitlement for direct distribution;
- matching Team ID/signing relationship;
- user approval;
- appropriate app installation location;
- `NEFilterManager` permission/configuration;
- notarization;
- update/deactivation/uninstall lifecycle.

The normal ad-hoc CI `.app` remains a core-testing artifact and must not pretend it can activate the provider.

## Acceptance before production

Promote this ADR from prototype to production only when a signed real Mac proves:

1. expected source apps map correctly from audit token;
2. helper/WebKit/system/unknown cases are documented;
3. local/external/unknown classification agrees with controlled traffic;
4. statistics byte deltas reconcile with known transfers;
5. XPC survives app/provider restart and authenticates the host;
6. provider observation coverage is measurable;
7. VPN behavior is understood;
8. CPU/wakeups/throughput overhead are acceptable;
9. activation/update/deactivation works in the intended distribution path;
10. content-filter exclusivity is acceptable for the product.

## Consequences

Positive:

- advanced observability stays separate from the lightweight core;
- payload inspection is not required;
- unknown evidence remains explicit;
- provider → XPC → UI source/build/package path is CI-verified;
- the system extension is embedded with the bundle-identifier-matching wrapper name required by macOS.

Negative:

- privileged Apple capabilities and approval are required;
- signed runtime behavior cannot be proven by GitHub's ad-hoc development artifact;
- XPC adds a security surface;
- content-filter exclusivity may conflict with existing security/filter software;
- real-Mac validation is mandatory before audit/privacy claims.
