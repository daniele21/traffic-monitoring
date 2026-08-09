# B0–B2 implementation status

Compact status for the **signed Advanced Provider** track. The no-entitlement `App Activity Preview` is a separate Phase 4 capability; see `non-privileged-app-activity.md`. Preview rows never fill gaps in signed-provider evidence.

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

## B2 — Advanced Provider product mode

Status: **signed-provider product mode implemented for prototype use; runtime validation remains open.**

The `Applications` destination is now always discoverable as a Beta product surface because it can also host the non-privileged App Activity Preview. The signed provider itself remains optional and capability-gated.

Implemented for the signed provider:

- [x] explicit Signed Provider capability/status inside Applications Beta;
- [x] Disabled / Provider unavailable / Awaiting approval / Active / Degraded states;
- [x] runtime entitlement detection prevents expected ad-hoc absence from appearing as a setup failure;
- [x] Applications table with Local / External / Unknown flow evidence when provider data exists;
- [x] per-application provider detail view;
- [x] byte values withheld from authoritative presentation while capability is `notValidated`;
- [x] provider runtime diagnostics shown in the Applications status surface;
- [x] separate Advanced Provider controls in Settings;
- [x] embedded system-extension activation action only when the host has the install entitlement;
- [x] macOS approval state surfaced;
- [x] `NEFilterManager` enable/disable lifecycle;
- [x] explicit confirmation before enabling because macOS content filters are exclusive;
- [x] restart-required state;
- [x] provider / bridge / byte-accounting status visible;
- [x] system-extension XPC is the preferred signed evidence path;
- [x] core Overview / Trends / Networks / Monitor remain fully usable with the provider unavailable;
- [x] no fake provider application rows in normal builds;
- [x] shield brand system and redesigned macOS navigation/status surfaces applied.

Still required before production B2:

- [ ] successful signed activation + filter configuration on a real Mac;
- [ ] authenticated XPC runtime validation;
- [ ] B1 source-app/locality/byte acceptance;
- [ ] advanced coverage model suitable for user-facing evidence;
- [ ] persisted signed-provider per-app buckets only after evidence semantics are proven;
- [ ] retention/reset controls for advanced evidence;
- [ ] accessibility/usability pass with real provider states;
- [ ] performance/network-safety validation;
- [ ] decision on content-filter exclusivity as a product constraint;
- [ ] final Developer ID/notarization path.

## Phase 4 relationship

`App Activity Preview` is intentionally outside B0–B2 evidence semantics.

Safe Preview claim:

> Traffic Monitoring can show best-effort process-level network totals locally on macOS without installing a system extension.

The Preview does **not** provide Local / External / Unknown classification, complete coverage, persistent per-app evidence, or privacy conclusions. Those remain responsibilities of the signed provider/audit path after validation.

## Claim boundary

Safe signed-provider branch claim:

> Traffic Monitoring contains an optional Advanced Provider prototype: an embedded macOS Filter Data Provider system extension, audit-token application identity path, local/external/unknown classification, aggregate flow statistics, authenticated XPC evidence bridge, installation/configuration lifecycle, runtime diagnostics, and Applications UI. Source/build/package gates pass in CI, but real signed-provider evidence remains experimental until a properly signed provider is activated and validated on a Mac.

Unsafe claims:

- `Traffic Monitoring measures validated per-app Local/External traffic in the downloadable ad-hoc build.`
- `App Activity Preview verifies that an app is local-only.`
- `Advanced Provider application byte totals are validated.`
- `No external traffic` without complete validated provider coverage and later audit semantics.
