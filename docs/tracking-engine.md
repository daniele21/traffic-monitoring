# Tracking engine

This document is authoritative for traffic measurement and attribution behavior.

## Objective

Continuously convert cumulative macOS interface counters into validated byte deltas and assign each delta to the network context in which it occurred.

The tracker must count traffic regardless of whether the Mac is connected through home Wi-Fi, office Wi-Fi, phone hotspot, Ethernet, USB tethering, or another supported physical interface.

## Key distinction: interface vs network

A physical interface is the transport endpoint exposed by macOS, for example `en0` or another `en*` interface.

A network is the context attached to that interface at a point in time, for example:

- Wi-Fi SSID `Home` on `en0`;
- Wi-Fi SSID `iPhone` on `en0`;
- Ethernet adapter `en5` at office;
- Ethernet adapter `en5` at home.

The same interface can represent different networks over time. Therefore interface counters must never be attributed only by interface name.

## Source signals

### Interface counters

Use a production implementation backed by Darwin/BSD interface statistics through public system APIs. `getifaddrs()` exposes address-family-specific `ifa_data`; for `AF_LINK` entries this contains interface statistics including received/transmitted byte counters.

Implementation requirement:

- use a 64-bit-safe representation for byte totals;
- verify the chosen Darwin structure/API against system-reported interface counters during Phase 1;
- hide the implementation behind `InterfaceCounterReader` so a different public API can replace it without touching the state machine.

Do not parse CLI output in production.

### Network path

Use `NWPathMonitor` to observe meaningful changes in network availability and default path properties.

Capture at least:

- path status;
- interface types used/available;
- `isExpensive`;
- `isConstrained`;
- path change timestamp.

`isExpensive` is useful for Personal Hotspot detection because Apple explicitly includes Cellular and Personal Hotspot among expensive paths. It remains metadata rather than a unique network identifier.

### Wi-Fi context

Use `CWWiFiClient.shared()` and interfaces vended by CoreWLAN.

Capture when available:

- BSD interface name;
- SSID;
- optional coarse radio metadata only if it later serves a concrete product need.

Do not persist BSSID by default.

Modern macOS requires Location Services authorization for SSID information. The tracker must function if SSID is nil or authorization is denied.

## Trackable interface policy

### Include by default

Candidate physical interfaces carrying user network traffic, especially:

- Wi-Fi `en*` identified via CoreWLAN/Network.framework;
- Ethernet `en*`;
- USB network adapters/tethering when exposed as physical network interfaces.

### Exclude by default

Virtual/system interfaces that can cause duplicate or irrelevant accounting:

- `lo0`;
- `utun*`;
- tunnel/VPN interfaces;
- `awdl*`;
- `llw*`;
- software bridges unless explicitly proven to be the correct physical accounting layer;
- inactive/down interfaces.

Do not rely on prefix rules alone. Build an `InterfaceClassifier` with test fixtures and combine BSD name, flags, link type, CoreWLAN mapping, and Network.framework metadata where available.

## Why VPN interfaces are excluded

With a VPN the same logical traffic can appear on both the virtual tunnel interface and the underlying Wi-Fi/Ethernet interface.

Example:

```text
application bytes
      │
      ▼
    utun5        ← encrypted/decrypted tunnel bytes
      │
      ▼
     en0         ← physical carrier bytes
```

The product goal is network consumption, so v1 counts the physical carrier interface and treats VPN presence only as optional metadata. Summing `utun5 + en0` would double count.

## Network identity model

`NetworkIdentity` must be deterministic for a given observed context but support degraded identities.

Suggested conceptual fields:

```swift
struct NetworkIdentity: Hashable, Sendable {
    let kind: NetworkKind
    let interfaceName: String
    let discriminator: String
}
```

### Wi-Fi

Preferred discriminator:

```text
wifi:<interface>:<SSID>
```

Store the SSID separately for display and allow a user alias.

When SSID is unavailable:

```text
wifi:<interface>:ssid-unavailable
```

Do not reuse the last known SSID after the system says it is unavailable; that could silently misattribute data after a network switch.

### Ethernet / wired

Interface name alone is insufficient when one adapter moves between networks.

Preferred v1 fingerprint, if reliably available from public APIs:

```text
wired:<interface>:<gateway/subnet fingerprint>
```

The implementation spike should investigate using public Network/SystemConfiguration information to derive gateway/subnet context without packet inspection or shell commands.

Fallback:

```text
wired:<interface>:unknown-network
```

Users can assign aliases. If stronger wired fingerprinting is not reliable enough for v1, document the limitation rather than using a fragile heuristic.

### Expensive/hotspot

Store `isExpensive` on sessions/buckets. A Wi-Fi profile with `isExpensive == true` can be presented as likely hotspot/costly network, but the identity remains the SSID-based network identity.

## Sampling state machine

Maintain state per trackable physical interface.

Conceptually:

```swift
enum InterfaceTrackingState {
    case noBaseline
    case tracking(Baseline)
    case suspended
}

struct Baseline {
    let counter: InterfaceCounterReading
    let context: NetworkContext
    let monotonicTimestamp: ContinuousClock.Instant
}
```

