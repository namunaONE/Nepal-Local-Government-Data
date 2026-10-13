# Merge sources & provenance

Every external dataset consumed by the merge pipeline is pinned here: the
exact URL, the license, and the retrieval date. **No third-party data is
vendored into this repository** — it lives in `data/_raw/` locally and is
re-fetchable from the URLs below. Integrity is verified against
`data/PROVENANCE.sha256`.

## Why nothing is vendored

1. **Licensing.** Two sources are **CC-BY-4.0**, which requires *visible
   attribution in the distributed package* — a decision that is still open.
2. **Size.** The five sources total ~2.5 MB today; Phase 3 boundary geometry
   alone would add ~46 MB from one source.
3. **Precedent.** `datasets/country-codes` (the closest flagship-grade
   reference for this kind of dataset) ships a fetch script, not the data.

## Source pins

| # | Source | Branch | License | Attribution required | Retrieved |
|---|---|---|---|---|---|
| 1 | `abinrimal/nepal-administrative-divisions-json` | `main` | MIT | No | 2026-10-11 |
| 2 | `sagautam5/local-states-nepal` | `master` | MIT | No | 2026-10-11 |
| 3 | `l3lackcurtains/nepali-geo-pro-max` | `main` | MIT | No | 2026-10-11 |
| 4 | `open-admin-data/nepal-administrative-divisions` | `main` | **CC-BY-4.0** | **Yes** | 2026-10-11 |
| 5 | `opentechcommunity/map-of-nepal` | `master` | **CC-BY-4.0** | **Yes** | *not fetched — Phase 3* |
| 6 | opendatanepal `geographical-codes-for-states-districts-and-local-bodies` (CBS harvest) | CKAN resource IDs, see §6 | **CC-BY** (`license_id: cc-by`, re-verified at fetch) | **Yes — via NOTICE** | 2026-10-11 |

## File-level pins and blob SHAs

`data/PROVENANCE.sha256` records, for every vendored file, its SHA-256, byte
length, and repo-relative path. It is generated from `data/_raw/`.

### 1. abinrimal — `abinrimal/…`

| File | Git tree SHA |
|---|---|
| `provinces.json` | `98a2d877e67df35bb625df87ab124425478750c4` |
| `districts.json` | `36dcf62f7f2dff7ded86f95cba9a63efb91294c9` |
| `local_levels.json` | `ea22335ec04f14eca3b3a189738782b3e872cd1c` |
| `local_level_types.json` | `0079a1105fd3c7e5c0a11c480b902448ac9866fc` |

Tree: `cbecbeae1c29cd0fd93e5f44a850a1a7538e07e7`

**Provides:** Devanagari names (7 provinces, 77 districts, 753 local bodies) —
the most complete bilingual set.
**Defects:** `Gulmi | Chatrakot` appears twice in `local_levels.json`; the
`code` field has only 4 distinct values (type codes, not identifiers).
**Used for:** `nameNe`. **Not used for:** counts, identifiers.

### 2. sagautam5 — `local-states-nepal/…`

| File | Git tree SHA |
|---|---|
| `dataset/provinces/en.json` | `d1ed4158650570c539d2b35729e2f618abc7af90` |
| `dataset/districts/en.json` | `d6854cbe2859bdde48f9f2a313093408bf9430b7` |
| `dataset/municipalities/en.json` | `6ceff9130ed6d5e1e1d9d902d66ee4a017b70409` |
| `dataset/municipalities/np.json` | `a5460712490b5206808d608dc00f6154b66aff83` |

Tree: `035cb3d2ce2420ad04d7aac1d0ce4d08960c57f0`

**Provides:** per-palika **ward counts** (sums to exactly 6,743), district
**headquarters**, province **capitals**, `area_sq_km`, `website`.
**Used for:** `wardCount` (the only source whose total reconciles),
`headquarter`, `capital`, `areaSqKm`, `website`.
**Flag:** `headquarter` / `areaSqKm` / `website` are **single-source**.

### 3. nepali-geo-pro-max — `nepali-geo-pro-max/…`

| File | Git tree SHA |
|---|---|
| `src/data/provinces.ts` | `9c06c176c36b3b822564abffc18a0fe32c6d5599` |
| `src/data/districts.ts` | `21274e0f6bd0aa814ddfefbb1d97f0ce222de4ea` |
| `src/data/local-units.ts` | `1c27389e3d6553db3b9f4ed9d316ea00910691c1` |
| `src/data/legacy-districts.ts` | `aca6f89e7ada8a9bdcc6272162c04019f26d9fff` |
| `src/data/postal-codes.ts` | `eabf8bf540e8494733b17fef67728941f533e0d7` |
| `src/data/postal-codes-2025.ts` | `b866e9a8ceaa8cdf855e5634c899e984e84bfe4d` |

Tree: `117fd0f3d2dabae3bd86bfe9e4c57098ffe56669`

> ⚠️ **Derived, not independent.** Its own header states it was generated from
> `sagautam5/local-states-nepal`. It must **never** be used as an independent
> verification vote.

**Provides:** `postal-codes-2025.ts` carries the **CBS/NSO administrative code
list** (`PDDPP` = province + district + palika), 752 of 753 coded (the single gap is Mahakali Municipality, Kanchanpur = 70905; see doc/REVIEW-codes.md); `aliases`;
province coordinates; two postal-code systems; the legacy 14-zone / 5-region /
75-district cross-walk.
**Defect:** its per-palika ward counts sum to **6,742** (one short) — a
transcription error introduced downstream of sagautam5.
**Used for:** supplementary extraction only.

