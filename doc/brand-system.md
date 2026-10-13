# Brand System v2 — Himalayan Trust × Everest Growth

Seed colors:

- **Primary seed (Trust Navy):** `#002C6D` — HCT h268.6 c43.2 t19.7
- **Secondary seed (Growth Green):** `#4FD166` — HCT h148.5 c68.6 t75.0

This document explains how Flutter Material 3 (M3) turns seeds into
a full tonal system, and how this repo maps it to web (CSS) + Flutter.

## 1. How Flutter M3 works (mental model)

`ColorScheme.fromSeed(seedColor: ...)` does NOT use the seed directly
as `primary`. It:

1. Converts seed to HCT (Hue-Chroma-Tone).
2. Builds 5 `TonalPalette`s (each 13 tones: 0–100):
   - `primary` — hue of seed, chroma max(48, seed chroma)
   - `secondary` — hue of seed, chroma 16 (muted harmony)
   - `tertiary` — hue + 60, chroma 24 (contrast accent)
   - `neutral` — hue of seed, chroma 6 (surfaces)
   - `neutralVariant` — hue of seed, chroma 8 (borders)
   - `error` — fixed hue 25, chroma 84
3. Picks fixed tones per role. Light vs dark swaps tones.

If you pass `secondary:` to `fromSeed`, Flutter replaces the
`secondary` palette with `TonalPalette.of(secondarySeed)` — full
chroma. That is what the premium brand does.

### TonalSpot (Flutter default, `Variant.tonalSpot`)

| Palette | Hue | Chroma | Source |
|---|---|---|---|
| primary | 268.6 | 36.0 | `#002C6D` |
| secondary | 268.6 | 16.0 | `#002C6D` (default) |
| tertiary | 328.6 | 24.0 | hue+60 |
| neutral | 268.6 | 6.0 | `#002C6D` |
| neutralVariant | 268.6 | 8.0 | `#002C6D` |
| error | 25 | 84 | fixed |

> Premium override: `secondary` palette = raw `#4FD166`
> (h148.5, c68.6) — see §3.

## 2. M3 color roles (what each does)

Accent:

- `primary` — main CTA, active states, FAB. White/black text via `onPrimary`.
- `onPrimary` — text/icon on `primary`.
- `primaryContainer` — highlighted section bg. Text via `onPrimaryContainer`.
- `onPrimaryContainer` — text on container.
- `primaryFixed` / `onPrimaryFixed` / `primaryFixedDim` /
  `onPrimaryFixedVariant` — fixed-step宣传, same in light+dark (calendars, badges).

Secondary (support actions, chips, filters):

- `secondary`, `onSecondary`, `secondaryContainer`,
  `onSecondaryContainer`, + `*Fixed` variants — same pattern.

Tertiary (contrast accent, maps, illustrations):

- `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer`.

Error:

- `error`, `onError`, `errorContainer`, `onErrorContainer`.

Surfaces (backgrounds — M3 Expressive adds 5 levels):

- `surfaceDim`, `surface`, `surfaceBright`
- `surfaceContainerLowest/Low/Container/High/Highest` — layered cards.
- `onSurface`, `onSurfaceVariant` — body + secondary text.
- `outline`, `outlineVariant` — borders/dividers.
- `inverseSurface`, `onInverseSurface`, `inversePrimary` — tooltips, snackbars.
- `surfaceTint` — tint overlay (usually `primary`).
- `scrim`, `shadow` — overlays.

Rule: never use palette tones directly in UI. Always use roles.
Tones are primitives; roles are semantics.

## 3. Full tonal tables (verified via `material_color_utilities` 0.13.1)

### 3a. Primary raw (`#002C6D`, h268.6 c43.2)

| Tone | Hex |
|---|---|
| 0 | `#000000` |
| 5 | `#000F30` |
| 10 | `#001945` |
| 15 | `#002359` |
| 20 | `#012D6E` |
| 25 | `#153879` |
| 30 | `#234485` |
| 35 | `#315092` |
| 40 | `#3E5C9F` |
| 50 | `#5875BA` |
| 60 | `#728FD5` |
| 70 | `#8CAAF2` |
| 80 | `#B0C6FF` |
| 90 | `#D9E2FF` |
| 95 | `#EEF0FF` |
| 98 | `#FAF8FF` |
| 99 | `#FEFBFF` |
| 100 | `#FFFFFF` |

