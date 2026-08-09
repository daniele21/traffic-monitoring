# Advanced Observability signed real-Mac runbook

Operational runbook for the first B1/B2 runtime validation. This document does **not** redefine acceptance semantics; the authoritative test matrix remains `testing.md`.

Use this only after the app and embedded Network Extension are signed with the required Apple capabilities. The normal ad-hoc GitHub Actions artifact is intentionally insufficient for this gate.

## Goal

Prove the runtime path:

```text
signed Traffic Monitoring.app
        ↓
macOS system-extension activation / approval
        ↓
NEFilterManager enabled
        ↓
NEFilterDataProvider running
        ↓
sourceAppAuditToken + locality + statistics
        ↓
authenticated Mach/XPC snapshot
        ↓
Applications UI
```

A successful run proves only the tested matrix. It does not by itself justify a `local-only` or privacy verdict.

## 1. Required signing inputs

Before building, obtain/configure:

- an Apple Developer Team with the Network Extension capability available for the app/provider identifiers;
- host bundle identifier `com.daniele21.trafficmonitoring`;
- provider bundle identifier `com.daniele21.trafficmonitoring.filter`;
- appropriate provisioning for the host and system extension;
- a signing identity suitable for the intended development/distribution path.

Host and provider must have the same stable Apple Team ID. The XPC service fails closed when that identity is missing or mismatched.

## 2. Preferred build path without local Xcode

The repository contains a manual workflow:

```text
Actions → Advanced Observability Signed Validation Build → Run workflow
```

It is intentionally `workflow_dispatch` only and does not run on normal pushes.

Configure these GitHub Actions secrets first:

```text
APPLE_TEAM_ID
MACOS_SIGNING_IDENTITY
MACOS_CERTIFICATE_P12_BASE64
MACOS_CERTIFICATE_PASSWORD
MACOS_HOST_PROVISIONING_PROFILE_BASE64
MACOS_EXTENSION_PROVISIONING_PROFILE_BASE64
```

Where:

- `MACOS_SIGNING_IDENTITY` is the exact code-signing identity imported from the P12;
- the host profile belongs to `com.daniele21.trafficmonitoring`;
- the extension profile belongs to `com.daniele21.trafficmonitoring.filter`;
- both profiles belong to `APPLE_TEAM_ID`.

The workflow:

1. creates a temporary keychain;
2. imports the signing certificate without printing it;
3. installs the two temporary provisioning profiles;
4. validates both profile Team IDs;
5. generates the Xcode project;
6. builds host + embedded system extension with target-specific profile specifiers;
7. runs `verify-signed-advanced-observability.sh`;
8. uploads only the signed `.app.zip` + checksum for three days;
9. removes the temporary keychain.

It does **not** upload the P12 or provisioning profiles.

A successful signed-build workflow is still only a packaging/signing gate. Runtime activation must be tested on the target Mac.

### Alternative local build

If a Mac with Xcode is available:

```bash
brew install xcodegen
xcodegen generate
```

Build with the same host/provider profiles and Team ID. Do not remove the host/provider entitlements just to make the build succeed.

Expected embedded path:

```text
TrafficMonitoring.app/Contents/Library/SystemExtensions/
  com.daniele21.trafficmonitoring.filter.systemextension
```

## 3. Run the signed-bundle preflight

Before launching:

```bash
bash scripts/verify-signed-advanced-observability.sh /path/to/TrafficMonitoring.app
```

The preflight checks:

- host and provider code signatures;
- exact bundle identifiers;
- exact embedded system-extension filename;
- `NEMachServiceName`;
- stable/non-ad-hoc Team ID;
- matching host/provider Team IDs;
- system-extension install entitlement;
- content-filter Network Extension entitlement;
- designated requirements.

Do not continue to runtime validation if this preflight fails.

## 4. Install and enable

