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
| 5 | `opentechcommunity/map-of-nepal` | `master` | **CC-BY-4.0** | **Yes** | 2026-10-13 |
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

## Code confidence tiers (`resolve_code_tiers.dart`, v2.4.0)

`verify_codes.dart` is deliberately strict: a code is `verified` only when
postal-2025 and the CBS harvest independently name the same code for the same
entity. That rule is right, but it left **206 of 753 palikas with
`cbsCode == null`** even though the CBS roster names every one of them — so a
consumer building a code-keyed map to join against government datasets was
silently dropping over a quarter of Nepal's local bodies.

`resolve_code_tiers.dart` keeps the strict tier and adds a weaker one that is
**published with an honest label rather than discarded**:

- `verified` (548) — unchanged: doubly-attested.
- `singleSource` (196) — one attestation from the authoritative CBS roster.
  Accepted only when **all** of these hold:
  1. the row is in the same district (PDD prefix match),
  2. its palika type agrees after canonicalising the harvest's own dialect
     (`Metropolitian`, `Municipaity`, `Gaun Palika`, `Gaunpaika` — see
     `cbsTypeToCanonical` in `tool/merge/common.dart`),
  3. its normalized name is within Levenshtein distance 2 of ours, **and is
     the unique best such candidate** (a tie is a guess, so it is refused), or
     the pairing is forced by elimination — exactly one of our palikas and
     exactly one free CBS row of that type remain in a district whose roster
     matches the CBS roster type-for-type.
- `unverified` (9) — no defensible code; `cbsCode` stays null. These are
  genuine ambiguities (several unclaimed same-type rows in one district, where
  any assignment would be a permutation guess), not omissions.

Two invariants are machine-enforced, so a wrong code cannot ship:

- **Bijection** — the assignment set is forced one-to-one; no two palikas can
  share a code.
- **District containment** — every code's PDD prefix must equal the CBS code of
  its owning district. `tool/generate.dart` re-checks both and refuses to emit.

Per-record evidence for all 753 palikas is written to
`data/_stage/code_tiers.json`.

> **Honesty note.** `singleSource` is *one* source, not two. It is offered for
> joins and clearly labelled; anything load-bearing (payments, statutory
> filings, addressing) should use `verified` only.

## Boundaries (source 5) — pinned, geometry quarantined

`data/_raw/boundaries/oknp_local_levels.{geojson,topojson}` are now fetched
and SHA-256 pinned. They were previously untracked in the manifest, which made
`verifyProvenance()` fail — and because that gate is the first thing every
merge tool runs, **the whole pipeline was unrunnable**. Pinning restores it.

The geometry itself is still **quarantined from the merge**:

- The GeoJSON ships **777** features against the gazetted 753 — the same
  over-count defect class as source #4.
- Its properties use the CBS harvest's spellings (`Aathrai Tribeni`, not our
  `Athrai Tribeni`) and carry no PDDPP code, so joining it to the dataset
  requires the same name-folding work as the code pipeline.

Nothing from this source is consumed by any shipped artifact yet. Admitting it
requires the Phase 3 review: reconcile the feature count against the roster,
define the district-containment check for geometry, and add the CC-BY-4.0
attribution to `NOTICE`. The PMTiles workflow
(`.github/workflows/pmtiles.yml`) builds a tile pyramid from it for on-demand
map delivery and does not alter the dataset.

## Bilingual names (`attach_bilingual.dart`, v2.5.0)

`nameNe` is taken from upstream rosters, never transliterated from the English
name: a machine transliteration is a guess about how a Nepali speaker spells a
place, and it disagrees with the gazette, the building and the voter roll often
enough to matter.

| Level | Named | Corroborated by two sources |
|---|---|---|
| Province | 7/7 | 6/7 |
| District | 77/77 | 77/77 |
| Local body | 731/753 | 450/731 |

- **Primary:** source #1 (`abinrimal`), `name_ne`.
- **Second vote / fallback:** source #4 (`open-admin-data`), `name.local`.
  Where abinrimal's roster is short in a district or blank for a row, this
  source fills the gap — it is never used as an *identifier*, because it ships
  775 units against 753.

**What `nameNeVerified` means.** True only when the two sources produce the
*same string*. False does not mean the name is doubtful: of 704 palikas where
both sources spoke, **262 differ only in orthography** — `ब`/`व`, `ी`/`ि`, the
candrabindu, `प्प`/`प`. That is the same phenomenon as the English spelling
variants documented for source #3, and it mirrors them one for one. Both
sources agreed on which palika it is; they disagree on the letters.