### 3b. Secondary raw (`#4FD166`, h148.5 c68.6)

| Tone | Hex |
|---|---|
| 0 | `#000000` |
| 5 | `#001503` |
| 10 | `#002107` |
| 15 | `#002D0B` |
| 20 | `#003910` |
| 25 | `#004616` |
| 30 | `#00531B` |
| 35 | `#006021` |
| 40 | `#006E27` |
| 50 | `#008A33` |
| 60 | `#15A742` |
| 70 | `#3FC35A` |
| 80 | `#5EE072` |
| 90 | `#7CFD8C` |
| 95 | `#C7FFC4` |
| 98 | `#EBFFE6` |
| 99 | `#F6FFF1` |
| 100 | `#FFFFFF` |

### 3c. Derived tonalSpot palettes from `#002C6D`

Primary (c36):

`0 #000000, 5 #000F30, 10 #001945, 15 #062355, 20 #152E60, 25 #223A6C, 30 #2E4578, 35 #3A5185, 40 #475D92, 50 #6076AC, 60 #7990C8, 70 #94AAE4, 80 #B0C6FF, 90 #D9E2FF, 95 #EEF0FF, 98 #FAF8FF, 99 #FEFBFF, 100 #FFFFFF`

Secondary (h268.6 c16):

`0 #000000, 5 #091121, 10 #141B2C, 15 #1F2536, 20 #293042, 25 #343B4D, 30 #404659, 35 #4B5265, 40 #575E71, 50 #70778B, 60 #8A90A5, 70 #A4ABC0, 80 #C0C6DC, 90 #DCE2F9, 95 #EEF0FF, 98 #FAF8FF, 99 #FEFBFF, 100 #FFFFFF`

Tertiary (h328.6 c24):

`0 #000000, 5 #1E0821, 10 #2A132C, 15 #351D37, 20 #412742, 25 #4D324E, 30 #593D5A, 35 #654966, 40 #725572, 50 #8C6D8C, 60 #A786A6, 70 #C3A0C2, 80 #E0BBDE, 90 #FDD7FA, 95 #FFEBFB, 98 #FFF7FA, 99 #FFFBFF, 100 #FFFFFF`

Neutral (c6):

`0 #000000, 5 #0F1116, 10 #1A1B20, 15 #24262B, 20 #2F3036, 25 #3A3B41, 30 #45464C, 35 #515258, 40 #5D5E64, 50 #76777D, 60 #909097, 70 #ABABB1, 80 #C6C6CD, 90 #E2E2E9, 95 #F1F0F7, 98 #FAF8FF, 99 #FEFBFF, 100 #FFFFFF`

NeutralVariant (c8):

`0 #000000, 5 #0E1118, 10 #191B23, 15 #23262D, 20 #2E3038, 25 #393B43, 30 #44464F, 35 #50525A, 40 #5C5E67, 50 #757780, 60 #8F9099, 70 #A9ABB4, 80 #C5C6D0, 90 #E1E2EC, 95 #EFF0FA, 98 #FAF8FF, 99 #FEFBFF, 100 #FFFFFF`

Error (fixed):

`0 #000000, 5 #2D0001, 10 #410002, 15 #540003, 20 #690005, 25 #7E0007, 30 #93000A, 35 #A80710, 40 #BA1A1A, 50 #DE3730, 60 #FF5449, 70 #FF897D, 80 #FFB4AB, 90 #FFDAD6, 95 #FFEDEA, 98 #FFF8F7, 99 #FFFBFF, 100 #FFFFFF`

## 4. Premium dual-seed mapping (this brand)

Flutter default `secondary` (`#575E71`) is too grey for a green brand.
Premium keeps primary/neutral/tertiary from `#002C6D` and swaps in the
green raw palette for secondary roles:

