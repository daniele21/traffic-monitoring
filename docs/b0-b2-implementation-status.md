# B0–B2 implementation status

Compact status for the Advanced Observability track.

## B0 — Architecture and entitlement spike

Status: **GO for a signed real-Mac prototype; production acceptance still gated.**

Implemented and CI-verified:

- [x] macOS `NEFilterDataProvider` system-extension target;
- [x] explicit system-extension `main.swift` using `NEProvider.startSystemExtensionMode()`;
- [x] `sourceAppIdentifier` rejected as unavailable on macOS rather than hidden behind a false abstraction;
- [x] `sourceAppAuditToken` accepted by the macOS SDK;
- [x] audit-token → Security Code Signing → signing-identifier resolver;
- [x] deterministic locality model with first-class `unknown`;
- [x] low-frequency `NEFilterReport` statistics request;
- [x] in-memory flow/app/locality aggregation;
- [x] `NEFilterControlProvider` removed after the real SDK proved it unavailable on macOS;
- [x] system-extension `NEMachServiceName`;
- [x] NSXPC listener inside the system extension;
- [x] main-app NSXPC client;
- [x] provider returns only aggregate JSON evidence, never packet payload;
- [x] entire spike builds unsigned in GitHub Actions against the same macOS SDK as the app.

Still required before production acceptance:

- [ ] embed/sign the provider in a Developer ID development build;
- [ ] activate/approve it on a real Mac;
- [ ] configure `NEFilterManager` for socket filtering;
- [ ] prove XPC runtime connectivity;
- [ ] validate XPC caller code-signing identity before accepting clients;
- [ ] real-Mac source-app capability matrix;
- [ ] byte-reconciliation tests;
- [ ] VPN/WebKit/helper/system-process coverage;
- [ ] idle/high-throughput performance budget;
- [ ] notarized distribution flow.

Authority: `advanced-observability-feasibility.md`.

## B1 — Minimal app-attribution prototype

Status: **implementation prototype complete enough for signed real-Mac validation; evidence is not release-validated.**

Implemented:

- [x] `FlowLocality`: loopback / localNetwork / external / unknown;
- [x] `ApplicationFlowEvidence` and per-application summary models;
- [x] application/locality/byte-capability provider states;
- [x] deterministic IP locality classifier with no classification-only DNS lookup;
- [x] `Unknown application` support;
- [x] audit-token signing-identifier resolution inside the provider;
- [x] flow registration by stable `NEFilterFlow.identifier`;
- [x] low-frequency statistics reports while traffic is allowed;
- [x] cumulative-report → per-flow delta accounting;
- [x] per-locality byte accumulation;
- [x] in-memory aggregation before provider → app IPC;
- [x] XPC JSON snapshot contract matching main-app domain models;
- [x] main app prefers XPC evidence when available;
- [x] stale provider snapshots become `degraded`;
- [x] bytes remain `notValidated` by default;
- [x] deterministic domain tests for locality, aggregation, byte fields and snapshot serialization.

Real-Mac acceptance remains open:

- [ ] signing identifier agrees with controlled source applications;
- [ ] localhost/LAN/external classes agree with controlled destinations;
- [ ] statistics byte deltas reconcile with controlled transfers;
- [ ] no double counting across report updates;
- [ ] XPC reconnect behaves across provider/app restart;
- [ ] WebKit/helper/VPN/system traffic limitations are documented;
- [ ] unobservable cases remain explicit.

There is still no durable per-app history in SwiftData. That should be added only after the live evidence source passes these gates.

## B2 — Advanced Observability product mode

Status: **opt-in product surface implemented; signed-provider activation and real data validation remain open.**

Implemented:

- [x] dedicated `Applications` section shown only after explicit opt-in;
- [x] Disabled / Provider unavailable / Awaiting approval / Active / Degraded states;
- [x] Applications table with Local / External / Unknown flow counts;
- [x] per-application detail view;
- [x] byte values withheld from authoritative presentation while capability is `notValidated`;
- [x] Advanced Observability Settings section;
- [x] provider/bridge/byte-accounting status visible to the user;
- [x] system-extension XPC is the preferred evidence path;
- [x] developer file snapshot exists only as deterministic UI fallback;
- [x] core Analytics and Monitor remain fully usable with advanced mode off;
- [x] no fake application rows are injected into normal builds;
- [x] normal ad-hoc CI build reports provider unavailable rather than pretending system-extension activation;
- [x] brand system applied to app shell, menu bar, accent and advanced-status surfaces.

Still blocked before production B2:

- [ ] signed provider installation/approval action in the shipping build;
- [ ] `NEFilterManager` enable/disable lifecycle;
- [ ] real per-app persisted buckets after B1 validation;
- [ ] advanced retention/reset controls;
- [ ] secure XPC caller validation;
- [ ] accessibility/usability pass with real provider states;
- [ ] performance/network-safety validation;
- [ ] final distribution/notarization path.

## Claim boundary

Safe branch claim:

> Traffic Monitoring now contains an opt-in Advanced Observability prototype: a macOS Filter Data Provider system extension, audit-token application identity path, local/external/unknown classification, aggregate flow statistics, an XPC bridge, and an Applications UI. The complete source builds in CI, but real per-app evidence remains experimental until a signed system extension is activated and validated on a Mac.

Unsafe claims:

- `Traffic Monitoring measures validated per-app traffic in the downloadable ad-hoc build.`
- `Traffic Monitoring verifies that an app is local-only.`
- `Application byte totals are validated.`
- `No external traffic` without complete provider coverage and the later audit semantics gate.
