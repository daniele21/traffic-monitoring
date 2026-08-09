# Non-privileged App Activity Preview

This document defines the Phase 4 fallback for application-level visibility when the signed Advanced Observability provider cannot be activated.

## Product role

**App Activity Preview** is a lightweight, best-effort process network activity view for macOS. It is intentionally separate from Advanced Observability evidence.

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

CI now smoke-tests the expected process-summary header rather than dumping process activity into build logs.

The app parses the CSV locally and refreshes the preview approximately every 15 seconds while the Applications screen is visible.

No preview sampling is required for core network tracking.

## What the preview may show

For processes present in the latest sample:

- process name;
- PID when parseable;
- downloaded bytes reported by `nettop`;
- uploaded bytes reported by `nettop`;
- total bytes;
- latest preview refresh time.

Rows are best-effort process activity hints. They are not persisted in SwiftData in this phase.

## Evidence boundary

The preview **cannot** currently establish:

- whether traffic was loopback, LAN, or Internet;
- the remote destination or endpoint;
- whether a process was active during periods when the preview was not sampling;
- that all traffic from an application was observed;
- that a process is `local-only`;
- a privacy verdict;
- byte reconciliation with the authoritative physical-interface tracker.

`nettop` process totals can include activity that occurred before the Applications view or Traffic Monitoring was opened. The UI states this explicitly.

For those reasons App Activity Preview data must not be merged into:

- network evidence quality;
- JSON/CSV evidence export;
- Advanced Provider Local / External / Unknown aggregates;
- future Privacy Audit verdicts.

## Privacy characteristics

The implementation launches a local macOS utility, parses its process summary in memory, and renders the result locally.

Traffic Monitoring does not add DNS lookups, packet payload inspection, browsing-content inspection, or a cloud analytics service to support this preview.

## Runtime behavior

- The preview is enabled by default unless the user turns it off.
- Sampling starts only while the **Applications** destination is visible.
- Leaving Applications stops the recurring sampler.
- Disabling the preview clears current preview rows.
- Missing/unusable `nettop` becomes an explicit unavailable/failed state rather than fake rows.
- Sampling executes off the main actor/thread; UI publication remains on the main actor.
- Only the top non-zero process rows are rendered to keep the UI responsive.
- Process search/filtering is local and does not change the sampled source.

## Relationship to the signed provider

```text
Applications Beta
├── App Activity Preview
│   ├── no Apple Developer Program required
│   ├── process name / PID
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
- zero-byte rows may be omitted from UI without changing the raw parser contract;
- sampling occurs off the main thread;
- the Applications UI states that preview data is best effort and non-authoritative;
- the normal tracker remains independent from preview failures;
- CI smoke-checks that the target macOS runner exposes the expected `bytes_in,bytes_out` process-summary header.

Real-Mac UX acceptance remains required for representative applications, long-running process lists, process churn, sleep/wake, and comparison with Activity Monitor/other local diagnostics.
