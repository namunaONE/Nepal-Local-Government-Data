# nepal-admin-data

Offline administrative divisions of Nepal for JavaScript — **7 provinces,
77 districts, 753 local bodies, 6,743 wards**, with official CBS codes,
Devanagari names, coordinates and ward counts.

Data as of **2026-10-13**. Generated from
[`data/nepal_local_levels.json`](https://github.com/namunaONE/Nepal-Local-Government-Data)
by `tool/generate_bindings.dart` — do not edit by hand.

- **Zero dependencies.** Pure data plus a small query layer.
- **Bilingual.** Devanagari names for all 7 provinces, 77 districts and
  731 of 753 palikas. Never transliterated.
- **Typed.** `.d.ts` included.
- Same data, same numbers and the same API shape as the Dart package
  [`nepal_admin_api`](https://pub.dev/packages/nepal_admin_api).

## Install

```bash
npm install nepal-admin-data
```

## Use

```js
const nad = require('nepal-admin-data');

// Lookups
nad.getLocalBodyByCbs(31304);
// { name: 'Bharatpur', nameNe: 'भरतपुर', district: 'Chitwan', ... }

nad.getDistrictByName('Chitwan').headquarter;   // 'Bharatpur'
nad.getLocalBodyByFullPath('Bharatpur, Chitwan, Bagmati').name;

// Search works in BOTH scripts, in either direction.
nad.search('Bharatpur').localBodies.length === nad.search('भरतपुर').localBodies.length; // true
nad.search('भारत').localBodies.length;   // fragment match

// Building a code-keyed join (the common case)
const byCode = new Map(nad.getLocalBodiesWithCode().map(b => [b.cbsCode, b]));
byCode.size;   // 744

// National totals
nad.getNationalStats();
// { provinces: 7, districts: 77, total: 753, wards: 6743,
//   verifiedWards: 6697, wardGaps: 8, unreconciledWards: 46, ... }
```

## Two ward totals, on purpose

`wards` is the **declared** national figure (6,743). `verifiedWards` is what
the per-palika rows this package substantiates add up to (6,697). The 46-ward
difference is 8 palikas documented as roster defects — reported, not hidden.

## Data files

Also ships `csv/` for pandas, Excel, R and QGIS, and `geojson/` centroid
FeatureCollections (RFC 7946) for Leaflet, geojson.io and QGIS.

## License

MIT for the code. The data is CC-BY-4.0 / CC-BY derived and attributed in
[NOTICE](NOTICE). Not affiliated with the Government of Nepal.
