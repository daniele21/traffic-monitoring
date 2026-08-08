# M1 measurement validation

Read this file only when validating the measurement spike on a real Mac. Implementation mechanics remain in `tracking-engine.md`.

## Automated status

The current spike has automated coverage for:

- monotonic cumulative-counter deltas;
- counter regression/reset rejection;
- timer jitter using real elapsed time;
- implausible-rate rejection;
- large `UInt64` counter arithmetic;
- Wi-Fi classification via CoreWLAN interface mapping;
- exclusion of `utun*`, loopback, down, and known system/virtual interfaces;
- Xcode project generation, macOS build, and unit tests in GitHub Actions.

The production Darwin byte source is `sysctl` with `NET_RT_IFLIST2`, parsing `RTM_IFINFO2` / `if_msghdr2.ifm_data` (`if_data64`). Do not replace it with `getifaddrs().ifa_data` for byte accounting because Darwin's `struct if_data` byte fields are 32-bit.

## Run the diagnostic build

```bash
brew install xcodegen
xcodegen generate
open TrafficMonitoring.xcodeproj
```

Run the `TrafficMonitoring` scheme, then:

1. open the menu-bar item;
2. open **Settings** and allow **Wi-Fi Network Names** if you want SSID attribution;
3. open **Analytics** — during M1 this window is the diagnostics surface;
4. keep Activity Monitor or `netstat -ib` available only as a validation reference.

The diagnostics table shows included and excluded interfaces, raw cumulative RX/TX, per-sample deltas, network name, and expensive/constrained metadata.

## Required manual scenarios

Record evidence before declaring the M1 acceptance gate complete.

| Scenario | Expected | Result |
|---|---|---|
| Idle 3–5 min | Counters stay monotonic; no absurd deltas | Pending |
| Known-size download | RX grows plausibly on expected physical interface | Pending |
| Known-size upload | TX grows plausibly on expected physical interface | Pending |
| Wi-Fi A → Wi-Fi B | SSID changes; boundary sample is not attributed across networks | Pending |
| Location denied | Bytes still update; Wi-Fi displays SSID unavailable | Pending |
| Phone hotspot | Bytes count normally; SSID appears if allowed; `isExpensive` captured if macOS reports it | Pending |
| VPN on/off | `utun*` remains excluded while physical interface bytes continue | Pending |
| Disconnect/reconnect | No giant synthetic delta | Pending |
| Ethernet, if available | Physical wired interface is included | Pending |
| Wi-Fi + Ethernet, if available | Both physical interfaces can move independently | Pending |

Protocol overhead means app deltas are not expected to equal file payload size exactly. Compare against physical-interface counters, not only the file size.

## Wired network identity finding

SystemConfiguration's public `SCDynamicStore` APIs expose current network state and can expose values such as primary interface, IPv4 router, addresses, and subnet masks. These are useful diagnostics, but no sufficiently stable and collision-resistant discriminator for **the same Ethernet adapter on different networks** has been proven yet.

For M1 the safe fallback remains:

```text
wired:<interface>:unknown-network
```

Do not silently promote router/subnet strings to a durable identity until they are tested on at least two real wired networks. User aliases can later make the fallback readable.

## Gate

M1 is complete only when the automated build/tests are green **and** the applicable manual scenarios above are recorded as passing. Until then, do not begin persistence or historical analytics work that assumes measurement semantics are proven.
