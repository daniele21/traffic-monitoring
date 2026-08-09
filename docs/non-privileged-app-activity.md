# Non-privileged App Activity Preview

This document defines the Phase 4 fallback for application-level visibility when the signed Advanced Observability provider cannot be activated.

## Product role

**App Activity Preview** is a lightweight, best-effort application and process network activity view for macOS. It is intentionally separate from Advanced Observability evidence.

It exists so Traffic Monitoring remains useful without an Apple Developer Program, Network Extension entitlement, system-extension installation, or content-filter activation.

It is **not** a replacement for the signed provider.

## Source

The current implementation samples the macOS `/usr/bin/nettop` process summary in logging mode:

```text
nettop -n -P -L 1 -x -J bytes_in,bytes_out
```

The Phase 4 CI spike on macOS 15 demonstrated that this mode runs without privileged installation and returns process rows containing:

- process name;
- PID when exposed in the process key;
- cumulative `bytes_in`;
- cumulative `bytes_out`.

CI smoke-tests the expected process-summary header rather than dumping process activity into build logs.

The app parses the CSV locally and refreshes the preview approximately every 15 seconds while the Applications screen is visible.

No preview sampling is required for core network tracking.

## Three activity views

Applications Beta presents the same latest macOS sample at three aggregation levels.

### Applications

For each sampled PID, Traffic Monitoring performs a best-effort macOS application identity resolution. It checks the running process and, when needed, walks the local parent-process chain to find an owning application bundle. Nested helper bundles are normalized to the outer application bundle when possible.

When an application bundle is resolved, aggregation uses its bundle identifier when available and sums all matching process rows into one application row. If ownership cannot be resolved, Traffic Monitoring does not invent one.

### Process names

All rows with the same process name are combined across PIDs into one ranked process-name summary. This answers questions such as how much aggregate activity came from all `language_server`, `Electron`, or helper instances in the latest sample.

Each summary exposes:

- process name;
- number of PID instances;
- represented application names when available;
- summed downloaded bytes;
- summed uploaded bytes;
- summed total bytes;
- percentage share of all visible process bytes in the latest sample.

Process-name aggregation is independent from application aggregation. The same process name can legitimately occur under more than one application; represented application names stay explicit rather than being forced into a single owner.

### Processes

The diagnostic view retains individual process/PID rows together with resolved application identity when available.

This is useful for checking how an application-level or process-name aggregate was composed.

## Evidence boundary

All three views are **latest-sample activity analytics**, not durable historical evidence.

The preview **cannot** currently establish:

- whether traffic was loopback, LAN, or Internet;
- the remote destination or endpoint;
- whether a process was active during periods when the preview was not sampling;
- that all traffic from an application was observed;
- that parent/application resolution is complete for every process;
- that a process or application is `local-only`;
- a privacy verdict;
- byte reconciliation with the authoritative physical-interface tracker.

`nettop` process totals can include activity that occurred before the Applications view or Traffic Monitoring was opened. The UI states this explicitly.

For those reasons App Activity Preview data must not be merged into:

- network evidence quality;
- JSON/CSV evidence export;
- Advanced Provider Local / External / Unknown aggregates;
- future Privacy Audit verdicts.

## Privacy characteristics

The implementation launches local macOS utilities, parses process summaries/parent relationships in memory, and renders the result locally.

Traffic Monitoring does not add DNS lookups, packet payload inspection, browsing-content inspection, or a cloud analytics service to support this preview.

## Runtime behavior

- The preview is enabled by default unless the user turns it off.
- Sampling starts only while the **Applications** destination is visible.
- Leaving Applications stops the recurring sampler.
- Disabling the preview clears current preview rows.
- Missing/unusable `nettop` becomes an explicit unavailable/failed state rather than fake rows.
- Sampling and app-identity resolution execute off the main actor/thread; UI publication remains on the main actor.
- Applications, Process names, and Processes are derived from the same in-memory sample and therefore reconcile to the same visible total.
- The diagnostic process table renders at most the first 200 matching rows to keep the UI responsive.
- Search and filtering are local and do not change the sampled source.

## Relationship to the signed provider

```text
Applications Beta
├── App Activity Preview
│   ├── no Apple Developer Program required
│   ├── application aggregation
│   ├── process-name aggregation
│   ├── process / PID diagnostics
│   ├── cumulative process byte totals
│   └── no locality / privacy conclusion
│
└── Advanced Provider
    ├── signed Network Extension system extension
    ├── source application identity
    ├── Local / External / Unknown flows
    ├── experimental byte accounting
    └── future evidence/audit path only after validation
```

When the Advanced Provider is available, the two sources remain visually and semantically separate. The preview is not used to fill gaps in provider evidence.

## Acceptance criteria

Phase 4 source/build acceptance requires:

- parser tests based on actual macOS `nettop` CSV shape;
- malformed rows are discarded rather than guessed;
- PID suffix parsing preserves process names containing periods;
- quoted CSV fields are supported;
- application aggregation sums multiple process rows without overflow;
- unresolved process identity remains explicit instead of fabricating a bundle identifier;
- process-name aggregation combines matching names across PIDs using saturating byte arithmetic;
- process-name aggregation may span multiple applications and keeps represented app names explicit;
- all aggregation levels reconcile to the same latest-sample byte totals;
- zero-byte rows may be omitted from UI without changing the raw parser contract;
- sampling occurs off the main thread;
- the Applications UI states that preview data is best effort and non-authoritative;
- the normal tracker remains independent from preview failures;
- CI smoke-checks that the target macOS runner exposes the expected `bytes_in,bytes_out` process-summary header.

Real-Mac UX acceptance remains required for representative applications, helper processes, language servers, long-running process lists, process churn, sleep/wake, and comparison with Activity Monitor/other local diagnostics.
