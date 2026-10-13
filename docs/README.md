# Website — Nepal Administrative Data by namunaONE

Static documentation site deployed via GitHub Pages from `docs/`.

- **Live:** https://namunaONE.github.io/Nepal-Local-Government-Data/
- **Pages:** `index.html` (landing), `api.html` (reference),
  `explorer.html` (interactive table + centroid map over `data.json`)
- **Assets:** `logo.svg` (icon), `logo-full.svg` (icon + wordmark),
  `favicon.svg`, `styles.css`, `app.js`, `data.json`
- **Cache policy:** asset URLs carry `?v=N` (bump on every visual/data
  change; `DATA_URL` in `app.js` likewise) so returning visitors never
  run mixed old/new bundles after a deploy.
- **No build step.** Pure HTML/CSS/JS. `.nojekyll` disables Jekyll.

## Design system

`styles.css` is the single source of truth (Design System v1.1):

1. **Primitive tokens** — palette scales (`--slate-*`, `--nepal-*`,
   status scales). Never use directly in components.
2. **Semantic tokens** — `--color-primary`, `--color-bg`, `--color-text`,
   `--color-border`, `--color-success/warning/danger/info`.
3. **Fluid typography + spacing** — `--text-*` and `--space-*` use
   `clamp()` (rem anchors + vw interpolation); no breakpoint-jumps.
4. **Layout primitives** — `.stack`, `.cluster`, `.grid-auto`; card grids
   use container queries (`container-type: inline-size`).
5. **Iconography** — `--icon-xs`…`--icon-xl` (14/16/20/24/32px),
   `currentColor` stroke icons, `.theme-icon` sun/moon swap.
6. **Components** — `.btn` (+primary/secondary/ghost/danger/sm/lg),
   `.badge` (+neutral/success/warning/danger/info), `.card`,
   `.alert-*`, `.code-block`, `.explorer-table` (sticky header +
   scroll-shadow hint), `.pagination`, `.toast`, `.maintainer-badge`.
7. **Nav** — sticky blurred header, floating pill on scroll (`.scrolled`,
   passive rAF listener), hamburger panel ≤860px (aria-expanded,
   Escape/outside-click close), 44px touch targets.
8. **Map** — fluid height `clamp(300px, 52vh, 460px)`, dark-filtered tiles,
   themed Leaflet controls/popups.
9. **Badges** — explicit `TYPE_META` map (class + short label + full-name
   tooltip); `.type-unknown` fallback; filter dropdown uses short labels.
   Never derive chip classes via chained string replaces.

Dark mode: `html.dark` class (JS toggle + `localStorage`), with
`prefers-color-scheme` as first-visit default. Honor
`prefers-reduced-motion` and print styles.

## Logo

- `logo.svg` — double-pennon mark: Nepal crimson `#DC143C`,
  Nepal blue `#003893`, white moon/sun/Himalaya, 7 province dots.
- `logo-full.svg` — mark + “Nepal Administrative Data” +
  “7 provinces · 77 districts · 753 palikas” + “BY namunaONE”.
- `favicon.svg` — 64px rounded version for browsers.
- `logo-full-dark.svg` — dark-mode wordmark (light text); swapped by JS
  via `data-logo-light`/`data-logo-dark` because SVG `<img>` cannot read
  page classes. `logo-full.svg` also carries a `prefers-color-scheme`
  media fallback for no-JS.
- Header uses `logo.svg` + stacked wordmark; hero uses `logo-full.svg`;
  footer reuses `logo.svg`.

## AI docs (llms.txt)

- `llms.txt` — spec-compliant index (single H1, ≤50-word blockquote
  summary, H2 sections, absolute-URL links with descriptions). Served at
  site root; footer-linked from every page.
- `llms-full.txt` — complete documentation in one file for deep ingestion.
  Hand-maintained alongside releases (install, quickstart, full API
  signatures, code formats, verification stats, known gaps, links).
  Update both when the API, coverage numbers, or version change.

## Map

Explorer embeds a Leaflet 1.9.4 + markercluster 1.5.3 dot map (lazy-loaded,
CDN, only on `explorer.html`):

- Tiles: OSM Standard keyless, maxZoom 19, `© OpenStreetMap contributors`
  on-map + footer. Dark mode reuses the same tiles with a CSS filter
  (no second tile set, no API key).
- Markers: canvas circleMarkers colored by type (badge tokens), hollow
  when CBS-unverified; clusters via `chunkedLoading` +
  `removeOutsideVisibleBounds`.
- Sync: filters/search rebuild markers (all filtered, not just the page);
  table-row click/Enter flies to the marker; `?cbs=31304` deep-links.
- Tile factory is a single `MAP_TILES` constant + `createTileLayer()` in
  `app.js` so a future vector/PMTiles migration is surgical.

## Regenerating explorer data

```bash
dart run tool/generate_explorer_data.dart
# reads data/nepal_local_levels.json → writes docs/data.json (753 rows,
# incl. lat/lng/geoSource where mapped: 726/753)
```

## Local preview

```bash
cd docs
python -m http.server 8000
# open http://localhost:8000/index.html
```

## Smoke test (no browser, no npm deps)

`node docs/smoke.cjs` loads the real `app.js` in Node with minimal DOM
stubs and runs the full explorer flow (fetch → filters → stats → table →
pagination) against the real `data.json`. It catches ReferenceError/scope
bugs that `node --check` (syntax-only) misses — e.g. the `escapeHtml is
not defined` outage, where a module-scope caller used an
initExplorer-scoped helper. Runs in CI before Pages deploy.

Maintained by **namunaONE** under **HyaMuji** and **Taire Bhai**.
