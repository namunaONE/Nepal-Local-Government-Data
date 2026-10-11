# Step 1 — Source Coverage Inventory

**Status:** complete. **No merging has been performed.**
**Generated:** 2026-10-11 · **Tooling:** `tool/merge/inventory.dart`
**Raw report:** `docs/_inventory-raw.txt` (regenerate with `dart run tool/merge/inventory.dart`)

---

## 1. What was acquired

All five sources pinned into `data/_raw/` with SHA-256 recorded per file (31 files total).

| Source | Branch/Ref | Files | Size | License | Attribution required? |
|---|---|---|---|---|---|
| `abinrimal/nepal-administrative-divisions-json` | `main` | 4 JSON + LICENSE | ~185 KB | MIT | No |
| `sagautam5/local-states-nepal` | `master` | 10 JSON + LICENSE | ~1.2 MB | MIT | No |
| `l3lackcurtains/nepali-geo-pro-max` | `main` | 8 TS + LICENSE | ~243 KB | MIT | No |
| `open-admin-data/nepal-administrative-divisions` | `main` | 4 JSON + LICENSE | ~933 KB | **CC-BY-4.0** | **Yes — visible in shipped package** |
| `opentechcommunity/map-of-nepal` | *(not yet fetched)* | GeoJSON | — | **CC-BY-4.0** | **Yes** |

`opentechcommunity/map-of-nepal` was deliberately **not** downloaded in Step 1 — boundary geometry is Phase 3 scope. Recorded here so it is not forgotten.

Sizes above match the GitHub git-tree listings exactly, which is the first integrity check that downloads were not truncated.

---

## 2. Headline result: the NSO code question is *answered*

This was Step 1's biggest unknown, and it resolved favourably.

`nepali-geo-pro-max`'s `src/data/postal-codes-2025.ts` is **not merely a postal-code file — it carries the CBS/NSO administrative code list.**

Its `PDDPP` structure (`1` province + `2` district + `2` palika) is *structurally identical* to the CBS hierarchical geographic code, and:

- **`"dharan sub-metropolitan city" = "11301"`** — exactly the published CBS/NSO code for Dharan from the peer-reviewed *Nepal Journal of Geography* coding paper. One independent, citable confirmation.
- It yields **exactly 77 district prefixes**, split per province **14 / 8 / 13 / 11 / 12 / 10 / 9** — **identical to our verified dataset's district counts for all seven provinces.**
- Koshi's sequence runs a **gapless 101…114** across all 14 districts.
- **751 of 753 palikas** carry a code.

Because ISO 3166-2:NP only covers provinces (no district or palika codes), this is the *only* route to official codes below province level. **It is the strongest candidate and largely de-risks Step 2.**

> ⚠️ **Caveat that must survive into Step 2:** this is *derived* data, not a primary CBS publication. One verified anchor is not full verification. Step 2 must confirm against CBS/NSO or MoFAGA before any code is marked `nsoCodeVerified: true`.

---

## 3. Ward counts — resolved, with a discrepancy caught

| Source | Per-palika ward counts | Sum |
|---|---|---|
| `sagautam5` | 753/753 | **6,743** ✅ matches the gazette |
| `nepali-geo-pro-max` | 753/753 | **6,742** ❌ off by one |

`sagautam5` sums to exactly the official 6,743. `nepali-geo-pro-max` is **one ward short**, and its own header comment proves why: it was generated *from* sagautam5 (verified 2026-04-30), so a transcription error was introduced downstream.

**Decision: source ward counts from `sagautam5`, never from `nepali-geo-pro-max`.** This is exactly the failure mode the three-way-verification protocol exists to catch — and it would have silently shipped a wrong 6,742.

---

## 4. ⚠️ Source independence — the most important structural finding

**`nepali-geo-pro-max` is *derived from* `sagautam5`.** Its own file header states:

> Source: sagautam5/local-states-nepal (master branch) … Last verified: 2026-04-30

We therefore have **three genuinely independent sources**, not four:

| # | Source | Independent? |
|---|---|---|
| 1 | `abinrimal` | ✅ yes |
| 2 | `sagautam5` | ✅ yes |
| 3 | `open-admin-data` | ✅ yes |
| 4 | `nepali-geo-pro-max` | ❌ **derivative of #2** |

**Consequence for the merge protocol:** treating these as four sources would have made every field look "4-way verified" when really only two independent sources agreed. The three-way-verification rule in the roadmap must be applied to sources **1–3**, with `nepali-geo-pro-max` used only as a *rich secondary extractor* (aliases, coords, postal codes, legacy cross-walk) — never as a vote.

---

## 5. Field coverage matrix

| Field | abinrimal | sagautam5 | geo-pro-max | open-admin | **Ours today** |
|---|---|---|---|---|---|
| English names (palika) | ✅ 753 | ✅ 753 | ✅ 753 | ⚠️ 775 | ✅ 753 |
| Devanagari names (palika) | ✅ 753 | ✅ (np.json) | ✅ 753 | ⚠️ 775 | ❌ **0** |
| Devanagari names (district) | ✅ 77 | ✅ | ✅ | ⚠️ | ❌ |
| Devanagari names (province) | ✅ 7 | ✅ | ✅ | ⚠️ | ❌ |
| Per-palika ward counts | ❌ | ✅ **753** | ✅ (754 err) | ❌ | ❌ agg only |
| NSO/CBS code | ❌ | ❌ | ✅ **751** | ⚠️ `NP…` ids | ❌ |
| District headquarter | ❌ | ✅ **77** | ✅ 77 | ❌ | ❌ |
| Province capital | ❌ | ✅ 7 | ✅ 7 + coords | ❌ | ❌ |
| Coordinates | ❌ | ❌ | ✅ province | ✅ all 775 | ❌ |
| Postal codes | ❌ | ❌ | ✅ 409 + 751 | ✅ | ❌ |
| Area (km²) | ❌ | ✅ **753 + 77 + 7** | ✅ province | ❌ | ❌ |
| Website | ❌ | ✅ **753 + 77 + 7** | ⚠️ 17 | ❌ | ❌ |
| Aliases | ❌ | ❌ | ✅ 17 + 7 | ❌ | ❌ |
| Legacy cross-walk | ❌ | ❌ | ✅ 75 + 14 + 5 | ❌ | ❌ |
| Unique palika ids | ⚠️ not unique | ✅ `id` | ✅ `P3.D05.L01` | ✅ `NP…` | ❌ |

