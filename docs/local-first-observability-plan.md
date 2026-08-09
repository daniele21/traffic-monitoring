# Local-first observability evolution plan

This document defines the staged evolution from a network-usage utility into an evidence and observability tool for local-first software.

Read `../AGENTS.md` and `positioning.md` first.

The existing `implementation-plan.md` remains authoritative for the current lightweight network-usage product. This document governs the **strategic evolution after the current core is stable**.

## North star

Traffic Monitoring should make this progression possible without sacrificing the simplicity or privacy of the base app:

```text
How much network data did my Mac use?
                ↓
On which network did it happen?
                ↓
When and where were the largest peaks?
                ↓
Which application generated network activity?       [future / opt-in]
                ↓
Was the observed flow local or external?             [future / opt-in]
                ↓
Can I run a reproducible local-first audit?           [future / opt-in]
```

The project must never jump directly to the final claim. Each stage has a feasibility and evidence gate.

---

# Strategic architecture

The product should evolve as two layers rather than one increasingly privileged monolith.

```text
┌──────────────────────────────────────────────────────────────┐
│                       Traffic Monitoring                     │
│                                                              │
│  Core network usage                 Advanced observability   │
│  ------------------                 ----------------------   │
│  Public macOS APIs                  Separate opt-in system   │
│  Physical interface counters        extension/provider       │
│  SSID/network context               App/flow metadata         │
│  Aggregate byte deltas              Locality evidence         │
│  Historical usage                   Audit sessions            │
│          │                                  │                 │
│          └────────── Evidence domain ────────┘                 │
│                         │                                    │
│              Analytics / export / UI                         │
└──────────────────────────────────────────────────────────────┘
```

## Core-mode invariant

A user who only wants hotspot/network usage analytics must never be forced to install or authorize advanced traffic-observability components.

## Advanced-mode invariant

A future advanced mode must be:

- explicit opt-in;
- separately explained;
- independently disableable;
- privacy-minimized;
- designed around metadata aggregation rather than content retention;
- unable to silently broaden collection beyond documented fields.

---

# Track A — Core product foundation

These phases improve the existing product and create trustworthy evidence primitives without requiring privileged traffic inspection.

## A0 — Reposition the repository

**Goal:** align public narrative with `positioning.md` while keeping current capabilities honest.

### Deliverables

- [x] Define `Local network observability for macOS` as the primary descriptor.
- [x] Define the project role as `Evidence & Observability`, not a local-AI infrastructure pillar.
- [x] Separate current capabilities from future application/locality observability.
- [ ] Update README hero, problem statement, current capabilities, roadmap, and privacy language.
- [ ] Update `product-spec.md` with strategic direction and advanced-observability boundary.
- [ ] Update `AGENTS.md` and docs map for progressive-disclosure routing.
- [ ] Review GitHub repository description/topics after the positioning branch is accepted.

### Acceptance gate

A new reader should understand within the first screen of the README:

1. what Traffic Monitoring does today;
2. why it is local-first;
3. why observability matters strategically;
4. that per-app/locality auditing is a future direction, not a current feature.

---

## A1 — Evidence-quality core

**Goal:** make current network-level analytics useful as evidence, not only as visual statistics.

Read: `data-and-analytics.md`, `tracking-engine.md`, `testing.md`.

### Product changes

- [ ] Add explicit data-quality state to analytics:
  - `identified`;
  - `partiallyIdentified`;
  - `unknownNetwork`;
  - `trackingDegraded`.
- [ ] Surface when Wi-Fi identity is unavailable instead of silently grouping all unknown Wi-Fi as equivalent evidence.
- [ ] Track coverage metadata for selected periods:
  - app active duration;
  - tracking healthy duration;
  - metadata-degraded duration;
  - gaps caused by process termination or failed persistence.
- [ ] Add a compact `About this data` explanation to analytics.
- [ ] Add network aliases without changing canonical identity keys.
- [ ] Add a detail view for one network with:
  - total/download/upload;
  - peak hour/day;
  - first/last observed;
  - likely-expensive/hotspot indicator;
  - history trend.

### Engineering changes

- [ ] Define `EvidenceQuality` domain model.
- [ ] Persist enough health/coverage information to avoid overclaiming complete observation.
- [ ] Add reconciliation tests for evidence coverage and usage totals.
- [ ] Verify no high-frequency health samples create storage bloat.

### Acceptance gate

For any historical period, the product can answer both:

> What usage was observed?

and:

> How complete/confident is this observation?

without requiring packet- or flow-level inspection.

---

## A2 — Reproducible export

**Goal:** turn current analytics into portable evidence while keeping export user-controlled.

### Deliverables

