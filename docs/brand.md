# Brand system

This document is authoritative for Traffic Monitoring visual identity and product-language styling.

Read it only for UI, visual, README or brand-asset work.

## Identity

Primary symbol: shield + Wi-Fi signal + upward usage trend.

Use:

- shield symbol for the macOS app icon and compact identity surfaces;
- full Traffic Monitoring lockup where the product name must be explicit;
- simplified monochrome shield/signal treatment in the macOS menu bar.

The logo may feel premium and dimensional. Product UI should remain flat, restrained and highly legible.

## Personality

- Reliable — accurate, calm, dependable.
- In control — visibility without alarmism.
- Technical — credible, never cryptic.
- Direct — plain labels and obvious actions.

## Brand colors

```text
Midnight       #020D2C
Deep Navy      #0E2345
Royal Blue     #002996
Network Blue   #207CCE
Signal Cyan    #0DC1F9
Surface        #F2F7FD
Dark UI        #10141A
Healthy        #22C55E
Warning        #F59E0B
Critical       #EF4444
```

Usage:

- Royal Blue — selection, primary actions, primary network series.
- Network Blue — standard network/data emphasis.
- Signal Cyan — live activity, hotspot emphasis and meaningful peaks.
- Midnight / Deep Navy — high-trust identity framing and headings.
- Green / amber / red — status only, not decorative branding.

## Typography

- macOS UI: SF Pro Text / SF Pro Display.
- Fallback: Inter.
- Technical aligned metrics: SF Mono when useful.
- Regular for body, Semibold for labels, Bold for key metrics only.

## Product language

Prefer:

- `Total used`
- `Downloaded`
- `Uploaded`
- `Current network`
- `Usage by network`
- `Peak usage`

Keep technical terms such as raw counters, deltas and interface names inside Monitor/diagnostics rather than primary analytics.

## Data visualization

Charts are precise and calm rather than decorative.

- use stable network-series colors;
- reserve Signal Cyan for live state or meaningful peaks;
- avoid heavy area fills and decorative gradients;
- always show units and timeframe;
- prefer direct labels when readable;
- keep network identity/color stable within a view.

## App surfaces

- support light and dark mode;
- use native macOS spacing and rounded cards;
- avoid excessive chrome;
- use the shield primarily for identity surfaces rather than repeating it inside every metric card;
- advanced/experimental states should use clear status copy, not dramatic warnings.

## Repository assets

Canonical app assets live in:

```text
TrafficMonitoring/Resources/BrandAssets.xcassets/
```

They are derived from the approved shield symbol and wordmark supplied with the brand kit.