**Every field we lack has at least one source.** Three fields — `headquarter`, `area_sq_km`, `website` — come from a single source (sagautam5) and must be flagged `SINGLE-SOURCE`.

---

## 6. Defects and traps found in the sources

### 6.1 `abinrimal` contains a genuine duplicate
`Gulmi | Chatrakot` appears **twice** in `local_levels.json`. Our dataset has exactly one `Chhatrakot` (note the different romanisation). abinrimal's data must be de-duplicated before use; otherwise the merge would silently produce 754 palikas.

### 6.2 `abinrimal`'s `code` field is a trap
Its `code` has only **4 distinct values across 753 records** — they are *type* codes (1/2/3/4), not identifiers. Any code that joins on it will produce a Cartesian explosion. It is useful only as a type hint.

### 6.3 `open-admin-data` has 775 units, not 753
Its `local_unit` array holds **775** records. Its counts must be **rejected outright** per the roadmap's hard gate — but its `id` (`NP0101301`) and `geo` (lat/lon on all levels) remain usable as *supplementary* data, not as counts.

### 6.4 Four mutually inconsistent district-numbering schemes

| Scheme | Koshi: Bhojpur / Sunsari | Nature |
|---|---|---|
| `abinrimal` | 20 / 11 | internal ordering |
| `sagautam5` | 1 / 11 | simple per-province sequence |
| `open-admin-data` | `NP0110` / `NP0106` | internal ordering |
| **`postal-2025`** | **106 / 113** | **gapless 01–14; matches published CBS code** |

Only `postal-2025` is a candidate for the official scheme (§2). **Do not mix schemes** — every code must come from one source or it will be meaningless.

### 6.5 Name-spelling divergence is severe
**239 of our 753 palika names do not join exactly** to `postal-2025`'s keys. Examples:

| Ours | postal-2025 key | Sagautam5 |
|---|---|---|
| `Shadananda` | `shadanand municipality` | `Shadanand` |
| `Salpa Silichho` | `salpasilichho rural municipality` | `Salpasilichho` |
| `Chhatrakot` | `chhatrakot rural municipality` | `Chhatrakot` |
| `BodeBarsain` | *(absent — spacing bug)* | — |
| `Kabilashi` | *(differs)* | `Kabilasi`? |

**Implication:** the merge **must** use fuzzy matching with human adjudication. Exact-match joining would fail on ~32% of palikas. This validates the roadmap's Step 4 design and means the `docs/REVIEW.md` conflict list will be large.

---

## 7. What is now decided vs. what stays open

### Decided in Step 1
- Ward counts → **`sagautam5`** (sums to 6,743)
- Devanagari names → **`abinrimal`** (753 + 77 + 7, most complete bilingual set) with `sagautam5` as cross-check
- Province capitals + district HQs + areas + websites → **`sagautam5`** (single-source, flag it)
- Aliases, province coordinates, postal codes, legacy cross-walk → **`nepali-geo-pro-max`** (supplementary extractor only)
- Boundary coordinates → **`open-admin-data`** (supplementary only; counts rejected)
- NSO codes → **`postal-2025` candidate**, pending Step 2 verification

### Open — carries into Step 2
1. **Verify `postal-2025` against CBS/NSO or MoFAGA** — one anchor (Dharan 11301) is not enough. This is the single highest-value Step 2 task.
2. **Resolve the 239 name-spelling divergences** via fuzzy match + adjudication.
3. **De-duplicate abinrimal's `Gulmi|Chatrakot`.**
4. **Determine whether Sudurpashchim is genuinely 86 or 88** palikas (postal-2025 has 86 codes; our dataset and sagautam5 both say 88). Likely a postal-coverage gap, not a structural difference — but must be confirmed, not assumed.

---

## 8. Exit criterion for Step 1

| Target field | Source count | Verdict |
|---|---|---|
| Devanagari names | 3 (abinrimal, sagautam5, geo-pro-max) | ✅ mergeable |
| Ward counts | 2 (sagautam5 ✓, geo-pro-max ✗) | ✅ use sagautam5 |
| NSO codes | 1 strong candidate (postal-2025) | ⚠️ verify in Step 2 |
| District HQ | 1 (sagautam5) | ⚠️ single-source flag |
| Province capital | 2 (sagautam5, geo-pro-max) | ✅ |
| Coordinates | 1 (open-admin-data, geo-pro-max for capitals) | ⚠️ single-source flag |
| Postal codes | 1 (geo-pro-max, derived from Wikipedia + GPO + VDC cross-walk) | ⚠️ single-source + derived |
| Area | 1 (sagautam5) | ⚠️ single-source flag |
| Website | 1 (sagautam5) | ⚠️ single-source flag |
| Aliases | 1 (geo-pro-max) | ⚠️ single-source flag |
| Legacy cross-walk | 1 (geo-pro-max) | ⚠️ single-source flag |
| Boundary geometry | 0 fetched | ⛔ **cut from current scope — Phase 3** |

**Every field has a known source count. No field has zero sources except boundary geometry, which is formally deferred.** Step 1 exit criterion met.
