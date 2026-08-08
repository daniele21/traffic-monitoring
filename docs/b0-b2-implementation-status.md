# B0–B2 implementation status

Compact status for the Advanced Observability track.

## B0 — Architecture and entitlement spike

Status: **capability spike implemented; production architecture blocked.**

Completed:

- [x] source-app evidence candidate validated in API surface: `NEFilterFlow.sourceAppIdentifier`;
- [x] deterministic locality contract with first-class `unknown`;
- [x] Data Provider system-extension target isolated under `experiments/advanced-observability/`;
- [x] low-frequency statistics report request compiled into the spike;
- [x] real SDK validation run through GitHub Actions;
- [x] Filter Data Provider privacy sandbox documented;
- [x] `NEFilterControlProvider` macOS blocker discovered by compiler and removed from the experiment;
- [x] content-filter-only production bridge rejected rather than simulated;
- [x] alternative transparent-proxy / Endpoint Security / packet-filter directions documented as research candidates or rejects.

Blocking gate:

- [ ] identify a supported provider-to-main-app evidence channel that preserves source-app evidence without turning the core product into an unnecessary traffic proxy.

Still open after a new architecture is identified:

- [ ] Developer ID entitlement/provisioning;
- [ ] system-extension activation/approval;
- [ ] notarized packaging;
- [ ] idle/high-throughput performance budget;
- [ ] real-Mac capability matrix.

Authority: `advanced-observability-feasibility.md`.

## B1 — Minimal app-attribution prototype

Status: **domain + provider capability prototype implemented; end-to-end app attribution blocked by B0.**

Implemented:

- [x] `FlowLocality`: loopback / localNetwork / external / unknown;
- [x] `ApplicationFlowEvidence` and per-application summary models;
- [x] source-app / locality / byte-capability states;
- [x] deterministic IP locality classifier with no extra DNS lookup;
- [x] `Unknown application` support;
- [x] isolated `NEFilterDataProvider` experimental target;
- [x] data provider requests low-frequency statistics reports while allowing traffic;
- [x] provider logs source app + byte counts only for development diagnostics;
- [x] byte values remain `notValidated` by default;
- [x] stale/incomplete evidence is modeled explicitly;
- [x] deterministic domain tests for locality, aggregation, bytes and snapshot serialization.

Not implemented / not claimed:

- [ ] supported provider → app runtime bridge;
- [ ] durable real per-app history;
- [ ] validated application byte accounting;
- [ ] validated source-app accuracy matrix;
- [ ] validated VPN/WebKit/helper behavior.

A development-only prototype snapshot reader exists so B2 UI state can be tested deterministically. It is explicitly not presented as Network Extension IPC.

## B2 — Advanced Observability product mode

Status: **experimental UI/product scaffolding implemented; real provider data intentionally unavailable in normal builds.**

Implemented:

- [x] dedicated `Applications` section shown only after explicit opt-in;
- [x] Disabled / Provider unavailable / Awaiting approval / Active / Degraded states;
- [x] Applications table with Local / External / Unknown flow evidence;
- [x] application detail view and evidence-boundary copy;
- [x] byte totals only become authoritative when capability is `validated`;
- [x] Advanced Observability Settings section;
- [x] core Analytics and Monitor remain fully usable with advanced mode off;
- [x] no fake sample applications are injected into normal builds;
- [x] normal ad-hoc CI build reports provider unavailable rather than pretending activation.

Blocked before production B2:

- [ ] B0 provider-to-app architecture;
- [ ] signed provider activation UX;
- [ ] real per-app data persistence;
- [ ] advanced retention/reset controls;
- [ ] accessibility/usability pass with real provider states;
- [ ] performance and network-safety validation.

## Claim boundary

Safe branch claim:

> Traffic Monitoring includes an experimental Advanced Observability UI, domain model, and macOS Filter Data Provider capability spike. B0 found that the current Content Filter architecture cannot yet deliver provider evidence to the main app through a supported channel, so normal builds do not claim real per-app analytics.

Unsafe claims:

- `Traffic Monitoring measures per-app traffic in the downloadable build.`
- `Traffic Monitoring verifies that an app is local-only.`
- `Application byte totals are validated.`