| Role | Light | Dark | Note |
|---|---|---|---|
| primary | `#475D92` (p40) | `#B0C6FF` (p80) | trust |
| onPrimary | `#FFFFFF` | `#152E60` (p20) | |
| primaryContainer | `#D9E2FF` (p90) | `#2E4578` (p30) | |
| onPrimaryContainer | `#2E4578` (p30) | `#D9E2FF` (p90) | |
| secondary | `#006E27` (g40) | `#5EE072` (g80) | growth — brand override |
| onSecondary | `#FFFFFF` | `#003910` (g20) | |
| secondaryContainer | `#7CFD8C` (g90) | `#00531B` (g30) | |
| onSecondaryContainer | `#002107` (g10) | `#EBFFE6` (g98) | darker text for neon container |
| tertiary | `#725572` (t40) | `#E0BBDE` (t80) | muted plum balances blue+green |
| onTertiary | `#FFFFFF` | `#412742` (t20) | |
| tertiaryContainer | `#FDD7FA` (t90) | `#593D5A` (t30) | |
| error | `#BA1A1A` | `#FFB4AB` | fixed |
| surface | `#FAF8FF` (n98) | `#121318` (n6) | |
| surfaceDim | `#DAD9E0` | `#121318` | |
| surfaceBright | `#FAF8FF` | `#38393F` | |
| lowest/low/container/high/highest (light) | `#FFFFFF` / `#F4F3FA` / `#EEEDF4` / `#E8E7EF` / `#E2E2E9` | — | |
| lowest/low/container/high/highest (dark) | — | `#0C0E13` / `#1A1B20` / `#1E1F25` / `#282A2F` / `#33353A` | |
| onSurface | `#1A1B20` | `#E2E2E9` | |
| onSurfaceVariant | `#44464F` | `#C5C6D0` | |
| outline | `#757780` | `#8F9099` | |
| outlineVariant | `#C5C6D0` | `#44464F` | |
| inverseSurface | `#2F3036` | `#E2E2E9` | |
| onInverseSurface | `#F1F0F7` | `#2F3036` | |
| inversePrimary | `#B0C6FF` | `#475D92` | |
| surfaceTint | `#475D92` | `#B0C6FF` | |
| scrim/shadow | `#000000` | `#000000` | |

Contrast: `primary #475D92` on white ≈ 6.0:1; `secondary #006E27`
on white ≈ 5.9:1; both AA for body text. Green container `#7CFD8C`
must use dark text `#002107` (≈12:1), never white.

Usage:

- Navy owns navigation, headers, primary buttons, links, focus rings.
- Green owns success, verified badges, map markers (rural), progress, secondary CTAs.
- Never place green text on navy without 15% white overlay — use
  container + dark text instead.
- Gradient (hero only): `linear-gradient(135deg, #002C6D, #004616 55%, #15A742)` — 60/30/10 navy/surface/green.

## 5. Flutter usage

See `example/brand_theme.dart`:

```dart
// 1. Base from navy seed (gives primary/tertiary/neutral/surfaces).
final base = ColorScheme.fromSeed(
  seedColor: const Color(0xFF002C6D),
  brightness: Brightness.light,
);
// 2. Override secondary with verified green tones.
// NOTE: `secondary: Color(0xFF4FD166)` alone is NOT enough — Flutter
// uses it raw (white text fails). Always copyWith tonal roles:
final light = base.copyWith(
  secondary: const Color(0xFF006E27), // g40
  onSecondary: const Color(0xFFFFFFFF),
  secondaryContainer: const Color(0xFF7CFD8C), // g90
  onSecondaryContainer: const Color(0xFF002107), // g10
);
```

Without any override you get grey `#575E71`. See `example/brand_theme.dart`
for the full verified `copyWith` (light + dark + fixed roles).

Web mirror: `docs/brand-tokens.css` exposes the same roles as
`--md-*` variables; `docs/brand.html` is the visual proof.

## 6. Files

- `doc/brand-system.md` — this spec
- `docs/brand-tokens.css` — CSS variables (`--brand-*`, `--md-*`)
- `docs/brand.html` — swatches + components preview
- `example/brand_theme.dart` — Flutter `ThemeData` + component themes
