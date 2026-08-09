# Brand system

Authoritative visual identity for Traffic Monitoring. Read only for UI, README, logo, app icon, chart, or product-language work.

## Identity

Primary symbol: **shield + Wi-Fi signal + upward usage trend**.

Use:

- shield symbol for macOS app icon and compact identity surfaces;
- shield + product name in primary app identity/header surfaces;
- simplified monochrome shield treatment in the macOS menu bar;
- full approved lockup in external marketing surfaces when available.

The logo may feel premium and dimensional. Product UI stays flat, restrained, native, and highly legible.

## Personality

- **Reliable** — accurate, calm, dependable.
- **In control** — visibility without alarmism.
- **Technical** — credible, never cryptic.
- **Direct** — plain labels and obvious actions.

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

- Royal Blue — primary selection/action/series emphasis.
- Network Blue — standard network/data emphasis and app tint.
- Signal Cyan — live state, hotspot emphasis and meaningful peaks.
- Midnight / Deep Navy — identity framing/headings.
- Green / amber / red — semantic state only.

## Typography

- macOS UI: SF Pro Text / SF Pro Display.
- Fallback: Inter.
- Technical aligned metrics: SF Mono where useful.
- Regular for body, Semibold for labels, Bold only for key metrics.

## Product language

Prefer:

- `Total used`
- `Downloaded`
- `Uploaded`
- `Current network`
- `Usage by network`
- `Peak usage`
- `Applications`
- `Local`
- `External`
- `Unknown`
- `Not validated`

Keep raw counters, deltas, interface names, audit tokens, and provider internals inside Monitor/developer diagnostics.

## Data visualization

- stable colors for network series;
- Signal Cyan only for live/peak/high-attention evidence;
- avoid heavy fills and decorative gradients;
- always show unit and timeframe;
- use direct labels when readable;
- do not use color alone to communicate evidence quality.

## Advanced Observability styling

Advanced mode should look like part of the same product, not a separate security tool.

- Blue = normal selected/active UI.
- Cyan = live flow activity where useful.
- Green = validated/healthy only.
- Amber = approval required, experimental, or meaningful caution.
- Red = actual failure/degraded state, not merely unavailable entitlement in an ad-hoc development build.
- `Unknown` and `Not validated` must be visually explicit but calm.

## App surfaces

- support light/dark mode;
- use native macOS spacing and rounded cards;
- avoid excessive chrome;
- use the shield mainly in identity surfaces, not every metric card;
- menu bar remains compact and monochrome at system level;
- system-extension approval/conflict copy must be factual and actionable.

## Repository assets

Canonical compiled assets:

```text
TrafficMonitoring/Resources/BrandAssets.xcassets/
├── AccentColor.colorset/
├── AppIcon.appiconset/
└── BrandShield.imageset/
```

The app icon and in-product shield follow the approved shield direction. The README renders the same repository shield asset so product and repository identity stay aligned.
