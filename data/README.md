# Dataset — Nepal local government structure

`nepal_local_levels.json` is the **single source of truth** for every
artifact in this repository: the Dart package (`lib/src/nepal_data.dart`)
is generated from it, and the React explorer consumes it directly.

- **Data as of:** October 2026
- **Structure:** 7 provinces · 77 districts · 753 local bodies
  (6 metropolitan, 11 sub-metropolitan, 276 municipalities,
  460 rural municipalities) · 6,743 wards
- **Basis:** the federal structure established by the Local Level
  Restructuring Commission (2017) under the Constitution of Nepal (2015),
  cross-checked against Ministry of Federal Affairs and General
  Administration (MoFAGA) references.

## Schema

| Field | Type | Notes |
|---|---|---|
| `meta.dataAsOf` | string | date the snapshot was verified |
| `meta.totals` | object | expected national counts — validated by the generator and the golden tests |
| `provinces[].id` | string | lowercase slug (`koshi`, …) |
| `provinces[].name` | string | display name |
| `provinces[].wards` | int | total wards in the province |
| `provinces[].districts[].name` | string | district name |
| `provinces[].districts[].localBodies[]` | object | `{ "name": …, "type": … }` |
| `type` | enum | `metropolitan` \| `subMetropolitan` \| `municipality` \| `ruralMunicipality` |

Local-body names are **not unique** across Nepal (e.g. `Aurahi` ×3,
`Sunkoshi` ×4) — always pair a name with its district and province.

## Updating the data

1. Edit `data/nepal_local_levels.json` (update `meta.dataAsOf` and
   `meta.totals`).
2. Run `dart run tool/generate.dart` — it validates the data against the
   official counts, then regenerates `lib/src/nepal_data.dart`.
3. Run `dart test` — the golden suite re-verifies everything.
4. Commit the JSON and the regenerated Dart file **together**;
   CI fails if they drift apart.

If the official structure changes (e.g. through a restructuring review ahead
of the 2027 local elections), update the snapshot here, bump the package
version (minor), and note the change in `CHANGELOG.md`.
