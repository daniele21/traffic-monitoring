# Phase 1–4 implementation status

Compact status for the product/UX work after A0–A2 and the signed B0–B2 prototype.

## Phase 1 — UX/UI overhaul

Status: **implemented; automated build/test gate required, real-Mac visual acceptance still required.**

Implemented:

- native macOS `NavigationSplitView` shell;
- sidebar destinations: Overview / Trends / Networks / Applications / Monitor;
- reusable branded cards, metrics, status pills, hero surface and section headers;
- approved navy / blue / cyan product palette;
- branded but restrained menu-bar popover;
- redesigned Settings outside the old dense grouped form;
- capability-aware copy so expected entitlement absence is not shown as a broken product;
- light/dark-compatible native SwiftUI surfaces.

## Phase 2 — Network analytics refinement

Status: **implemented; real usage validation remains required.**

Implemented:

- Overview hero combining selected-period totals with live network/rates;
- download/upload/peak/coverage summary metrics;
- first-class evidence-quality surface;
- local-history status and top-network insight;
- redesigned Trends line chart and peak highlighting;
- redesigned Networks cards with usage share and metadata badges;
- network detail with identity quality, friendly alias, first/last observed and trend;
- About data / Export preserved as shared evidence actions.

## Phase 3 — Applications Beta cleanup

Status: **implemented.**

Applications now exposes two distinct capability levels:

1. **App Activity Preview** — no Apple Developer Program required;
2. **Advanced Provider** — optional signed Network Extension path.

The UI never presents expected ad-hoc entitlement absence as a setup failure. The signed provider remains visibly experimental and separate from core Analytics.

## Phase 4 — Non-privileged App Activity Preview

Status: **implemented and CI-source-validated; real-Mac UX/coverage validation remains required.**

Implemented:

- local `/usr/bin/nettop` process-summary sampler;
- no system extension / Apple Developer Program requirement;
- process name + PID parsing;
- downloaded / uploaded / total process byte preview;
- ~15-second refresh only while Applications is visible;
- local process search;
- parser tests based on real macOS CI output;
- malformed/unknown input is discarded rather than guessed;
- stable CI smoke test for the `bytes_in,bytes_out` process-summary source;
- explicit evidence boundary in UI and docs;
- preview rows are not persisted and are excluded from evidence export/privacy claims.

Authority for Phase 4 semantics: `non-privileged-app-activity.md`.

## Brand packaging polish

- AppIcon slots use correctly dimensioned shield SVG assets for macOS sizes/scales.
- Menu-bar glyph remains monochrome/native while the full shield is used inside branded identity surfaces.

## Claim boundary

Safe:

> Traffic Monitoring provides polished local network analytics and a best-effort process-level App Activity Preview without requiring an Apple Developer Program. The preview does not classify process traffic as local vs Internet and is not privacy evidence.

The signed Advanced Provider remains the experimental path toward Local / External / Unknown application-flow evidence and is still gated by Apple signing plus real-Mac validation.
