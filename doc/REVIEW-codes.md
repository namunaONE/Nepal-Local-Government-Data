# Step 2 — CBS Code Verification

**Status:** complete. **No canonical data modified** (assignments staged, not merged).
**Generated:** 2026-10-11 · **Tooling:** `tool/merge/verify_codes.dart` (+ shared `tool/merge/common.dart`)
**Raw report:** `doc/_verify-codes-raw.txt` (regenerate with `dart run tool/merge/verify_codes.dart`)
**Staged mapping:** `data/_stage/nso_codes.json` (753 assignments, provenance-headered)

---

## 1. What was verified, and against what

| List | Codes | Authority |
|---|---|---|
| CBS harvest (`cbs-codes/`, opendatanepal, "harvested from CBS") | 753 × `PDDPP` (10101–70909), 77 × `PDD` (101–709), 7 states | Primary — downloads MD5-identical to CKAN metadata, license `cc-by` re-verified at fetch |
| postal-2025 (`nepali-geo-pro-max`) | 752 distinct codes | Secondary — now doubly-attested (CBS + Shrestha 2019, DOI `10.3126/njg.v18i1.51115`) |
| Ours (`data/nepal_local_levels.json`) | none yet | Receives assignments |

Dharan = 11301 confirmed independently in the CBS file (with CBS's own "Sub-Metropolitian" typo — codes matter, spellings don't).

## 2. Gate results

| Gate | Result |
|---|---|
| Provenance (33 files) | ✅ pass |
| Structural (7/77/753 counts, uniqueness, patterns, prefix sets, referential integrity) | ✅ all pass |
| Alignment guard (EN↔Ne suffix correspondence) | ✅ 747/753, max consecutive run 1 (no cascade) |
| District Ne quarantine signature | ✅ confirmed present — column never consumed |
| Postal uniqueness (752 distinct) | ✅ pass |
| Sudurpashchim P7 rows | ✅ 88 = ours — structural match |

## 3. Reconciliation numbers

- **Postal-only codes (stale?): 0** — every postal-2025 code exists in CBS.
- **CBS-only codes (coverage gap): 1** — Mahakali Municipality, Kanchanpur = **70905**.
- **Assignments: 547 verified / 206 unverified / 753 total.**
- Verified rule (strict): postal T1/T2-accepted code doubly-attested by a same-district CBS row with agreeing normalized name. The 30 T1/T2 accepts that failed CBS name agreement went to review rather than being force-verified.
- Unverified = `nsoCode: null`, `nsoCodeVerified: false`, with a district-scoped suggestion for Step 4 (never auto-applied).

### Corrections to Step 1 figures

Step 1 reported postal-2025 as "751 codes" with "86 in Sudurpashchim". Both were an undercount from a shell regex whose character class excluded dots — it missed `k.i.singh rural municipality` = 70606. True figures: **752 codes, 87 in P7**. The single CBS-only gap is Mahakali 70905.

## 4. Source defects catalogued (all carry into Step 4)

1. **CBS districts Devanagari column corrupt from row 43** (`NAWALPARASI EAST` truncated mid-parenthetical; rows 44–77 carry the previous row's name — proven at codepoint level). Quarantined.
2. **CBS palika typos (isolated, max run 1):** `Sirijanga` Ne "गाउंपालिका", `Bensi Shahar` Ne "नगरापालिका", `Bhirkot Municipaity` (EN), `Gulmi Durbar Gaunpaika` (EN), `Tilottama` Ne "नगरापालिका", `Kanaka Sundari Gaun Palika` (EN spaced). Spelling evidence for adjudication, not alignment breaks.
3. **CBS uppercase romanization variants** (`CHITAWAN`, `DHANUSA`, `TANAHU`, `KAPILBASTU`, `NAWALPARASI EAST/WEST`, `RUKUM EAST/WEST`) — explain open-admin-data's spellings; codes join on codes.
4. **Postal-2025 shortfall: exactly 1 code** (Mahakali 70905, Kanchanpur).

## 5. What Step 4 receives

- `data/_stage/nso_codes.json` — every ours palika with either a doubly-attested code or an explicit null + suggestion.
- 206 review items (149 T3 + 27 MISS + 30 CBS-name-disagree), each with a district-scoped code suggestion.
- The 219 palika + 13 district Devanagari diffs gain a 4th vote (CBS `स्थानीय तह`, where aligned).
- District codes 101–709 validated and ready for schema v2.

## 6. Open items resolved

- REVIEW-inputs §7.1 (verify postal-2025): **done** — doubly-attested, see §3.
- REVIEW-inputs §7.4 (86 vs 88): **done** — 88, structural match, see §3.
- REVIEW-inputs §7.2 (name divergences) and §7.3 (Chatrakot dupe): **Step 4**.
