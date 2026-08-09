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

## Application aggregation

The primary preview is application-level rather than PID-level.

For each sampled PID, Traffic Monitoring performs a best-effort macOS application identity resolution. It checks the running process and, when needed, walks the local parent-process chain to find an owning application bundle. Nested helper bundles are normalized to the outer application bundle when possible, so helpers such as browser helpers or language servers can be grouped with the application that owns them.

When an application bundle is resolved, aggregation uses its bundle identifier when available and sums all matching process rows into one application row. The row exposes:

- application display name;
- bundle identifier when available;
- number of contributing process rows;
- downloaded bytes;
- uploaded bytes;
- total bytes.

If macOS cannot resolve an owning application, Traffic Monitoring does not invent one. The row falls back to a best-effort process-name group and is labeled accordingly in the UI.

A segmented **Applications / Processes** control keeps the raw process/PID view available for diagnostics. Searching applications also matches bundle identifiers and contributing process names.

## What the preview may show

For processes present in the latest sample:

- owning application when resolvable;
- application bundle identifier when resolvable;
- process name;
- PID when parseable;
- downloaded bytes reported by `nettop`;
- uploaded bytes reported by `nettop`;
- total bytes;
- latest preview refresh time.

Rows are best-effort activity hints. They are not persisted in SwiftData in this phase.

## Evidence boundary

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
- Application totals aggregate all non-zero process rows retained from the latest sample.
- The diagnostic process table renders at most the first 200 matching rows to keep the UI responsive.
- Application/process search and filtering are local and do not change the sampled source.

## Relationship to the signed provider

```text
Applications Beta
├── App Activity Preview
│   ├── no Apple Developer Program required
│   ├── application aggregate when resolvable
│   ├── process name / PID diagnostics
│   ├── process byte totals
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
- zero-byte rows may be omitted from UI without changing the raw parser contract;
- sampling occurs off the main thread;
- the Applications UI states that preview data is best effort and non-authoritative;
- the normal tracker remains independent from preview failures;
- CI smoke-checks that the target macOS runner exposes the expected `bytes_in,bytes_out` process-summary header.

Real-Mac UX acceptance remains required for representative applications, helper processes, language servers, long-running process lists, process churn, sleep/wake, and comparison with Activity Monitor/other local diagnostics.