- [ ] Add CSV export for aggregated usage.
- [ ] Add JSON evidence export with explicit schema version.
- [ ] Include in exported evidence:
  - observation range;
  - network identity/display label;
  - download/upload/total;
  - expensive/constrained flags when observed;
  - evidence-quality/coverage summary;
  - app version;
  - schema version.
- [ ] Exclude by default:
  - raw payloads;
  - destinations;
  - BSSID;
  - unrelated system metadata.
- [ ] Let the user preview what will be exported.
- [ ] Add deterministic fixture tests for export format.

### Example evidence envelope

```json
{
  "schemaVersion": 1,
  "period": {
    "start": "...",
    "end": "..."
  },
  "coverage": {
    "status": "identified",
    "observedSeconds": 7200
  },
  "networks": [
    {
      "displayName": "iPhone Hotspot",
      "downloadBytes": 123,
      "uploadBytes": 45,
      "totalBytes": 168,
      "isExpensive": true
    }
  ]
}
```

### Acceptance gate

An exported file can reproduce dashboard totals for the same period and contains only fields documented in the export schema.

---

# Track B — Advanced observability feasibility

Do not implement this track opportunistically inside the core tracker.

Current interface counters cannot establish source application or public-Internet locality. Those require a different evidence source.

Apple's Network Extension content-filter APIs are a promising macOS direction because flows can expose source-app identity and flow metadata. They also introduce system-extension, entitlement, sandbox, distribution, and consent implications. These must be evaluated before product commitment.

## B0 — Architecture and entitlement spike

**Goal:** decide whether application-level observability is technically, operationally, and privacy-wise acceptable for this project.

### Questions to answer

#### Capability

- [ ] Can a supported macOS Network Extension content filter observe the flows required for this product?
- [ ] Can `NEFilterFlow.sourceAppIdentifier` reliably identify normal source applications for the target scenarios?
- [ ] How should helper processes, XPC services, WebKit processes, and system-created flows be represented?
- [ ] Which system traffic is not observable and how should that limitation be surfaced?
- [ ] Can byte counts be derived accurately enough per flow without retaining payload data?
- [ ] Can local vs external classification be based on endpoint metadata without DNS/content inspection?

#### Platform / distribution

- [ ] Which Network Extension entitlements are required?
- [ ] Is Apple approval required for intended distribution?
- [ ] Must the provider ship as a macOS system extension?
- [ ] What user approval/install flow is required?
- [ ] How does this affect signing, notarization, sandboxing, and CI?
- [ ] Does Mac App Store distribution remain viable, and under which constraints?

#### Privacy

- [ ] What is the minimum metadata needed?
- [ ] Can endpoint addresses/hostnames be classified and then discarded immediately?
- [ ] Can app identifiers be aggregated without persisting per-flow records long-term?
- [ ] What data must be visible in an audit log for explainability?
- [ ] What data should never cross the provider boundary?

#### Performance

- [ ] Measure idle CPU/wakeups with the provider enabled.
- [ ] Measure overhead under high-throughput traffic.
- [ ] Measure flow-event volume across a normal working day.
- [ ] Determine safe aggregation cadence.

### Spike artifacts

Create:

- `docs/advanced-observability-feasibility.md`;
- ADR documenting chosen/rejected platform approach;
- minimal experimental target isolated from production core;
- capability matrix across common apps;
- privacy data-flow diagram;
- signing/entitlement notes.

### Acceptance gate

Proceed only if all are true:

1. source application attribution is sufficiently reliable for stated claims;
2. local/external classification can be explained with clear unknown states;
3. user authorization/distribution requirements are acceptable;
4. the architecture can avoid retaining packet payloads;
5. provider overhead is compatible with an always-on utility;
6. the base app can remain functional without the extension.

If the gate fails, retain Traffic Monitoring as a strong network-level observability product rather than forcing advanced attribution.

### Apple APIs to evaluate

Primary research candidates:

- `NetworkExtension.NEFilterDataProvider`;
- `NetworkExtension.NEFilterFlow`;
- `NEFilterFlow.sourceAppIdentifier` / audit-token metadata;
- `NEFilterSocketFlow` flow endpoints/protocol metadata;
- `NEFilterManager` / provider configuration;
- macOS system-extension packaging for filter providers.

This list is a research starting point, not a pre-decided architecture.

---

## B1 — Minimal app-attribution prototype

**Prerequisite:** B0 accepted.

**Goal:** prove app identity and aggregate byte attribution without building the final UI.

### Domain model

Introduce experimental models separate from core `UsageBucket`:

```text
ObservedApplication
FlowObservation
FlowLocality
ApplicationUsageBucket
ObservabilityCoverage
```

Suggested `FlowLocality`:

```text
loopback
localNetwork
external
unknown
```

`unknown` is mandatory. Never force classification.

### Provider behavior

