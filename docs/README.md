# Website — Nepal Administrative Data by namunaONE

Static documentation site deployed via GitHub Pages from `docs/`.

- **Live:** https://namunaONE.github.io/Nepal-Local-Government-Data/
- **Pages:** `index.html` (landing), `api.html` (reference),
  `explorer.html` (interactive table over `data.json`)
- **Assets:** `logo.svg` (icon), `logo-full.svg` (icon + wordmark),
  `favicon.svg`, `styles.css`, `app.js`, `data.json`
- **No build step.** Pure HTML/CSS/JS. `.nojekyll` disables Jekyll.

## Design system

`styles.css` is the single source of truth:

1. **Primitive tokens** — palette scales (`--slate-*`, `--nepal-*`,
   status scales). Never use directly in components.
2. **Semantic tokens** — `--color-primary`, `--color-bg`, `--color-text`,
   `--color-border`, `--color-success/warning/danger/info`.
3. **Typography** — `--text-xs`…`--text-5xl`, `--leading-*`,
   `--weight-*`, `--tracking-*`. Body: Inter; code: JetBrains Mono.
4. **Spacing** — `--space-1`…`--space-20`. Radius `--radius-*`.
   Elevation `--shadow-*`. Motion `--transition*`.
5. **Iconography** — `--icon-xs`…`--icon-xl` (14/16/20/24/32px),
   `currentColor` stroke icons, `.theme-icon` sun/moon swap.
6. **Components** — `.btn` (+primary/secondary/ghost/danger/sm/lg),
   `.badge` (+neutral/success/warning/danger/info), `.card`,
   `.alert-*`, `.code-block`, `.explorer-table`, `.pagination`,
   `.toast`, `.maintainer-badge`.

Dark mode: `html.dark` class (JS toggle + `localStorage`), with
`prefers-color-scheme` as first-visit default. Honor
`prefers-reduced-motion` and print styles.

## Logo

- `logo.svg` — double-pennon mark: Nepal crimson `#DC143C`,
  Nepal blue `#003893`, white moon/sun/Himalaya, 7 province dots.
- `logo-full.svg` — mark + “Nepal Administrative Data” +
  “7 provinces · 77 districts · 753 palikas” + “BY namunaONE”.
- `favicon.svg` — 64px rounded version for browsers.
- Header uses `logo.svg` + stacked wordmark; hero uses `logo-full.svg`;
  footer reuses `logo.svg`.

## Regenerating explorer data

```bash
dart run tool/generate_explorer_data.dart
# reads data/nepal_local_levels.json → writes docs/data.json (753 rows)
```

## Local preview

```bash
cd docs
python -m http.server 8000
# open http://localhost:8000/index.html
```

Maintained by **namunaONE** under **HyaMuji** and **Taire Bhai**.
