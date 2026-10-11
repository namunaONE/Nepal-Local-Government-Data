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
list** (`PDDPP` = province + district + palika), 751 of 753 coded; `aliases`;
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
**Blocked:** cannot be imported into the core package until the CC-BY
attribution decision (roadmap §9.3 step 2.0) is settled.

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