- [ ] Receive new flow metadata.
- [ ] Resolve source application identity where available.
- [ ] Record protocol/direction needed for accounting.
- [ ] Classify endpoint locality using deterministic address rules where possible.
- [ ] Avoid persisting payload bytes.
- [ ] Aggregate observations before crossing into the main app where architecture allows.
- [ ] Redact or discard raw endpoint metadata after classification unless diagnostic mode explicitly requires temporary inspection.

### Main-app behavior

Diagnostic-only view:

```text
Application          Local      External      Unknown
ClosedRoom           182 MB       0 B           0 B
Safari                14 MB     1.8 GB          2 MB
Unknown process        1 MB       4 MB          3 MB
```

### Test matrix

At minimum:

- Safari / WebKit traffic;
- `curl` or equivalent CLI process;
- a native URLSession test app;
- localhost client/server traffic;
- LAN traffic to another device;
- VPN enabled/disabled;
- helper/XPC process;
- app restart;
- provider restart;
- high-throughput transfer.

### Acceptance gate

For controlled applications and transfers:

- attribution agrees with known source app for supported cases;
- local/external classification agrees with controlled destinations;
- unknown/unobservable cases remain explicit;
- totals do not double-count the existing physical-interface tracker;
- no payload content is persisted.

---

## B2 — Advanced observability product mode

**Prerequisite:** B1 accepted.

**Goal:** expose app-level network evidence to users without confusing it with core usage analytics.

### Information architecture

Do not overload the existing `Networks` view.

Proposed analytics navigation:

```text
Overview
Trend
Networks
Applications      ← shown only when Advanced Observability is enabled
Audits            ← later
Monitor
```

### Applications view

Show:

- application name/icon;
- observed local bytes;
- observed external bytes;
- unknown/unclassified bytes;
- last observed activity;
- observation coverage;
- drill-down.

### App detail

Show:

- total observed traffic;
- local vs external vs unknown;
- timeline;
- top-level protocol breakdown only if useful and privacy-safe;
- evidence limitations;
- `Start Audit` entry point when B3 exists.

### Settings

Advanced Observability must have a dedicated settings block:

- current status;
- why the permission/system extension is needed;
- exact metadata collected;
- enable/disable action;
- retention policy;
- reset advanced data independently where feasible.

### Acceptance gate

A nontechnical user can distinguish:

- normal network-usage analytics;
- app-level advanced observation;
- data that is unknown or outside coverage.

No UI implies that Advanced Observability is required for basic traffic tracking.

---

# Track C — Local-first audit workflows

## C0 — Audit semantics

**Prerequisite:** reliable B2 evidence.

Before coding an audit button, define what an audit can and cannot conclude.

### Audit unit

A bounded observation session has:

```text
auditId
selected application identity
start/end
coverage status
local bytes
external bytes
unknown bytes
flow count by locality
observability warnings
Traffic Monitoring version
provider version
```

### Safe verdict language

Allowed examples:

- `No external traffic detected during this audit.`
- `External traffic was observed.`
- `Some traffic could not be classified.`
- `Application attribution was incomplete for part of this audit.`

Avoid:

- `100% private`;
- `GDPR compliant` based only on this tool;
- `No data ever leaves this device`;
- `Guaranteed local-only`.

### Acceptance gate

The audit result describes observed evidence and coverage, not a universal privacy verdict.

---

## C1 — Privacy Audit

**Goal:** create a reproducible workflow for testing a local-first application.

### User flow

```text
Applications
    ↓
Select application
    ↓
Start Audit
    ↓
Run target workflow
    ↓
Stop Audit
    ↓
Evidence summary
    ↓
Optional export
```

### Audit result

Example:

```text
ClosedRoom — Network Audit
45m 12s observed

Local network         182 MB
External network        0 B
Unclassified            0 B

No external traffic detected during this audit.
```

### Features

- [ ] start/stop audit;
- [ ] live audit status;
- [ ] elapsed time;
- [ ] selected-app identity lock;
- [ ] coverage warnings;
- [ ] local/external/unknown totals;
- [ ] timeline of classified activity;
- [ ] JSON evidence export;
- [ ] optional human-readable report later.

### Acceptance gate

Repeated controlled audits produce deterministic, explainable results within documented observation limitations.

---

## C2 — Developer evidence mode

**Goal:** make Traffic Monitoring useful as developer tooling rather than only a GUI utility.

Possible interfaces, to be evaluated in order:

1. JSON export from GUI;
2. URL/deep-link automation for starting an audit;
3. local CLI helper;
4. headless audit command;
5. CI/privacy-regression integration.

Do not start with a daemon or broad automation surface unless real workflows justify it.

### Candidate CLI experience

Future concept only:

```bash
traffic-monitor audit \
  --bundle-id com.example.ClosedRoom \
  --duration 30m \
  --output audit.json
```

