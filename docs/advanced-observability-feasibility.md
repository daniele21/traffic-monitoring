# Advanced Observability feasibility — B0

Status: **capability spike GO; production content-filter architecture NO-GO pending a supported evidence handoff.**

This document records the B0 result for application-level network observability on macOS. It does not change the evidence level of the lightweight core tracker.

## Decision

Apple's macOS Content Filter APIs are useful for proving two important capabilities inside a Filter Data Provider:

- `NEFilterFlow.sourceAppIdentifier` can identify the application associated with an observed flow when available;
- `NEFilterReport` / statistics reporting can expose inbound and outbound byte counts to the provider.

However, the originally proposed production path cannot currently satisfy Traffic Monitoring's product requirement of durable, app-visible evidence:

1. the Filter Data Provider runs in a restrictive sandbox that blocks normal network access, IPC and disk writes;
2. the real macOS SDK used by CI marks `NEFilterControlProvider` unavailable on macOS, so the generic Data Provider → Control Provider → shared store design cannot be used as our macOS evidence-export bridge;
3. therefore app attribution may be observable **inside** the data provider, but this B0 spike has not identified a supported, privacy-preserving channel that makes those observations available to the containing Traffic Monitoring app.

The correct B0 decision is consequently:

> Keep the content-filter target as an isolated capability experiment, keep B1/B2 domain/UI scaffolding experimental, and do not ship or advertise app-level observability until a supported macOS provider-to-app architecture is proven.

## What is technically proven enough for prototyping

### Source application

`NEFilterFlow.sourceAppIdentifier` exposes a source-app identifier for a flow when available. Missing identity must remain `Unknown application`.

### Locality

The experimental domain classifier uses only deterministic IP-literal rules:

- loopback: `127.0.0.0/8`, `::1`, localhost;
- local network: RFC1918 IPv4, IPv4 link-local, IPv6 link-local and unique-local ranges;
- external: IP literals outside those ranges;
- unknown: missing endpoint, hostname-only endpoint, or anything that cannot be classified without creating extra network/DNS activity.

No DNS request is created merely to classify a flow.

### Statistics

The Data Provider can request low-frequency statistics reports. These reports can contain inbound and outbound flow byte counts. This is useful for a controlled B1 experiment, but byte accounting remains `notValidated` until it can be reconciled against controlled transfers and delivered through a supported host-app architecture.

## Platform boundary discovered by CI

The B0 spike deliberately compiles against the same macOS SDK as the app CI.

That validation produced a decisive platform result:

```text
'NEFilterControlProvider' is unavailable in macOS
```

This result takes precedence over a generic documentation diagram that describes Data and Control Providers together across platforms.

The experiment therefore contains only the macOS Filter Data Provider system-extension target.

## Data Provider privacy sandbox

Apple documents the Filter Data Provider as intentionally unable to export observed user network content through normal mechanisms: its sandbox blocks network access, IPC and disk writes.

This is a good privacy property, but it means Traffic Monitoring must not invent an unsupported bridge just to make B2 work.

## Alternatives considered after the blocker

### Transparent proxy

A transparent proxy can run on macOS and, as a tunnel-provider family API, has a host/provider messaging channel. It is materially more invasive because the provider participates in the traffic path and flow copying. Apple also documents source-app `NEFlowMetaData` primarily in per-app VPN contexts, so system-wide source attribution for our use case is not yet established.

Decision: **research candidate only**, not adopted as a workaround.

### Endpoint Security

Endpoint Security provides strong process identity but Apple documents its socket events as UNIX-domain-socket events, not general Internet socket byte accounting.

Decision: **not suitable as the primary traffic evidence source**.

### Packet filter

A packet filter can observe packets on macOS but does not by itself solve reliable source-application attribution and the host evidence handoff.

Decision: **not selected**.

## B0 gate matrix

| Gate | Result | Notes |
|---|---|---|
| Source app identity inside provider | GO for prototype | explicit unknown remains required |
| Local/external deterministic classification | GO for IP literals | hostname/missing endpoint stays unknown |
| Flow statistics available inside provider | GO for experiment | accounting not release-validated |
| Payload persistence avoidable | GO | provider need not inspect/store payloads |
| Base app independent | GO | advanced track remains optional |
| macOS Data Provider packaging | GO for spike | system extension |
| Supported provider → host evidence bridge | **NO-GO** | current blocking item |
| Per-app durable analytics | **BLOCKED** | depends on supported bridge |
| Real-Mac performance | OPEN | cannot accept release gate yet |
| Signing/notarization/approval | OPEN | ad-hoc CI cannot prove activation |

## Effect on B1 and B2

B1 may contain platform-independent domain models, deterministic locality rules and the isolated Data Provider capability spike. It must not claim that the normal app receives real provider evidence.

B2 may contain the opt-in `Applications` UI and provider-state UX so the product path is testable. In regular builds it must show `Provider unavailable` rather than fake application rows.

The `Applications` UI may only show authoritative byte values after:

1. a supported provider-to-app evidence channel is selected;
2. real source-app/locality tests pass;
3. byte accounting reconciles under controlled traffic;
4. coverage and stale-provider semantics are validated;
5. distribution/approval/performance gates pass.

## Next B0 research question

The next architecture spike is narrowly defined:

> Is there a supported macOS Network Extension architecture that provides system-wide source-application flow metadata, aggregate byte accounting, and a supported host-app communication path without forcing Traffic Monitoring to become a full traffic proxy?

Until that is answered positively, the product remains a strong network-level observability tool and Advanced Observability remains experimental scaffolding.

## Apple references

- https://developer.apple.com/documentation/networkextension/nefilterflow/sourceappidentifier
- https://developer.apple.com/documentation/networkextension/nefilterreport
- https://developer.apple.com/documentation/networkextension/nefilternewflowverdict/statisticsreportfrequency
- https://developer.apple.com/documentation/networkextension/nefilterprovider
- https://developer.apple.com/documentation/networkextension/nefilterproviderconfiguration/filterdataproviderbundleidentifier
- https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
- https://developer.apple.com/documentation/networkextension/netransparentproxyprovider
- https://developer.apple.com/documentation/networkextension/neflowmetadata
