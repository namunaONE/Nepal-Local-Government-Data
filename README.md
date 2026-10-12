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
| **Complete hierarchy** | Province → District → Local Body (palika) |
| **Official codes** | 547/753 palikas with verified 5-digit CBS codes (PDDPP), all 77 districts (3-digit), all 7 provinces (NP-P1…NP-P7) |
| **Map coordinates** | 726/753 palikas with approximate centroids (`lat`/`lng` + `geoSource`); `hasCoordinates`, `whereMapped` |
| **Type-safe models** | `Province`, `District`, `LocalBody`, `LocalBodyType` enum |
| **Hierarchical queries** | Navigate province → district → local body with typed accessors |
| **Typed search** | Disambiguates duplicate names by district/province context |
| **Computed stats** | National & provincial totals (not hardcoded) |
| **JSON serialization** | `toJson()` / `fromJson()` on all models |
| **Zero dependencies** | Pure Dart, works offline on every platform |
| **130/130 pub.dev** | Full score: analysis, formatting, tests, docs, platform support |

---

## 📦 Installation

```yaml
dependencies:
  nepal_admin_api: ^2.2.0
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
Wards: ${stats.wards}                   // 6,743
''');

  // ──────────────────────────────────────────────
  // JSON Serialization
  // ──────────────────────────────────────────────
  final json = bharatpur.toJson();
  final restored = LocalBody.fromJson(json);
  assert(restored.cbsCode == bharatpur.cbsCode);
}
```

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
| `getLocalBodyByCbs(code)` | `LocalBody?` | By CBS PDDPP (`31304` = Bharatpur) |
| `getVerifiedLocalBodies()` | `List<LocalBody>` | Only CBS-verified (547/753) |
| `search(query)` | `SearchResult` | Typed search (names, ISO, full paths) |
| `getNationalStats()` | `NationalStats` | Computed national totals |

**Models**: `Province`, `District`, `LocalBody`, `LocalBodyType`, `ProvinceStats`, `NationalStats`, `SearchResult`

**Helpers**: `LocalBody.fullPath` (`'Bharatpur, Chitwan, Bagmati'`), `isUrban` / `isRural`, `LocalBodyListX` (`sortedByName`, `sortedByFullPath`, `whereUrban`, `whereRural`, `whereVerified`, `ofType`)

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
Step 2: CBS code verification via MoFAGA harvest + Postal-2025 (tool/merge/verify_codes.dart)
       │ 547/753 verified (73%)
       ▼
Step 3: Adjudication — 72 conflicts, 72 resolved (tool/merge/adjudicate.dart)
       │ 49 mofaga-exact, 15 mofaga-slug, 8 human
       ▼
Step 4: Schema v2 with CBS codes embedded (tool/merge/apply_cbs_codes.dart)
       │
       ▼
Generated: lib/src/nepal_data.dart (embedded, compile-time)
```

**Sources** (all CC-BY-4.0, attributed in [NOTICE](NOTICE)):
- `abinrimal/nepal-local-levels` — Devanagari names
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

# Regenerate dataset (after data changes)
dart run tool/merge/inventory.dart
dart run tool/merge/match.dart
dart run tool/merge/adjudicate.dart
dart run tool/merge/verify_codes.dart
dart run tool/merge/apply_cbs_codes.dart
dart run tool/generate.dart
```

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