### 4. open-admin-data — `open-admin-data/…`

Tree pin: dataset updated 2026-09-08; files fetched 2026-10-11.

**Provides:** lat/lon on all levels, JSON Schema, CC-BY-4.0.
**Defect:** ships **775** local units, not 753. **Counts rejected** per the
roadmap hard gate; `geo` retained as supplementary only.
**License status: RESOLVED.** CC-BY-4.0 coordinate/postal/slug fields may be
imported: attribution travels in the shipped package via `NOTICE` (credit +
license link + adaptation note, per CC-BY-4.0 section 3(a)), is surfaced in
`README.md`, and is pinned per-field in this file. `LICENSE` stays MIT for
the package's own code; it does not — and cannot — relicense the adapted
CC-BY-4.0 portions, which remain under their original terms.

### 6. CBS geographical codes via opendatanepal — `cbs-codes/…`

Dataset: `geographical-codes-for-states-districts-and-local-bodies`
(package `22870675-146d-4e4f-8848-2216380170de`), organization
Central Bureau of Statistics, notes "harvested from Central Bureau of
Statistics". License `cc-by` (attribution-only), re-verified at fetch
2026-10-11; metadata unchanged since 2026-06-14.

| File | CKAN resource ID | CKAN MD5 | Bytes |
|---|---|---|---|
| `cbs_districts.csv` | `de973922-7b56-4521-b6a4-aa3de7f8d8a2` | `e7f757371dda9765e310ac78bb2c0d8b` | 3022 |
| `cbs_local_bodies.csv` | `e33aa0f3-72de-4074-a38b-c6a1bf55d9a8` | `78fac72eb1faf0a7913f8c9c58ab3a62` | 75955 |
| `cbs_states.csv` | `37aa60f6-cbbe-43fd-b581-6864b72744ae` | `9ebc36a04637bf976b50af9b24aaa235` | 267 |

Downloads verified MD5-identical to the CKAN metadata before use.
Base download URL pattern:
`https://api.opendatanepal.com/dataset/22870675-146d-4e4f-8848-2216380170de/resource/<id>/download/<file>`

**Provides:** the authoritative CBS hierarchical codes — 77 districts
(`PDD`, 101–709), 753 local bodies (`PDDPP`, 10101–70909), 7 states
(1–7) — plus English and Devanagari names at every level.
**Defects (verified at codepoint level, Step 2):** the districts CSV
Devanagari column is corrupt from row 43 (`NAWALPARASI EAST`) onward —
row 43 truncated mid-parenthetical, rows 44–77 each carry the previous
row's district name (off-by-one cascade). **Quarantined: district
`nameNe` is never sourced from this file.** The palika CSV is guarded by
the suffix-correspondence check in `tool/merge/verify_codes.dart`.
English spellings are UPPERCASE variants (`CHITAWAN`, `DHANUSA`,
`Sub-Metropolitian` [sic]); codes join on codes, names join fuzzy.
**Used for:** `nsoCode` (verified), `nsoCodeVerified`, district-code
resolution, 4th Devanagari vote (palika level, where aligned).

## Ward counts (`verify_wards.dart`, HYA-324)

Per-palika ward counts merge from two 753-row snapshots (sagautam5
`dataset_municipalities_en.json` + geo-pro-max `src_data_local-units.ts`)
with district-scoped exact/alias/fuzzy/containment matching. **Honesty
note:** geo-pro-max derives from sagautam5 (per its header), so snapshot
agreement is a transcription check; the independent check is province-sum
reconciliation against declared totals (different lineage): 745/753
verified, Lumbini fully reconciled (109 units, 983 wards). 8 gaps are
MoFAGA-backed roster defects (ours+CBS vs sag+MoFAGA splits + 2 silent
harvest gaps), recorded in `data/_stage/wards.json` review — never guessed.
Human decision: Janakpurdham 25 (sub-metro official; geo-pro-max stale 24).

## Website basemap (not shipped in the package)

The GitHub Pages explorer renders centroid dots over
OpenStreetMap Standard raster tiles
(`https://tile.openstreetmap.org/{z}/{x}/{y}.png`, maxZoom 19, no API key).
Tiles are fetched at view time by the visitor's browser; no tile data is
vendored. Attribution `© OpenStreetMap contributors` is shown on-map and
in the explorer footer, per the ODbL. Dark mode reuses the same tiles with
a CSS filter (no second tile set, no key). Centroid coordinates themselves
derive from source #4 (open-admin-data, CC-BY-4.0, attributed in NOTICE).

## Re-fetching

```powershell
$sources = @{
  "abinrimal"        = "https://raw.githubusercontent.com/abinrimal/nepal-administrative-divisions-json/main"
  "local-states-nepal" = "https://raw.githubusercontent.com/sagautam5/local-states-nepal/master"
  "nepali-geo-pro-max" = "https://raw.githubusercontent.com/l3lackcurtains/nepali-geo-pro-max/main"
  "open-admin-data"  = "https://raw.githubusercontent.com/open-admin-data/nepal-administrative-divisions/main"
}
# …see tool/merge/inventory.dart for the exact file list per source.
dart run tool/merge/inventory.dart
```

After re-fetching, verify integrity:

```powershell
Get-ChildItem -Recurse -File data\_raw | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  $rel = $_.FullName.Replace((Get-Location).Path + '\data\_raw\','').Replace('\','/')
  "{0}  {1,-8}  {2}" -f $h, $_.Length, $rel
}
# compare against data/PROVENANCE.sha256
```

A mismatch means the upstream source has changed and the merge must be
re-reviewed — **not** silently re-accepted.
