# Architectural decisions

Compact decision log. Keep entries short; detailed mechanics belong in the focused documents.

## D001 — Native Swift/SwiftUI macOS app

**Status:** accepted for v1.

**Decision:** use Swift + SwiftUI rather than Electron, web wrappers, or Python desktop frameworks.

**Why:** the app depends heavily on macOS networking/lifecycle APIs, should consume minimal resources, and is naturally suited to a menu-bar utility.

**Consequences:** macOS-only codebase; direct access to Network.framework, CoreWLAN, ServiceManagement, SwiftData, and Swift Charts.

---

## D002 — Measure cumulative physical-interface counters

**Status:** accepted direction; concrete Darwin API must be validated in M1.

**Decision:** derive usage from cumulative RX/TX counters on physical interfaces and calculate deltas.

**Why:** it measures the bytes crossing the Mac's network interfaces without packet capture, VPN interception, content inspection, or a privileged helper.

**Consequences:** local-LAN traffic can be included; values are network-interface usage rather than exact carrier-billable usage.

---

## D003 — Do not use Network Extension in v1

**Status:** accepted.

**Decision:** no packet tunnel, content filter, or local VPN architecture for v1.

**Why:** v1 needs aggregate byte accounting by network, not packet/application attribution. Network Extension would add permissions, complexity, failure modes, and privacy surface without solving a necessary v1 problem.

**Revisit when:** per-application or destination-level attribution becomes an explicit product requirement and passes a separate privacy/security review.

---

## D004 — Track all relevant physical interfaces, not only the default path

**Status:** accepted.

**Decision:** maintain counters/baselines independently per trackable physical interface.

**Why:** Wi-Fi and Ethernet can be active simultaneously. `NWPathMonitor` is important context but should not be treated as the byte source of truth for all interfaces.

**Consequences:** totals can legitimately include simultaneous traffic from more than one physical interface.

---

## D005 — Exclude virtual VPN/tunnel interfaces from product totals

**Status:** accepted.

**Decision:** count the physical carrier layer and exclude virtual tunnel interfaces such as `utun*` by default.

**Why:** the same logical traffic can appear on the tunnel and physical interface; summing both causes double counting.

**Consequences:** VPN state may be retained as optional diagnostics/context later, but it does not create a second usage total.

---

## D006 — SSID is optional enrichment

**Status:** accepted.

**Decision:** use CoreWLAN SSID when authorized/available, but never make counting depend on it.

**Why:** on modern macOS, Wi-Fi SSID access is gated by Location Services. Users must still receive correct byte tracking if they deny permission.

**Fallback:** explicit generic identity such as `wifi:<interface>:ssid-unavailable`.

**Important:** do not silently reuse the previous SSID after it becomes unavailable.

---

## D007 — Keep tracking in the user app process for v1

**Status:** accepted.

**Decision:** no root daemon or privileged helper. The menu-bar application remains the tracking process and can auto-start at login.

**Why:** simpler lifecycle/signing and a cleaner authorization path for SSID metadata. Recent macOS versions make Wi-Fi identity particularly awkward for headless daemons.

**Consequence:** usage is tracked only while the user app process is running. Login launch reduces gaps.

---

## D008 — SwiftData for local persistence

**Status:** accepted for v1.

**Decision:** persist local profiles, sessions, and usage buckets with SwiftData.

**Why:** native dependency, suitable record volume, easy integration with a SwiftUI macOS 14+ app.

**Escape hatch:** repository protocols isolate storage so SQLite/GRDB or another backend can replace it if performance/migration evidence demands it.

---

## D009 — Sessions plus five-minute usage buckets

**Status:** accepted.

**Decision:** store connection sessions for boundaries/totals and short usage buckets for time-series analytics.

**Why:** session-only storage cannot accurately answer arbitrary period/time-series queries; sample-level storage would create unnecessary write/record volume.

**Default:** approximately five-minute buckets, split earlier at context/lifecycle boundaries and checkpointed while open.

---

## D010 — Conservative attribution at uncertain boundaries

**Status:** accepted.

**Decision:** when a network transition or lifecycle boundary makes an interval ambiguous, discard the uncertain interval rather than guessing where its bytes belong.

**Why:** a small undercount is preferable to persistent misattribution or a synthetic spike that corrupts analytics.

---

## D011 — No retroactive attribution before app observation

**Status:** accepted.

**Decision:** never interpret the current cumulative interface counter as historical app usage at first launch/relaunch.

**Why:** interface counters predate the process and may span unknown contexts. First observation is always a baseline.

**Consequence:** history begins while the tracker is running; mobile-plan opening usage can be a future manually entered feature.

---

## D012 — Decimal units in product UI

**Status:** accepted initial convention.

**Decision:** canonical values are bytes; UI formats network usage using decimal kB/MB/GB.

**Why:** mobile and Internet data plans are generally communicated in decimal GB.

**Consequence:** never persist rounded units.

---

## D013 — Public Apple/system APIs only in production

**Status:** accepted.

**Decision:** do not make production behavior depend on parsing `netstat`, `ifconfig`, `route`, or private/deprecated `airport` tooling.

**Why:** shell formats/private tools are brittle, sandbox-unfriendly, and can change across macOS releases.

**Allowed:** use system tools during M1/manual testing to validate the public API implementation.

---

## D014 — Minimum target macOS 14 initially

**Status:** accepted initial target.

**Decision:** target macOS 14+ unless compatibility research gives a strong reason to expand support.

**Why:** enables SwiftData and keeps the v1 compatibility/testing matrix manageable while still supporting several macOS generations.

**Revisit when:** distribution goals require older macOS support.

---

## References informing current decisions

- NWPathMonitor: https://developer.apple.com/documentation/network/nwpathmonitor
- NWPath expensive paths / Personal Hotspot: https://developer.apple.com/documentation/network/nwpath/isexpensive
- CoreWLAN CWInterface: https://developer.apple.com/documentation/corewlan/cwinterface
- CoreWLAN SSID: https://developer.apple.com/documentation/corewlan/cwinterface/ssid()
- Apple DTS discussion of modern macOS SSID Location requirement: https://developer.apple.com/forums/thread/732431
- getifaddrs macOS manual page: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/freeifaddrs.3.html
- `if_data` byte counters: https://developer.apple.com/documentation/kernel/if_data
- MenuBarExtra: https://developer.apple.com/documentation/swiftui/menubarextra
