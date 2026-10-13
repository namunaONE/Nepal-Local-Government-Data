# Dataset — Nepal Administrative Data by namunaONE

`nepal_local_levels.json` is the **single source of truth** for every
artifact in this repository: the Dart package (`lib/src/nepal_data.dart`)
is generated from it, and the website explorer (`docs/data.json`) is derived
from it.

- **Data as of:** October 2026
- **Structure:** 7 provinces · 77 districts · 753 local bodies
  (6 metropolitan, 11 sub-metropolitan, 276 municipalities,
  460 rural municipalities) · 6,743 wards
- **Codes (Schema v2 + tiers):** provinces `cbsCode` 1–7 + `isoCode` NP-P1…NP-P7,
  districts `cbsCode` 3-digit, palikas `cbsCode` 5-digit PDDPP +
  `cbsCodeConfidence` (`verified` 548 / `singleSource` 196 / `unverified` 9 —
  744 of 753 palikas carry a code)
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
| `cbsCodeConfidence` | enum | `verified` \| `singleSource` \| `unverified` — see below |
| `nameNe` | string? | Devanagari name; null for 22/753 (never transliterated) |
| `nameNeVerified` | bool | true only when both bilingual sources agree on the spelling |
| `lat` / `lng` | double? | approximate WGS84 centroid; null for 27/753 (never fabricated) |
| `geoSource` | string? | e.g. `open-admin-data`, `osm-nominatim` |
| `wards` | int? | ward count; null for 8/753 pending roster adjudication |
| `wardsVerified` | bool | true only when doubly-attested (sagautam5 + geo-pro-max, incl. documented aliases) |
| `website` / `email` / `phone` | string? | official contact block, single-source (MoFAGA); null for 382/753 |
| `zipCodes` | string[] | Nepal Post postal codes, single-source; empty for 279/753 |

### Bilingual names

`nameNe` is taken from upstream rosters, never transliterated from the English
name: a machine transliteration would be a guess about how a Nepali speaker
spells a place, and the gazette, the building and the voter roll all disagree
with such a guess often enough to matter.

| Level | Named | Corroborated by two sources |
|---|---|---|
| Province | 7/7 | 6/7 |
| District | 77/77 | 77/77 |
| Local body | 731/753 | 450/731 |

`nameNeVerified == false` does **not** mean the name is doubtful. It means the
two rosters spell the same name differently in orthography — 262 pairs differ
only in `ब`/`व`, `ी`/`ि`, the candrabindu, or `प्प`/`प`. Both sources agreed
which palika it is; they disagree on the letters. The published string is the
primary source's.

Names are matched from the **English** name, inside the district, by normalized
name (lowercased, type suffix and parentheticals stripped, punctuation removed)
with Levenshtein distance ≤ 2 and a unique-best-candidate requirement. A tie is
a guess and is refused. Distance 3-4 was measured and rejected: it paired
distinct neighbouring palikas (our "Dhorchaur" taking Bagachour's name,
"Sulikot" taking Ajirkot's).

### Administrative attributes

`headquarter`, `areaSqKm`, `website`, `capital`, `email`, `phone` and
`zipCodes` are all **single-source** and flagged as such in
`data/SOURCES.md`. Where the source has nothing, the field is null or an empty
list — never a plausible-looking value.

### Code confidence tiers

`cbsCodeVerified` is a two-state answer to a one-state question. A code
attested by one authoritative source and a code attested by two are not the
same claim, and collapsing both to `null` used to throw away 197 defensible
codes. `cbsCodeConfidence` records the difference:

| Tier | Count | Rule |
|---|---|---|
| `verified` | 548 | postal-2025 **and** the CBS harvest name the same code for the same entity |
| `singleSource` | 196 | Exactly one same-district, same-type row of the CBS roster within normalized-name Levenshtein distance 2, **or** a pairing forced by elimination inside a district whose roster matches the CBS roster type-for-type |
| `unverified` | 9 | No defensible code. Left `null` — a genuine ambiguity, not an omission |

`cbsCodeVerified` remains exactly the doubly-attested case, so any code
written against v2.x keeps behaving identically.

Two invariants are enforced by `tool/generate.dart`, which refuses to emit a
dataset that violates either:

- **Bijection** — no two palikas may share a code, nationwide.
- **District containment** — every code's PDD prefix must equal the CBS code of
  the district that owns the palika.

Local-body names are **not unique** across Nepal (e.g. `Aurahi` ×3,
`Sunkoshi` ×4) — always pair a name with its district and province.

## Updating the data

One command regenerates every derived artifact, in order, and aborts on the
first failure so nothing can drift silently:

```bash
dart run tool/pipeline.dart            # full regeneration
dart run tool/pipeline.dart --dry-run  # report without writing
```

To change the dataset by hand:

1. Edit `data/nepal_local_levels.json` (update `meta.dataAsOf` and
   `meta.totals`).
2. Run `dart run tool/pipeline.dart`.
3. Run `dart test` — the golden suite re-verifies everything.
4. Commit the JSON and **both** regenerated files
   (`lib/src/nepal_data.dart` and `docs/data.json`) together; CI fails if any
   of the three drift apart.

If the official structure changes (e.g. through a restructuring review ahead
of the 2027 local elections), update the snapshot here, bump the package
version (minor), and note the change in `CHANGELOG.md`.

## Provenance

- Per-field source, license, retrieval date: `data/SOURCES.md`
- SHA-256 manifest: `data/PROVENANCE.sha256`
- Merge pipeline: `tool/pipeline.dart` (wrapping `tool/merge/`)
- Per-tier evidence: `data/_stage/code_tiers.json`
- Per-palika bilingual evidence: `data/_stage/bilingual.json`

Steps 4 and 5 of the pipeline are **order-dependent**: the MoFAGA harvest
carries no codes, so `attach_attributes` joins palikas by their Devanagari
name, which only exists once `attach_bilingual` has run. Running them out of
order attaches nothing and fails silently, which is why the pipeline — not the
individual tools — is the documented entry point.
- Human decisions: `data/_stage/decisions_manual.json`
- Maintained by **namunaONE** under **HyaMuji** and **Taire Bhai**.
