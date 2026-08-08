# B0–B2 implementation status

Compact status for the Advanced Observability track.

## B0 — Architecture and entitlement spike

Status: **GO for a signed real-Mac prototype; production acceptance still gated.**

Implemented and CI-verified:

- [x] macOS `NEFilterDataProvider` system-extension target;
- [x] system-extension entry point using `NEProvider.startSystemExtensionMode()`;
- [x] `sourceAppIdentifier` rejected as unavailable on macOS;
- [x] `sourceAppAuditToken` accepted by the macOS SDK;
- [x] audit-token → Security Code Signing → signing-identifier resolver;
- [x] deterministic loopback / localNetwork / external / unknown model;
- [x] low-frequency `NEFilterReport` statistics request;
- [x] in-memory flow/app/locality aggregation;
- [x] `NEFilterControlProvider` removed after the macOS SDK proved it unavailable;
- [x] system-extension `NEMachServiceName` + NSXPC listener;
- [x] main-app NSXPC client;
- [x] XPC client authentication implemented: expected host identifier + valid signature + matching non-empty Team ID;
- [x] ad-hoc/no-Team-ID XPC clients fail closed;
- [x] aggregate JSON IPC only; no packet payload/raw audit token IPC;
- [x] provider runtime diagnostics: protocol version, provider start, active flows, observed flows, snapshot timestamp;
- [x] closed-flow state is released after the final cumulative report delta;
- [x] provider target embedded in the main `.app` under `Contents/Library/SystemExtensions`;
- [x] host activation lifecycle with SystemExtensions framework;
- [x] `NEFilterManager` socket/browser filter configuration;
- [x] enable/disable lifecycle;
- [x] explicit warning that enabling this content filter can disable another active content filter;
- [x] signed-bundle preflight script for structure/signature/Team-ID/entitlement checks;
- [x] unsigned SDK/build/package path passes GitHub Actions.

Still required before production acceptance:

- [ ] Developer ID / Apple capability provisioning for the host and provider;
- [ ] signed activation/approval on a real Mac;
- [ ] prove authenticated XPC runtime connectivity;
- [ ] negative runtime XPC test from a non-host process;
- [ ] real-Mac source-app/locality capability matrix;
- [ ] byte-reconciliation tests;
- [ ] VPN/WebKit/helper/system-process coverage;
- [ ] idle/high-throughput performance budget;
- [ ] coexistence/product acceptability with other content filters;
- [ ] notarized distribution/update/uninstall flow.

Authority: `advanced-observability-feasibility.md`.
Operational signed validation: `advanced-observability-signed-runbook.md`.

## B1 — Minimal app-attribution prototype

Status: **source implementation complete enough for signed real-Mac validation; evidence is not release-validated.**

Implemented:

- [x] `FlowLocality`: loopback / localNetwork / external / unknown;
- [x] `ApplicationFlowEvidence` and per-application summary models;
- [x] application/locality/byte-capability states;
- [x] `Unknown application` support;
- [x] deterministic locality rules without classification-only DNS lookup;
- [x] audit-token signing-identifier resolution inside the provider;
- [x] flow registration by `NEFilterFlow.identifier`;
- [x] low-frequency statistics reports while traffic is allowed;
- [x] cumulative-report → per-flow delta accounting;
- [x] final `.flowClosed` delta handling and active-flow cleanup;
- [x] per-locality byte accumulation;
- [x] in-memory aggregation before provider → app IPC;
- [x] XPC JSON snapshot contract matching main-app domain models;
- [x] backward-compatible optional provider diagnostic fields in the snapshot contract;
- [x] main app prefers real XPC evidence when available;
- [x] stale snapshots become `degraded`;
- [x] bytes remain `notValidated` by default;
- [x] deterministic domain tests for locality, aggregation, byte fields, diagnostics and snapshot serialization.

Real-Mac B1 acceptance remains open:

- [ ] signing identifier agrees with controlled source applications;
- [ ] localhost/LAN/external classes agree with controlled destinations;
- [ ] statistics byte deltas reconcile with controlled transfers;
- [ ] no double counting across report updates / final close report;
- [ ] XPC reconnect behaves across provider/app restart;
- [ ] WebKit/helper/VPN/system traffic limitations are documented;
- [ ] unobservable cases remain explicit.

There is intentionally no durable per-app SwiftData history yet. Add it only after the live evidence source and provider-restart semantics pass B1 validation.

## B2 — Advanced Observability product mode

Status: **opt-in product mode implemented for prototype use; signed-provider runtime validation remains open.**

Implemented:

- [x] dedicated `Applications` section shown only after explicit opt-in;
- [x] Disabled / Provider unavailable / Awaiting approval / Active / Degraded states;
- [x] Applications table with Local / External / Unknown flow evidence;
- [x] per-application detail view;
- [x] byte values withheld from authoritative presentation while capability is `notValidated`;
- [x] provider runtime diagnostics shown in the Applications status surface;
- [x] Advanced Observability Settings section;
- [x] embedded system-extension activation action;
- [x] macOS approval state surfaced;
- [x] `NEFilterManager` enable/disable lifecycle;
- [x] explicit confirmation before enabling because macOS content filters are exclusive;
- [x] restart-required state;
- [x] provider / bridge / byte-accounting status visible;
- [x] system-extension XPC is the preferred evidence path;
- [x] developer file snapshot exists only as deterministic UI fallback;
- [x] core Analytics and Monitor remain fully usable with advanced mode off;
- [x] no fake application rows in normal builds;
- [x] normal ad-hoc CI build reports provider unavailable rather than pretending activation;
- [x] shield brand system applied to app shell, menu bar, accent and advanced-status surfaces.

Still required before production B2:

- [ ] successful signed activation + filter configuration on a real Mac;
- [ ] authenticated XPC runtime validation;
- [ ] B1 source-app/locality/byte acceptance;
- [ ] advanced coverage model suitable for user-facing evidence;
- [ ] persisted per-app buckets only after evidence semantics are proven;
- [ ] retention/reset controls for advanced data;
- [ ] accessibility/usability pass with real provider states;
- [ ] performance/network-safety validation;
- [ ] decision on content-filter exclusivity as a product constraint;
- [ ] final Developer ID/notarization path.

## Claim boundary

Safe branch claim:

> Traffic Monitoring contains an opt-in Advanced Observability prototype: an embedded macOS Filter Data Provider system extension, audit-token application identity path, local/external/unknown classification, aggregate flow statistics, authenticated XPC evidence bridge, installation/configuration lifecycle, runtime diagnostics, and Applications UI. Source/build/package gates pass in CI, but real per-app evidence remains experimental until a properly signed provider is activated and validated on a Mac.

Unsafe claims:

- `Traffic Monitoring measures validated per-app traffic in the downloadable ad-hoc build.`
- `Traffic Monitoring verifies that an app is local-only.`
- `Application byte totals are validated.`
- `No external traffic` without complete validated provider coverage and later audit semantics.
