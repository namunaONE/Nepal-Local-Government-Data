# Dataset — Nepal Administrative Data by namunaONE

`nepal_local_levels.json` is the **single source of truth** for every
artifact in this repository: the Dart package (`lib/src/nepal_data.dart`)
is generated from it, and the website explorer (`docs/data.json`) is derived
from it.

- **Data as of:** October 2026
- **Structure:** 7 provinces · 77 districts · 753 local bodies
  (6 metropolitan, 11 sub-metropolitan, 276 municipalities,
  460 rural municipalities) · 6,743 wards
- **Codes (Schema v2):** provinces `cbsCode` 1–7 + `isoCode` NP-P1…NP-P7,
  districts `cbsCode` 3-digit, palikas `cbsCode` 5-digit PDDPP +
  `cbsCodeVerified` bool (547/753 verified, 73%)
- **Basis:** the federal structure established by the Local Level
  Restructuring Commission (2017) under the Constitution of Nepal (2015),
  cross-checked against Ministry of Federal Affairs and General
  Administration (MoFAGA) references.

## Schema (v2)

| Field | Type | Notes |
|---|---|---|
| `meta.dataAsOf` | string | date the snapshot was verified |
| `meta.totals` | object | expected national counts — validated by the generator and the golden tests |
| `provinces[].id` | string | lowercase slug (`koshi`, …) |
| `provinces[].name` | string | display name |
| `provinces[].cbsCode` | int | 1–7 |
| `provinces[].isoCode` | string | `NP-P1`…`NP-P7` |
| `provinces[].wards` | int | total wards in the province |
| `provinces[].districts[].name` | string | district name |
| `provinces[].districts[].cbsCode` | int | 3-digit (e.g. `306` Kathmandu) |
| `provinces[].districts[].localBodies[]` | object | `{ "name", "type", "cbsCode?", "cbsCodeVerified?" }` |
| `type` | enum | `metropolitan` \| `subMetropolitan` \| `municipality` \| `ruralMunicipality` |
| `cbsCode` | int? | 5-digit PDDPP: P=province, DD=district, PP=palika; null when unverified |
| `cbsCodeVerified` | bool | true only when doubly-attested (CBS + Postal-2025) |
| `lat` / `lng` | double? | approximate WGS84 centroid; null for 27/753 (never fabricated) |
| `geoSource` | string? | e.g. `open-admin-data`, `osm-nominatim` |

Local-body names are **not unique** across Nepal (e.g. `Aurahi` ×3,
`Sunkoshi` ×4) — always pair a name with its district and province.

## Updating the data

1. Edit `data/nepal_local_levels.json` (update `meta.dataAsOf` and
   `meta.totals`).
2. Run `dart run tool/generate.dart` — it validates the data against the
   official counts, then regenerates `lib/src/nepal_data.dart`.
3. Run `dart run tool/generate_explorer_data.dart` — regenerates
   `docs/data.json` for the website explorer.
4. Run `dart test` — the golden suite re-verifies everything.
5. Commit the JSON and the regenerated Dart file **together**;
   CI fails if they drift apart.

If the official structure changes (e.g. through a restructuring review ahead
of the 2027 local elections), update the snapshot here, bump the package
version (minor), and note the change in `CHANGELOG.md`.

## Provenance

- Per-field source, license, retrieval date: `data/SOURCES.md`
- SHA-256 manifest: `data/PROVENANCE.sha256`
- Merge pipeline: `tool/merge/` (`inventory` → `match` → `adjudicate` →
  `verify_codes` → `apply_cbs_codes`)
- Human decisions: `data/_stage/decisions_manual.json`
- Maintained by **namunaONE** under **HyaMuji** and **Taire Bhai**.
