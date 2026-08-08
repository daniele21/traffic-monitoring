# Testing strategy

This document defines how correctness is proven without requiring every test to depend on live macOS networking.

## Testing pyramid

```text
Signed real-Mac / hardware validation
               ▲
        Integration tests
               ▲
    Deterministic unit tests
```

Most tracking semantics must be deterministic. Real-network tests validate platform adapters, Apple entitlements, system-extension behavior, and assumptions that CI cannot prove.

## 1. Core domain / tracker tests

Use fake counter/context/time/repository inputs and cover:

- first reading produces no usage;
- monotonic RX/TX exact delta;
- upload-only/download-only/zero delta;
- timer jitter uses real elapsed time for rate;
- counter regression resets baseline without synthetic usage;
- implausible-delta guard;
- large `UInt64` values;
- same interface/network continuation;
- Wi-Fi A → B context boundary;
- disconnect/reconnect;
- SSID unavailable/permission denied without stale identity reuse;
- expensive/constrained metadata;
- simultaneous physical interfaces;
- virtual/tunnel exclusion;
- sleep/wake, graceful stop, relaunch boundaries.

## 2. Persistence / analytics tests

Use isolated/in-memory SwiftData where possible.

Cover:

- network-profile upsert;
- alias rename preserving immutable identity;
- five-minute usage bucket checkpoint/reconciliation;
- five-minute evidence-coverage bucket checkpoint/reconciliation;
- long observation gaps stay unobserved;
- empty data;
- numeric limits;
- totals reconcile between summary, network rows, time-series points, and export;
- JSON round-trip/schema version;
- CSV escaping.

## 3. Core real-Mac validation

Use `m1-validation.md` for the focused checklist.

At minimum exercise:

- normal Wi-Fi;
- SSID permission granted/denied;
- Wi-Fi change;
- likely hotspot/expensive path;
- Ethernet where available;
- VPN;
- sleep/wake;
- quit/relaunch;
- force-kill/relaunch;
- controlled download/upload comparison against macOS physical-interface counters.

## 4. Advanced Observability automated gates

The normal CI intentionally proves **source/build/package compatibility**, not privileged runtime activation.

CI must pass:

1. `swift test`;
2. app Debug build + Xcode tests;
3. standalone Advanced Observability system-extension build;
4. clean Release build;
5. embedded system-extension structure verification;
6. ad-hoc signing/verification for core testing;
7. artifact upload.

The Release bundle must contain:

```text
TrafficMonitoring.app/Contents/Library/SystemExtensions/
  com.daniele21.trafficmonitoring.filter.systemextension
```

CI also asserts:

- embedded `CFBundleIdentifier`;
- `NEMachServiceName`;
- host `NSSystemExtensionUsageDescription`.

Automated Advanced Observability semantics cover:

- loopback/private/public/unknown locality rules;
- hostname-only evidence remains `unknown` without DNS lookup;
- `Unknown application` remains valid;
- per-app/per-locality aggregation;
- missing byte accounting remains incomplete;
- aggregate snapshot JSON round-trip;
- installer/XPC/provider source compiles against the supported macOS SDK.

## 5. B1/B2 signed real-Mac matrix

Do **not** mark Advanced Observability production-accepted until a properly entitled/signed build passes the following.

### Activation / lifecycle

- install app in intended location;
- request system-extension activation;
- exercise macOS approval;
- enable `NEFilterManager` configuration;
- verify provider launch;
- verify XPC snapshot retrieval;
- disable filter;
- app/provider restart;
- provider update/deactivation;
- restart-required path where applicable.

### Source application

Generate controlled traffic from:

- Safari / WebKit;
- CLI (`curl` or equivalent);
- native URLSession test app;
- XPC/helper process;
- short-lived process;
- development-signed/unsigned test app;
- observable system process.

Expected:

- correct signing identifier where reliably resolvable;
- otherwise explicit `Unknown application`;
- no silent helper-to-parent merging.

### Locality

Test controlled destinations for:

- loopback IPv4/IPv6;
- private LAN IPv4;
- local IPv6/link-local where available;
- public IPv4;
- public IPv6 where available;
- hostname-only/missing endpoint representation.

Unknown cases stay unknown.

### Byte reconciliation

For repeated controlled transfers record:

- expected transfer size;
- provider inbound/outbound reports;
- derived per-flow delta;
- app/locality aggregate;
- core physical-interface delta in the same window.

Do not promote `ByteAccountingCapability` to `validated` until repeated tests show an acceptable documented relationship and no report-update double counting.

### VPN / coverage / helpers

Exercise:

- VPN off/on;
- provider restart during traffic;
- app restart while provider remains active;
- sleep/wake;
- WebKit/helper processes;
- long-lived and short-lived flows.

Define provider coverage semantics before any audit verdict work.

### Performance

Measure:

- idle CPU;
- memory;
- wakeups;
- normal browsing workload;
- sustained large transfer;
- XPC polling overhead;
- provider flow-state growth.

An always-on observability feature that materially affects networking, thermals, or battery is not acceptable.

### Security

Before production:

- authenticate XPC callers by code-signing identity;
- ensure arbitrary local processes cannot retrieve provider evidence;
- keep raw audit tokens out of IPC;
- keep endpoint/activity metadata out of Release logs;
- test app/provider version mismatch.

### Content-filter coexistence

macOS content filters are exclusive. Test with another network content filter/security product installed.

The user must see the warning before enablement. Decide explicitly whether this platform constraint is acceptable before production release.

## 6. Long-run core reliability

Before release, perform a multi-day core run including multiple sleep/wake cycles, at least two Wi-Fi networks, hotspot use, VPN toggle, app restart, disconnects, and Analytics queries.

Inspect monotonic totals, absurd buckets, DB size, CPU/wakeups, memory growth, evidence coverage, and persistence errors.

## Evidence rule

A test proves only what it observes.

Compile success proves API/build compatibility. A signed controlled runtime test proves behavior for that test matrix. Neither alone proves that another application is universally private or always local-only.