1. Launch the signed app.
2. Open **Traffic Monitoring Settings**.
3. Enable **Show Applications view**.
4. Choose **Install & Enable Advanced Observability**.
5. Read/accept the content-filter coexistence warning only if replacing another active content filter is acceptable for the test machine.
6. Approve the system extension in macOS System Settings when requested.
7. Restart only if macOS explicitly reports that the extension update requires it.
8. Return to Settings and confirm that the system component / provider state progresses toward active.

Core Analytics must continue working even if any advanced activation step fails.

## 5. Runtime diagnostics

The Applications status card exposes only non-sensitive provider diagnostics:

- provider protocol version;
- provider start time;
- active flow count;
- total observed flow count;
- latest snapshot time;
- byte-accounting capability.

Interpretation examples:

- **Provider active + observed flows increasing + Applications empty** → investigate source-app resolution/aggregation.
- **Provider active + observed flows never increase** → investigate content-filter coverage/configuration.
- **Provider unavailable / XPC timeout** → investigate activation, Mach service, Team-ID authentication and provider logs.
- **Degraded** → snapshot is stale; do not draw app-level conclusions.

For local diagnostics, prefer unified logging for the Traffic Monitoring/provider subsystems. Do not add endpoint or payload logging to Release builds.

## 6. First controlled source-app test

Start with processes whose identity is easy to recognize:

1. CLI `curl` or another known command-line process;
2. Safari/WebKit;
3. a small native URLSession test app if available.

For each one record:

- expected process/app;
- displayed signing identifier or `Unknown application`;
- Local / External / Unknown flow counts;
- observed-flow counter before/after;
- timestamp.

Unknown identity is acceptable evidence; incorrect confident identity is not.

## 7. Locality matrix

Exercise at least:

- loopback (`127.0.0.1` and/or `::1`);
- private LAN peer;
- public Internet IPv4;
- IPv6 where available;
- hostname-only/missing endpoint cases encountered naturally.

Expected classes are defined in `testing.md`. Do not perform extra DNS lookups merely to turn Unknown into External.

## 8. Byte reconciliation

Byte accounting starts as **Not validated**.

For repeated controlled transfers capture:

- transfer size;
- Advanced Observability per-app/locality bytes;
- core physical-interface delta in the same time window;
- whether the flow had multiple statistics reports;
- final flow-close behavior.

The provider removes closed flow state after applying its final cumulative-byte delta, preventing unbounded active-flow state growth. Promote byte accounting only after repeated tests show no report-update double counting and a documented acceptable relationship to the controlled transfers/reference counters.

## 9. Security gate

The Mach/XPC evidence service authenticates clients before returning a snapshot.

Required behavior:

- host bundle identifier must be `com.daniele21.trafficmonitoring`;
- host code signature must validate;
- host and provider Team IDs must match;
- ad-hoc/no-Team-ID callers are rejected;
- raw audit tokens and packet payloads are never returned over IPC.

Before production release, add a negative runtime test using another local process that attempts to connect to the known Mach service and confirm it cannot retrieve evidence.

## 10. VPN / helper / lifecycle matrix

After the basic path works, execute the remaining B1/B2 matrix in `testing.md`, including:

- VPN off/on;
- Safari/WebKit helpers;
- helper/XPC processes;
- app restart while provider remains enabled;
- provider/system-extension restart/update;
- sleep/wake;
- short-lived flows;
- content-filter coexistence;
- idle CPU/wakeups and sustained-throughput overhead.

## 11. Cleanup

Use **Disable Filter** in Traffic Monitoring Settings before testing another content filter.

If the system extension itself must be removed, use the app's deactivation path / intended development cleanup workflow rather than deleting files from the system-extension directories manually.

## Acceptance output

Record a dated validation note with:

- macOS version / Mac model;
- app/provider version and commit SHA;
- Team/signing path used;
- preflight result;
- activation result;
- XPC result;
- source-app matrix;
- locality matrix;
- byte reconciliation table;
- VPN/helper limitations;
- performance observations;
- unresolved Unknown/degraded cases.

Only then update `b0-b2-implementation-status.md` from compile-level/prototype claims to the evidence actually demonstrated on the real Mac.