### First reading

For a new interface/context:

1. store the reading as a baseline;
2. record zero usage;
3. wait for the next valid reading.

Never interpret cumulative counters as usage since app launch.

### Normal delta

A delta is eligible when:

- same physical interface;
- same interface generation/context boundary;
- current counters are greater than or equal to previous counters;
- elapsed time is positive and within expected bounds;
- interface remains trackable.

Then:

```text
rxDelta = current.rxBytes - previous.rxBytes
txDelta = current.txBytes - previous.txBytes
```

Attribute the delta to the context covering that interval.

### Counter regression/reset

If either cumulative counter goes backwards:

- record a diagnostic event;
- discard the interval;
- establish the current reading as the new baseline.

Never use wrapping arithmetic.

### Implausible delta guard

Add a configurable sanity check based on elapsed time and a generous maximum plausible link throughput. The guard should catch corrupted readings, not police real high-speed interfaces.

If the delta is clearly impossible:

- discard it;
- log why;
- reset baseline.

The threshold must be conservative and tested.

## Context transitions

Potential triggers:

- NWPath change;
- CoreWLAN SSID-change event;
- interface appearance/disappearance;
- expensive/constrained status change if it affects profile/session metadata;
- network loss/reconnect.

On a transition:

1. request an immediate counter snapshot;
2. if the old context is still confidently known, apply the final valid delta to it;
3. flush the current bucket/session;
4. resolve the new context;
5. create a fresh baseline;
6. start a new session.

If ordering is ambiguous, discard the boundary interval rather than guessing.

## Concurrent physical interfaces

Do not assume only one physical network interface is active.

If Wi-Fi and Ethernet both transfer bytes, maintain independent baselines and attribute each physical interface separately. This is more correct than counting only the default `NWPath`.

Network.framework informs context/default routing but the byte source of truth is the physical interface counter set.

## Live throughput

Use validated deltas and actual monotonic elapsed time:

```text
downloadRate = rxDelta / elapsedSeconds
uploadRate   = txDelta / elapsedSeconds
```

Do not assume the timer fires exactly on schedule.

The UI may smooth rates for readability, but persisted usage uses unsmoothed byte deltas.

## Sleep and wake

Observe system sleep/wake notifications.

Before sleep:

- take a best-effort final sample;
- flush persistence;
- mark interface states suspended.

After wake:

- resolve interfaces and contexts again;
- take fresh counter readings;
- use them only as new baselines;
- discard the unobserved sleep interval.

This can miss traffic generated while asleep/Power Nap, but avoids falsely attributing a large unobserved delta to the post-wake network.

A later phase may explicitly investigate sleep-time accounting if it becomes a requirement.

## App quit / crash / restart

On graceful termination:

- best-effort sample;
- flush current buckets;
- close current sessions.

On crash/forced quit:

- the next launch must not calculate a delta from stale cumulative counters saved before termination;
- new process startup always establishes fresh baselines;
- stale sessions are closed/recovered using their last persisted checkpoint timestamp.

## Persistence cadence

Sampling is frequent; durable writes are not.

Initial strategy:

- sample approximately every 2 seconds;
- update current in-memory usage immediately;
- checkpoint the active usage bucket approximately every 15 seconds;
- close/split buckets at a 5-minute boundary or network transition;
- force checkpoint on sleep, meaningful path change, analytics store shutdown, and app termination.

See `data-and-analytics.md` for entities.

## Location authorization behavior

SSID is useful enough to request Location permission, but the app must explain the reason narrowly: it is used only to identify the Wi-Fi network for local usage grouping.

State handling:

- authorized → use SSID when CoreWLAN supplies it;
- not determined → onboarding may request access;
- denied/restricted → count under generic Wi-Fi identity and show a non-blocking explanation/settings action;
- CoreWLAN nil despite authorization → treat as temporarily unavailable, not as permission success/failure proof.

## Diagnostics

Emit structured local logs/events for:

- tracker start/stop;
- interface added/removed/classified;
- baseline created/reset;
- delta accepted/discarded with reason;
- network identity changed;
- SSID availability/authorization state changes;
- sleep/wake;
- persistence checkpoint failure;
- implausible delta rejection.

Logs must never contain traffic destinations or payload data.

## Validation spike before full UI

Before building the dashboard, implement a small debug surface/test harness that prints:

- included physical interfaces;
- current raw cumulative RX/TX;
- computed deltas;
- current network identity/SSID availability;
- expensive/constrained flags.

Validate controlled download/upload transfers against macOS tooling such as Activity Monitor / `netstat -ib` during development. These tools are validation references only, not production dependencies.

## Required edge-case tests

The state machine must have synthetic tests for at least:

1. first sample;
2. normal monotonic counters;
3. timer jitter;
4. network A → network B on same `en0`;
5. disconnect/reconnect same SSID;
6. counter reset;
7. interface disappears;
8. new interface appears;
9. Wi-Fi SSID becomes unavailable;
10. VPN virtual interface present alongside physical interface;
11. simultaneous Wi-Fi and Ethernet;
12. sleep/wake;
13. stale session after crash;
14. persistence checkpoint failure;
15. very large but valid transfer.
