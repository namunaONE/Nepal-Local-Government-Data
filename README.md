# Nepal Administrative Data by namunaONE — `nepal_admin_api`

<p align="left">
  <img src="docs/logo-full.svg" alt="Nepal Administrative Data by namunaONE" width="420">
</p>

[![pub package](https://img.shields.io/pub/v/nepal_admin_api.svg)](https://pub.dev/packages/nepal_admin_api)
[![pub points](https://img.shields.io/pub/points/nepal_admin_api.svg)](https://pub.dev/packages/nepal_admin_api/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/namunaONE/Nepal-Local-Government-Data/actions/workflows/dart.yml/badge.svg)](https://github.com/namunaONE/Nepal-Local-Government-Data/actions/workflows/dart.yml)
[![Website](https://img.shields.io/badge/docs-GitHub%20Pages-DC143C)](https://namunaONE.github.io/Nepal-Local-Government-Data/)

> **Offline administrative divisions of Nepal** — 7 provinces, 77 districts, 753 local bodies, 6,743 wards with **official CBS/NSO codes** (PDDPP format) and **ISO 3166-2 province codes** (NP-P1…NP-P7).

Pure Dart package. Zero runtime dependencies. Data ships in the box.

> Maintained by **namunaONE** under **HyaMuji** and **Taire Bhai**.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Flutter widgets** | [`nepal_admin_widgets`](/packages/nepal_admin_widgets) — cascading Province → District → Palika pickers, bilingual, offline, 58 widget tests |
| **Bindings for 5 ecosystems** | Dart · TypeScript/JavaScript · Python · CSV · GeoJSON — all generated from one dataset, drift-checked in CI |
| **Bilingual** | Devanagari names for all 7 provinces, 77 districts and **731/753 palikas** - never transliterated, never guessed |
| **Bilingual search** | `search('भरतपुर')` and `search('Bharatpur')` return the same palika; fragments match too |
| **Complete hierarchy** | Province → District → Local Body (palika) |
| **Official codes** | 744/753 palikas with CBS 5-digit codes (PDDPP), all 77 districts (3-digit), all 7 provinces (NP-P1…NP-P7) |
| **Honest confidence tiers** | Every code labelled `verified` (548) / `singleSource` (196) / `unverified` (9) — you choose how much to trust it |
| **Ward counts** | 745/753 palikas with verified ward counts; declared vs substantiated totals reported side by side; 8 documented roster-defect gaps |
| **Administrative attributes** | District HQ, area and website (77/77); province capital, area and website (7/7); palika website/email/phone and postal codes |
| **Map coordinates** | 726/753 palikas with approximate centroids (`lat`/`lng` + `geoSource`); `hasCoordinates`, `whereMapped` |
| **Type-safe models** | `Province`, `District`, `LocalBody`, `LocalBodyType`, `CbsCodeConfidence` enums |
| **Hierarchical queries** | Navigate province → district → local body with typed accessors |
| **Typed search** | Disambiguates duplicate names by district/province context, by `fullPath`, or by district-scoped lookup |
| **Computed stats** | National & provincial totals (not hardcoded), with declared-vs-verified ward reconciliation |
| **JSON serialization** | `toJson()` / `fromJson()` + `==` / `hashCode` on all models |
| **Zero dependencies** | Pure Dart, works offline on every platform |
| **130/130 pub.dev** | Full score: analysis, formatting, tests, docs, platform support |

---

## 📦 Installation

```yaml
dependencies:
  nepal_admin_api: ^2.7.1
```

```bash
dart pub get
# or
flutter pub get
```

---

## 🚀 Quick Start

```dart
import 'package:nepal_admin_api/nepal_admin_api.dart';

void main() {
  // ──────────────────────────────────────────────
  // Provinces (with CBS/ISO codes in v2.0.0+)
  // ──────────────────────────────────────────────
  final provinces = NepalAdminApi.getAllProvinces();
  print('Provinces: ${provinces.length}'); // 7

  // By ID (case-insensitive) or ISO code
  final koshi = NepalAdminApi.getProvinceById('koshi');
  final byIso = NepalAdminApi.getProvinceById('NP-P1');
  print('Koshi CBS: ${koshi?.cbsCode}, ISO: ${koshi?.isoCode}'); // 1, NP-P1

  // ──────────────────────────────────────────────
  // Districts
  // ──────────────────────────────────────────────
  final chitwan = NepalAdminApi.getDistrictByName('Chitwan');
  print('Chitwan bodies: ${chitwan?.localBodyCount}'); // 7
  print('Chitwan CBS code: ${chitwan?.cbsCode}'); // 306

  // ──────────────────────────────────────────────
  // Local Bodies (palikas) with CBS codes
  // ──────────────────────────────────────────────
  final bharatpur = NepalAdminApi.search('Bharatpur').localBodies.first;
  print('${bharatpur.name} (${bharatpur.typeName})');
  print('District: ${bharatpur.districtName}');
  print('Province: ${bharatpur.provinceName}');
  print('CBS Code: ${bharatpur.cbsCode} (verified: ${bharatpur.cbsCodeVerified})');
  // Bharatpur (Metropolitan City)
  // District: Chitwan
  // Province: Bagmati
  // CBS Code: 31304 (verified: true)

  // ──────────────────────────────────────────────
  // Search (handles duplicates via context)
  // ──────────────────────────────────────────────
  final sunkoshi = NepalAdminApi.search('Sunkoshi');
  for (final lb in sunkoshi.localBodies) {
    print('${lb.name} — ${lb.districtName}, ${lb.provinceName}');
  }
  // Sunkoshi — Okhaldhunga, Koshi
  // Sunkoshi — Udayapur, Koshi
  // Sunkoshi — Sindhupalchok, Bagmati
  // Sunkoshi — Rautahat, Madhesh

  // ──────────────────────────────────────────────
  // National Statistics (computed, not hardcoded)
  // ──────────────────────────────────────────────
  final stats = NepalAdminApi.getNationalStats();
  print('''
Provinces: ${stats.provinces}           // 7
Districts: ${stats.districts}           // 77
Metropolitan: ${stats.metro}            // 6
Sub-Metro: ${stats.subMetro}            // 11
Municipalities: ${stats.municipalities} // 276
Rural Municipalities: ${stats.ruralMunicipalities} // 460
Total: ${stats.total}                   // 753
Wards: ${stats.wards}                   // 6,743 declared
''');

  // `wards` is the declared national figure. `verifiedWards` is what the
  // per-palika rows we can actually substantiate add up to. They differ by
  // 46 because 8 palikas carry no verified ward count — so the package
  // reports both instead of quietly picking one.
  assert(stats.verifiedWards == 6697);
  assert(stats.wardGaps == 8);
  assert(stats.unreconciledWards == stats.wards - stats.verifiedWards);

  // ──────────────────────────────────────────────
  // Code confidence — join to government datasets
  // ──────────────────────────────────────────────
  // 744 of 753 palikas carry a code. Each says how strongly it is attested.
  final byCode = NepalAdminApi.getAllLocalBodies().byCbsCode; // Map<int, LocalBody>
  print('Joinable by CBS code: ${byCode.length}/753');

  for (final lb in NepalAdminApi.getSingleSourceLocalBodies().take(2)) {
    print('${lb.cbsCodeString} ${lb.name} '
        '(${lb.cbsCodeConfidence.wireName}, verified=${lb.cbsCodeVerified})');
  }

  // ──────────────────────────────────────────────
  // JSON Serialization
  // ──────────────────────────────────────────────
  final json = bharatpur.toJson();
  final restored = LocalBody.fromJson(json);
  assert(restored.cbsCode == bharatpur.cbsCode);
  assert(restored.cbsCodeConfidence == bharatpur.cbsCodeConfidence);
}
```

---

## 🌐 Bindings — one dataset, five ecosystems

Everything below is **generated** from `data/nepal_local_levels.json` by
`dart run tool/generate_bindings.dart`, cross-checked against the Dart package in
CI, and byte-stable across regenerations. Same numbers, same honesty
guarantees, in whichever shape you already use.

| Target | Install | Shape |
|---|---|---|
| **Dart / Flutter** | `nepal_admin_api` (pub.dev) | typed classes, zero deps |
| **JavaScript / TypeScript** | `npm install nepal-admin-data` | `index.js` + `index.d.ts`, zero deps |
| **Python** | `pip install nepal-admin-data` | pure stdlib, zero deps |
| **CSV** | [`local_bodies.csv`](https://namunaONE.github.io/Nepal-Local-Government-Data/downloads/local_bodies.csv) | 3 flat files, RFC 4180 |
| **GeoJSON** | [`local-bodies.centroids.geojson`](https://namunaONE.github.io/Nepal-Local-Government-Data/downloads/local-bodies.centroids.geojson) | RFC 7946, WGS84 |

```js
const nad = require('nepal-admin-data');
nad.getLocalBodyByCbs(31304).nameNe;                  // 'भरतपुर'
nad.search('भरतपुर').localBodies.length
  === nad.search('Bharatpur').localBodies.length;     // true
new Map(nad.getLocalBodiesWithCode().map(b => [b.cbsCode, b])).size;  // 744
```

```python
import nepal_admin as nad
nad.get_local_body_by_cbs(31304)["nameNe"]            # 'भरतपुर'
len(nad.get_local_bodies_with_code())                 # 744
nad.get_national_stats()["unreconciled_wards"]        # 46
```

```python
import pandas as pd
pd.read_csv("local_bodies.csv").query("cbsCode == 31304")[["name", "nameNe"]]
```

The JS and Python APIs mirror the Dart one name-for-name, so moving between
them is a rename rather than a rewrite. `bindings/README.md` documents the
generated tree; `bindings/verify_bindings.cjs` executes it.

## 🇳🇵 Bilingual data

Every level carries its Devanagari name, taken from source rosters — never
transliterated from the English, because a machine transliteration would be a
guess about how a Nepali speaker spells a place.

```dart
final bharatpur = NepalAdminApi.getLocalBodyByCbs(31304)!;
print(bharatpur.name);          // Bharatpur
print(bharatpur.nameNe);        // भरतपुर
print(bharatpur.nameNeOrName);  // भरतपुर   (never null)
print(bharatpur.displayBoth);   // Bharatpur · भरतपुर

// Search works in both directions, including fragments.
NepalAdminApi.search('भरतपुर').localBodies;   // same as search('Bharatpur')
NepalAdminApi.search('भारत').localBodies;      // fragment match
NepalAdminApi.search('चितवन').districts;       // Chitwan
```

| Level | Coverage | Corroborated by 2 sources |
|---|---|---|
| Province | 7/7 | 6/7 |
| District | 77/77 | 77/77 |
| Local body | **731/753** | 450/731 |

**What `nameNeVerified == false` means.** Not that the name is wrong. It means
the two rosters spell the *same* name differently in orthography — 262 pairs
differ only in `ब`/`व`, `ी`/`ि`, the candrabindu, or `प्प`/`प`. Both sources
agreed on which palika it is; they disagree on spelling. The published string
is the primary source's.

**What is missing.** 22 palikas have no attested Devanagari name and keep
`nameNe == null` — listed by name in the CHANGELOG and pinned in the test
suite. Nothing was invented to fill them.

## 🏛️ Administrative attributes

Single-source fields, documented as such in [data/SOURCES.md](data/SOURCES.md).
Treat `areaSqKm` as approximate for anything load-bearing.

```dart
final chitwan = NepalAdminApi.getDistrictByName('Chitwan')!;
print(chitwan.headquarter);  // Bharatpur  (the district's seat)
print(chitwan.areaSqKm);     // 2218.0
print(chitwan.website);      // https://dccchitwan.gov.np/

final koshi = NepalAdminApi.getProvinceById('koshi')!;
print(koshi.capital);        // Biratnagar

final bharatpur = NepalAdminApi.getLocalBodyByCbs(31304)!;
print(bharatpur.website);    // http://bharatpurmun.gov.np
print(bharatpur.phone);      // 056-525879
print(bharatpur.zipCodes);   // [44200]
print(bharatpur.hasContact); // true
```

| Field | Coverage | Source |
|---|---|---|
| `District.headquarter` / `areaSqKm` / `website` | 77/77 | sagautam5 |
| `Province.capital` / `areaSqKm` / `website` | 7/7 | sagautam5 |
| `LocalBody.website` / `email` / `phone` | 371/753 | MoFAGA |
| `LocalBody.zipCodes` | 474/753 | open-admin-data |

## 🔍 Code confidence, explained

A missing code and a doubtful code are different problems, so the package
distinguishes them instead of collapsing both to `null`:

| Tier | Count | Meaning | Use it for |
|------|-------|---------|------------|
| `verified` | 548 | postal-2025 **and** the CBS harvest name the same code | Anything load-bearing |
| `singleSource` | 196 | One attestation from the authoritative CBS roster: a unique same-district, same-type row whose normalized name matches — or a pairing forced by elimination where the rosters agree type-for-type | Joining datasets; worth spot-checking |
| `unverified` | 9 | No defensible code. Left `null` on purpose | Report the gap, don't guess |

`cbsCodeVerified` is still exactly what it always was — `true` only for the
doubly-attested tier — so existing code keeps working unchanged. The
assignment is forced to be a bijection, and every code must sit inside its own
district, both enforced by the generator.

## ⚖️ Two ward totals, on purpose

`NationalStats.wards` is **6,743** — the declared national figure.
`NationalStats.verifiedWards` is **6,697** — the sum of the per-palika counts
this package can substantiate. The 46-ward difference is the 8 palikas
documented as roster defects in [CHANGELOG](CHANGELOG.md). Lumbini reconciles
exactly (109 units, 983 wards); the other six provinces differ by their own
known gaps, which `Province.unreconciledWards` reports per province.

---

## 📚 API Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `getAllProvinces()` | `List<Province>` | All 7 provinces |
| `getProvinceById(id)` | `Province?` | By ID (`'koshi'`) or ISO (`'NP-P3'`) |
| `getProvinceByIso(iso)` | `Province?` | By ISO 3166-2 (`'NP-P3'`) |
| `getProvinceByCbs(code)` | `Province?` | By CBS code (`3`) |
| `getAllDistricts()` | `List<District>` | All 77 districts |
| `getDistrictsByProvince(id)` | `List<District>` | Districts in a province (id or ISO) |
| `getDistrictByName(name)` | `District?` | Case-insensitive lookup |
| `getDistrictByCbs(code)` | `District?` | By CBS code (`306` = Kathmandu) |
| `getAllLocalBodies()` | `List<LocalBody>` | All 753 palikas |
| `getLocalBodiesByDistrict(name)` | `List<LocalBody>` | Palikas in a district |
| `getLocalBodiesByProvince(id)` | `List<LocalBody>` | Palikas in a province (id or ISO) |
| `getLocalBodiesByType(type)` | `List<LocalBody>` | Palikas of one type |
| `getLocalBodiesByName(name, district)` | `List<LocalBody>` | **Disambiguates duplicates by district** |
| `getLocalBodyByFullPath(path)` | `LocalBody?` | **`'Bharatpur, Chitwan, Bagmati'`; null if ambiguous** |
| `getLocalBodyByCbs(code)` | `LocalBody?` | **Any tier** — resolves 744/753 (`31304` = Bharatpur) |
| `getLocalBodyByCbsVerified(code)` | `LocalBody?` | **Strict tier only** — 548/753 |
| `getLocalBodiesWithCode()` | `List<LocalBody>` | **744 — the joinable set** |
| `getVerifiedLocalBodies()` | `List<LocalBody>` | Doubly-attested only (548) |
| `getSingleSourceLocalBodies()` | `List<LocalBody>` | Single attestation (196) |
| `getUncodedLocalBodies()` | `List<LocalBody>` | No defensible code (9) |
| `search(query)` | `SearchResult` | Typed search (names, ISO, full paths) |
| `getNationalStats()` | `NationalStats` | Computed national totals |

**Models**: `Province`, `District`, `LocalBody`, `LocalBodyType`, `CbsCodeConfidence`, `ProvinceStats`, `NationalStats`, `SearchResult`

**Helpers**: bilingual (`nameNe`, `nameNeOrName`, `displayBoth` on all three models), `LocalBody.fullPath` (`'Bharatpur, Chitwan, Bagmati'`), `isUrban` / `isRural`, `hasCoordinates`, `hasCbsCode`, `cbsCodeString` (zero-padded, for string joins), `LocalBodyListX` (`sortedByName`, `sortedByFullPath`, `whereUrban`, `whereRural`, `whereVerified`, `whereMapped`, `whereCoded`, `whereDoublyAttested`, `whereSingleSource`, `whereUncoded`, `whereCodeAndCoordinateMapped`, `whereWardsVerified`, `ofType`, `totalWards`, `byCbsCode`), ward reconciliation (`District.wards` / `verifiedWardCoverage` / `wardsFullyVerified`, `Province.declaredWards` / `verifiedWards` / `unreconciledWards` / `wardsReconcile`)

👉 [Full API Documentation](https://namunaONE.github.io/Nepal-Local-Government-Data/api.html)

---

## 🗺️ Data Explorer

Interactive table with all 753 local bodies — search, filter by province/district/type, view CBS codes and verification status — plus an interactive centroid map (726 mapped, Leaflet + clustered dots, click a row to fly to it, `?cbs=` deep links).

👉 [Open Data Explorer](https://namunaONE.github.io/Nepal-Local-Government-Data/explorer.html)

---

## 📊 Schema v2 (Breaking Changes in 2.0.0)

| Class | New Fields |
|-------|------------|
| `Province` | `cbsCode` (1–7), `isoCode` (`NP-P1`…`NP-P7`) |
| `District` | `cbsCode` (3-digit, e.g., `306` for Kathmandu) |
| `LocalBody` | `cbsCode` (5-digit PDDPP), `cbsCodeVerified` (bool) |

**Migration**:
```dart
// v1
LocalBody(name: 'X', type: T, districtName: 'D', provinceName: 'P')

// v2 (new params optional)
LocalBody(
  name: 'X', 
  type: T, 
  districtName: 'D', 
  provinceName: 'P',
  cbsCode: 31304,
  cbsCodeVerified: true,
)
```

---

## 📋 Data Verification Pipeline

```
5+ independent sources
       │
       ▼
Step 1: Inventory & defect audit (tool/merge/inventory.dart)
       │
       ▼
Step 2: CBS code verification via the CBS harvest + Postal-2025 (tool/merge/verify_codes.dart)
       │ 548/753 doubly-attested (verified)
       ▼
Step 3: Adjudication — 72 conflicts, 72 resolved (tool/merge/adjudicate.dart)
       │ 49 mofaga-exact, 15 mofaga-slug, 8 human
       ▼
Step 4: Schema v2 with CBS codes embedded (tool/merge/apply_cbs_codes.dart)
       │
       ▼
Step 5: Confidence tiers — single-source codes recovered from the CBS roster,
        with a bijection gate so no two palikas share a code
        (tool/merge/resolve_code_tiers.dart)
       │ 548 verified + 196 singleSource = 744/753 codes (98.8%)
       ▼
Step 6: Devanagari names at all three levels, corroborated against a second
        bilingual source (tool/merge/attach_bilingual.dart)
       │ 7/7 provinces, 77/77 districts, 731/753 palikas
       ▼
Step 7: Administrative attributes — HQ, area, website, contact, postal codes
        (tool/merge/attach_attributes.dart)
       │ 77/77 districts, 7/7 provinces, 371/753 palikas, 474 postal codes
       ▼
Step 8: Codegen (tool/generate.dart) + website payload
        (tool/generate_explorer_data.dart)

All of the above runs in one command:
   dart run tool/pipeline.dart

Steps 6 and 7 are ORDER-DEPENDENT: the MoFAGA harvest carries no codes, so
attributes join palikas by their Devanagari name, which only exists after
step 6. Running them out of order attaches nothing and fails silently, so
use the pipeline rather than the individual tools.

The whole chain aborts on the first failure, and every step is gated: the
generator refuses to emit a dataset with a code outside its own district, a
duplicate code, a confidence tier that contradicts the verified flag, or a
Devanagari field holding no Devanagari.

**Sources** (CC-BY-4.0 material attributed in [NOTICE](NOTICE)):
- `abinrimal/nepal-administrative-divisions-json` — Devanagari names
- `sagautam5/local-states-nepal` — Municipalities dataset  
- `CBS/NSO official CSVs` — States, districts, local bodies codes
- `Postal Codes 2025` — Cross-reference for verification

---

## 🛠️ Development

```bash
# Setup
git clone https://github.com/namunaONE/Nepal-Local-Government-Data.git
cd Nepal-Local-Government-Data
dart pub get

# Run CI locally
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart run tool/generate.dart
node docs/smoke.cjs

# Regenerate EVERYTHING from the source of truth (recommended)
# Runs the merge steps, then both codegen steps, and aborts on the first
# failure so no artifact can silently drift from the dataset.
dart run tool/pipeline.dart

# Inspect a data change before writing it
dart run tool/pipeline.dart --dry-run

# After re-fetching upstream sources (rare): audit, then regenerate
dart run tool/merge/inventory.dart
dart run tool/pipeline.dart
```

If you only ever edit `data/nepal_local_levels.json`, `dart run
tool/pipeline.dart` is the whole story. The steps it wraps are:

```
tool/merge/verify_codes.dart        → doubly-attested CBS codes
tool/merge/apply_cbs_codes.dart    → write them into the dataset
tool/merge/resolve_code_tiers.dart → single-source tier + bijection gate
tool/merge/attach_bilingual.dart   → Devanagari names at all 3 levels
tool/merge/attach_attributes.dart  → HQ / area / website / contact / postal
tool/generate.dart                 → lib/src/nepal_data.dart (validates)
tool/generate_explorer_data.dart   → docs/data.json
tool/generate_bindings.dart        → CSV / GeoJSON / JS / Python bindings
```

Steps 4 and 5 are **order-dependent**: the MoFAGA harvest carries no codes, so
attributes join palikas by their Devanagari name, which only exists after
step 4. Running them out of order attaches nothing and fails *silently*, which
is why the pipeline rather than the individual tools is the entry point.

Output is byte-stable — fixed ordering, LF endings, UTF-8 without BOM, no
timestamps — so CI drift is a plain `git diff`. Verify at any time:

```bash
node bindings/verify_bindings.cjs   # executes the JS, parses CSV + GeoJSON
dart test                            # includes cross-binding parity tests
```

Commit the dataset **and** every generated file together; CI fails if any of
them drift apart.

---

## 🤖 Using with AI coding assistants

Machine-readable docs live alongside the site (llms.txt convention):

- [`llms.txt`](https://namunaONE.github.io/Nepal-Local-Government-Data/llms.txt) — curated index: install, API, data, links
- [`llms-full.txt`](https://namunaONE.github.io/Nepal-Local-Government-Data/llms-full.txt) — complete documentation in one file; paste this URL into any LLM for full context

Guidelines for AI-generated answers using this package: always query codes/counts/coordinates from the API (never invent CBS codes, ward counts, or lat/lng); disambiguate duplicate palika names with `districtName`/`provinceName` or `fullPath`; respect `*Verified` flags and `null` gaps.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Bug reports, feature requests, PR guidelines
- Conventional Commits format
- Data pipeline documentation
- Commit message conventions

---

## 📜 License

**Code**: [MIT](LICENSE)  
**Data**: CC-BY-4.0 attributed sources — see [NOTICE](NOTICE) and [data/SOURCES.md](data/SOURCES.md)

> This project is not affiliated with the Government of Nepal. Data reflects the gazetted federal structure as of October 2026. Administrative boundaries may change through future government decisions.

---

## 🔗 Links

- **Package**: [pub.dev/packages/nepal_admin_api](https://pub.dev/packages/nepal_admin_api)
- **Documentation**: [GitHub Pages](https://namunaONE.github.io/Nepal-Local-Government-Data/)
- **API Reference**: [/api.html](https://namunaONE.github.io/Nepal-Local-Government-Data/api.html)
- **Data Explorer**: [/explorer.html](https://namunaONE.github.io/Nepal-Local-Government-Data/explorer.html)
- **Repository**: [github.com/namunaONE/Nepal-Local-Government-Data](https://github.com/namunaONE/Nepal-Local-Government-Data)
- **Issues**: [GitHub Issues](https://github.com/namunaONE/Nepal-Local-Government-Data/issues)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)