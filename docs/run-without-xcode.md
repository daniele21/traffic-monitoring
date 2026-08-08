# Run the app without Xcode

Use this path when you want to test Traffic Monitoring on a Mac that does not have the full Xcode application installed.

GitHub Actions builds and tests the macOS application on an Apple runner, then creates a separate clean Release app build and publishes it as an artifact.

## Download the latest build

1. Open the repository on GitHub.
2. Open **Actions** → **CI**.
3. Select the latest successful run for the branch or pull request you want to test.
4. In **Artifacts**, download **TrafficMonitoring-macOS**.
5. Unzip the downloaded GitHub artifact.
6. Inside it, unzip `TrafficMonitoring.app.zip`.

You should now have `TrafficMonitoring.app`.

The outer ZIP is GitHub's artifact container. The inner ZIP is intentionally created with macOS `ditto` so the `.app` bundle keeps executable permissions and bundle metadata.

## Launch

You can move `TrafficMonitoring.app` to `/Applications` or run it from Downloads.

Try opening it normally first. If macOS warns that the developer cannot be verified, use **Control-click → Open → Open**.

The CI build is ad-hoc signed for local testing but is not Developer ID signed or notarized. If Gatekeeper still blocks a build that you downloaded from this repository's own successful CI run, remove quarantine from that specific app and open it again:

```bash
xattr -dr com.apple.quarantine /path/to/TrafficMonitoring.app
open /path/to/TrafficMonitoring.app
```

Do not use the quarantine command on apps obtained from untrusted sources.

## Verify the downloaded archive

The artifact also contains `TrafficMonitoring.app.zip.sha256`.

From the directory containing both files:

```bash
shasum -a 256 -c TrafficMonitoring.app.zip.sha256
```

Expected result:

```text
TrafficMonitoring.app.zip: OK
```

## Where the app appears

Traffic Monitoring is an `LSUIElement` menu-bar application, so launching it does not necessarily open a normal main window.

Look for the network icon in the macOS menu bar. From there you can open:

- **Analytics** — currently the M1 live diagnostics surface;
- **Settings** — including optional Wi-Fi network-name permission.

## What this build is for

The downloadable CI artifact is a Release-configuration development build for validating M0/M1 behavior on real Macs. It is built separately from the test host so XCTest bundles and test frameworks are not included in the packaged app.

It is not yet a production distribution build. Production distribution will later require Developer ID signing and notarization so users can launch the app without development-oriented Gatekeeper steps.
