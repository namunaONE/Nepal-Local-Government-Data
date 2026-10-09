# nepal_admin_api

Offline, dependency-free administrative divisions of Nepal for Dart and Flutter.

[![pub package](https://img.shields.io/pub/v/nepal_admin_api.svg)](https://pub.dev/packages/nepal_admin_api)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Nepal's federal structure — **7 provinces, 77 districts, 753 local bodies
(6 metropolitan cities, 11 sub-metropolitan cities, 276 municipalities,
460 rural municipalities) and 6,743 wards** — bundled as a pure-Dart package.
No network calls, no assets, no dependencies: the data ships in the box.

## Features

- 🏔️ Full hierarchy: Province → District → Local Body (palika)
- 🔍 Type-safe search across all levels
- 📊 Verified counts (validated against the official national structure)
- 🧊 Zero runtime dependencies — works on every Dart platform
- 🔄 JSON serialization support

## Installation

```yaml
dependencies:
  nepal_admin_api: ^1.0.0
```

## Usage

```dart
import 'package:nepal_admin_api/nepal_admin_api.dart';

void main() {
  // All 7 provinces
  final provinces = NepalAdminApi.getAllProvinces();
  print('Provinces: ${provinces.length}'); // 7

  // One province
  final bagmati = NepalAdminApi.getProvinceById('bagmati');
  print('${bagmati!.name}: ${bagmati.stats.total} local bodies'); // 119

  // Local bodies in a district
  final chitwan = NepalAdminApi.getDistrictByName('Chitwan');
  for (final body in chitwan!.localBodies) {
    print('${body.name} — ${body.typeName}');
  }

  // Typed search across provinces, districts and palikas
  final result = NepalAdminApi.search('Bharatpur');
  for (final body in result.localBodies) {
    print('${body.name} (${body.typeName}) in ${body.districtName}, ${body.provinceName}');
  }

  // National totals, computed live from the dataset
  final stats = NepalAdminApi.getNationalStats();
  print('${stats.total} local bodies, ${stats.wards} wards'); // 753, 6743
}
```

## API overview

| Method | Returns |
|---|---|
| `getAllProvinces()` | All 7 provinces |
| `getProvinceById(id)` | Province by id (`'koshi'`, `'madhesh'`, …) |
| `getAllDistricts()` | All 77 districts |
| `getDistrictsByProvince(id)` | Districts of one province |
| `getDistrictByName(name)` | Single district |
| `getAllLocalBodies()` | All 753 local bodies |
| `getLocalBodiesByDistrict(name)` | Palikas of one district |
| `search(query)` | Typed matches across all levels |
| `getNationalStats()` | Computed national totals |

> ⚠️ **Palika names are not unique** (e.g. there are three `Aurahi`s and four
> `Sunkoshi`s). Always disambiguate with `districtName` / `provinceName`,
> which every `LocalBody` carries.

## Data provenance & disclaimer

The dataset reflects Nepal's gazetted federal structure (753 local levels,
as established by the 2017 restructuring under the 2015 Constitution) with an
"as of" date of **October 2026**. Counts are validated by the package's own
test suite against the official national figures. The dataset lives in
`data/nepal_local_levels.json` (single source of truth) — its schema and
update process are documented in [data/README.md](data/README.md).
Administrative boundaries may change through future government decisions;
check the [releases page](https://github.com/namunaONE/Nepal-Local-Government-Data/releases)
for dataset updates.

This project is not affiliated with the Government of Nepal.

## License

[MIT](LICENSE)