Potential machine-readable outcome:

```text
PASS                    no external traffic observed and complete coverage
FAIL                    external traffic observed
INCONCLUSIVE            unknown traffic or incomplete coverage
```

A CI pass/fail contract must never hide an `INCONCLUSIVE` state.

### Acceptance gate

A developer can reproduce the same evidence through documented automation without granting broader permissions than the GUI mode already requires.

---

# Cross-cutting workstreams

## Privacy model

Before B1, document data classification for every new field:

| Data | Sensitivity | Persist? | Retention |
|---|---|---:|---|
| App bundle identifier | medium | aggregate only by default | configurable |
| Process audit token | high/technical | no unless required | ephemeral |
| Remote IP | potentially sensitive | preferably no | classify then discard |
| Hostname | sensitive | no by default | ephemeral if ever used |
| Payload content | very high | never | none |
| Aggregate local/external bytes | low-medium | yes | local history |

Final decisions depend on the feasibility spike.

## Storage evolution

Keep core and advanced data schemas separable.

Possible future entities:

```text
ApplicationProfileEntity
ApplicationUsageBucketEntity
AuditSessionEntity
AuditEvidenceEntity
```

Do not put one row per network flow into SwiftData by default. Aggregate before persistence unless a bounded audit explicitly requires more detail.

## Observability health

Advanced mode needs explicit coverage states such as:

```text
healthy
providerDisabled
providerUnavailable
partialAttribution
partialLocality
persistenceError
```

Audit conclusions must incorporate these states.

## Performance budget

Define and measure:

- idle CPU;
- memory;
- wakeups;
- extension event throughput;
- DB writes/hour;
- storage growth/day;
- analytics query latency.

A privacy tool that materially degrades battery life or networking is not acceptable.

## Security review

Before shipping advanced mode:

- threat-model extension/app communication;
- ensure untrusted processes cannot inject fake evidence;
- validate code-signing identity used for app attribution;
- minimize IPC payload;
- avoid logging sensitive flow metadata;
- review export redaction;
- test downgrade/update paths for provider and app schema versions.

---

# Product roadmap summary

| Phase | User value | Architecture impact | Status |
|---|---|---|---|
| A0 Positioning | coherent role in local-first ecosystem | docs only | in progress |
| A1 Evidence quality | trustworthy network-level history | small core/schema changes | planned |
| A2 Export | reproducible current evidence | analytics/export layer | planned |
| B0 Feasibility spike | decide whether per-app observability is viable | isolated experiment | planned |
| B1 App attribution prototype | source-app + locality evidence | optional extension path | gated |
| B2 Advanced mode | per-app analytics | new optional product surface | gated |
| C0 Audit semantics | safe evidence language | domain model | gated |
| C1 Privacy Audit | bounded local-first verification | audit workflow | gated |
| C2 Developer evidence mode | automation / regression testing | optional CLI/API | later |

---

# Recommended immediate implementation order

The next engineering work should **not** begin with Network Extension.

Recommended order:

1. finish real-Mac validation and reliability work already defined in `implementation-plan.md`;
2. complete A1 evidence-quality changes;
3. implement A2 export;
4. only then run B0 as an isolated feasibility project;
5. make an explicit go/no-go decision before adding privileged advanced observability to production targets.

This keeps the current product useful and shippable even if advanced application attribution proves unsuitable.

---

# Decision rules for coding agents

1. `positioning.md` owns strategic language.
2. `implementation-plan.md` owns the current lightweight product roadmap.
3. This document owns the advanced observability evolution.
4. No agent may implement B1+ work before B0 has a documented accepted gate.
5. No agent may infer source application from physical-interface counters.
6. No agent may label traffic `external` without a documented locality-classification rule.
7. Unknown evidence is a valid product state.
8. No advanced feature may require payload persistence.
9. Base network analytics must continue working when advanced mode is disabled.
10. If Apple platform constraints conflict with the desired positioning, change the feature claim rather than weakening privacy or correctness guarantees.

## Research references

Apple platform documentation to review during B0:

- `NEFilterDataProvider`: https://developer.apple.com/documentation/networkextension/nefilterdataprovider
- `NEFilterFlow`: https://developer.apple.com/documentation/networkextension/nefilterflow
- `NEFilterFlow.sourceAppIdentifier`: https://developer.apple.com/documentation/networkextension/nefilterflow/sourceappidentifier
- `NEFilterSocketFlow`: https://developer.apple.com/documentation/networkextension/nefiltersocketflow
- WWDC25 — Filter and tunnel network traffic with NetworkExtension: https://developer.apple.com/videos/play/wwdc2025/234/

These references indicate that Network Extension can expose flow objects and source-app metadata on macOS, but the B0 spike must still validate entitlement, system-extension, coverage, privacy, and distribution constraints for this specific product.