**Matching rule.** Palikas are identified from the *English* name, scoped to
the district, by normalized name (lowercased, type suffix and parentheticals
stripped, punctuation flattened) with Levenshtein distance ≤ 2 and a
unique-best-candidate requirement. Ties are refused, never arbitrated.

> **Why 2 and not 4.** A threshold of 4 was implemented and measured. It
> produced confidently wrong pairings between genuinely different neighbouring
> palikas — our `Dhorchaur` taking Bagachour's name, `Sulikot` taking
> Ajirkot's, `Kanda` taking Masta's. Distance 2 still covers every observed
> transliteration variant (`Pauwa Dunma`/`Pauwadungma`, `Gulmi Durbar`/
> `Gulmidarbar`, `Kapilvastu`/`Kapilbastu`). A wrong name is worse than an
> absent one.

**Source defects absorbed:**
- abinrimal's `code` column holds only four distinct values (it is a type
  code, not an identifier). It cannot key a "already matched" set; doing so
  silently dropped 575 matches. Identity uses `district_code` + `name_en`.
- abinrimal duplicates `Gulmi / Chatrakot`. Duplicate Devanagari names inside a
  district are resolved by evidence strength (corroboration first, then match
  distance); the weaker claim is dropped rather than duplicating a name across
  two palikas.
- Two abinrimal rows carry no Devanagari at all (Meringden, Bogtan Foodsil).
  open-admin-data supplies them.

## Administrative attributes (`attach_attributes.dart`, v2.5.0)

**All fields below are single-source.** They were extracted by earlier steps
and held back of the schema for exactly this reason; they ship now with the
limitation stated on every field. Treat `areaSqKm` as approximate for anything
load-bearing.

| Field | Coverage | Source |
|---|---|---|
| `District.headquarter`, `areaSqKm`, `website` | 77/77 | #2 sagautam5 |
| `Province.capital`, `areaSqKm`, `website` | 7/7 | #2 sagautam5 |
| `LocalBody.website`, `email`, `phone` | 371/753 | #6 MoFAGA harvest |
| `LocalBody.zipCodes` | 474/753 | #4 open-admin-data |

**MoFAGA joins on Devanagari, not on a code.** The harvest carries no
identifiers, so a palika is matched by its bare Devanagari name. Two hazards
were measured and handled:

- *District-keyed matching loses whole districts.* 12 districts spell their
  Devanagari differently in this source (`स्याङ्जा` vs `स्याञ्जा`, `रुपन्देही`
  vs `रूपन्देही`, `नवलपरासी पूर्व` …). Indexing by district silently dropped all
  of their contact details. Indexing is therefore global, by bare name.
- *Bare Devanagari palika names are not unique.* Many rural municipalities
  share a name across districts — 41 collisions in this harvest. A candidate is
  accepted only when it is unambiguous: exactly one row nationwide, or several
  of which exactly one sits in our district. Where our own roster has two
  palikas sharing a Devanagari name, **55 palikas are skipped entirely** rather
  than handed a contact block that may belong to a different palika.

sagautam5's province names also need one fold: it spells Sudurpashchim with
one `c` fewer ("Sudurpaschim").

## Ward-level records — NOT AVAILABLE

`wards` is a **count**. No vendored source names individual wards, so
6,743 ward records cannot be published without inventing them.

Checked and confirmed absent:

| Source | What it actually holds |
|---|---|
| #6 MoFAGA `mofaga_all.json` | 750 rows, all palikas — no wards |
| #3 nepali-geo-pro-max `local-units.ts` | ~757 rows, all palikas — no wards |
| #2 sagautam5 | `wards` **count** only |
| #4 open-admin-data | `children_count` is an empty object |
| #1 abinrimal | 753 palikas, no ward layer |

Adding this layer needs a new source, fetched and pinned like any other, before
any tool is written. Candidates: MoFAGA's own ward-level roster pages, ward
boundaries GeoJSON, or Election Commission delimitation data. Until one is
pinned, the honest position is a count and a documented gap.

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

> **Two ward totals, reported separately.** The declared national total is
> **6,743**; the per-palika rows sum to **6,697**. The 46-ward difference is
> the 8 palikas above, pending roster adjudication. The package exposes both
> (`NationalStats.wards` vs `verifiedWards`, `Province.unreconciledWards`)
> rather than publishing one number that silently disagrees with the other.
> Only Lumbini reconciles exactly (109 units, 983 wards).

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
