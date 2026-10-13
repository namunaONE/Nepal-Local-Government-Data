# Bindings

Everything in this directory is **generated**. Do not edit any file here by
hand — edit `data/nepal_local_levels.json` and run:

```bash
dart run tool/generate_bindings.dart      # or: dart run tool/pipeline.dart
```

CI regenerates and diffs the output, so a binding can never disagree with the
Dart package. Output is byte-stable (fixed ordering, LF endings, no
timestamps), which is what makes that check a plain `git diff`.

| Path | What it is | Verified by |
|---|---|---|
| `csv/` | `provinces.csv`, `districts.csv`, `local_bodies.csv` | `bindings/verify_bindings.cjs` |
| `geojson/` | Centroid FeatureCollections, RFC 7946 WGS84 | `bindings/verify_bindings.cjs` |
| `javascript/` | npm package `nepal-admin-data` (`index.js`, `index.d.ts`) | `bindings/verify_bindings.cjs` |
| `python/` | PyPI package `nepal-admin-data` (stdlib only) | CI job (needs Python) |
| `meta.json` | Version, dataAsOf, coverage counters | — |

## Why these shapes

- **CSV** — because the most common real use is a pandas merge or a
  spreadsheet, and copying 753 rows by hand is the thing this project exists
  to stop.
- **GeoJSON centroids** — so a map works today. Boundary polygons are *not*
  included: the only vendored geometry ships 777 features against the gazetted
  753 and is quarantined pending review (`data/SOURCES.md`). Centroids now
  means a polygon layer can be added later without changing this contract.
- **JavaScript / Python** — same numbers and the same API shape as the Dart
  package, so moving between them is a rename, not a rewrite.

All three bindings expose the same honesty guarantees as the Dart package:
absent means absent (`null` / omitted), confidence tiers are explicit, and
nothing is fabricated to fill a column.

## Verification status

- JavaScript, CSV and GeoJSON are executed and asserted locally against the
  source dataset on every run (`bindings/verify_bindings.cjs`).
- The Python binding is **generated and reviewed but not executed locally** —
  the development machine used for this release has no Python interpreter. It
  is exercised in CI, which is the first place it is actually run.

## Not here

- **Ward-level records.** No vendored source names individual wards, so
  `wards` is a count. See `data/SOURCES.md` § "Ward-level records".
- **Boundary polygons.** See above.

Generated 21 files · version 2.7.0 · data as of 2026-10-13.
