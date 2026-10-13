# Changelog

All notable changes to this package are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/) and the
package adheres to [Semantic Versioning](https://semver.org/).

## 2.3.0 — 2026-10-13

### Added
- Per-palika ward counts: `LocalBody.wards` (int, nullable) +
  `wardsVerified` (bool). Coverage 745/753 (99%) doubly-attested
  (sagautam5 + geo-pro-max agree, incl. documented aliases, fuzzy,
  containment and 1 human decision); 8 remain null (see below).
- `District.wards` (sums verified counts) and
  `LocalBodyListX.whereWardsVerified`.
- `tool/merge/verify_wards.dart` — merge tool with district-scoped
  exact/alias/fuzzy/containment matching, `data/_stage/wards.json`
  (assignments + review), `decisions_wards_manual.json` (Janakpurdham 25).
- Explorer: Wards column + map popups show ward counts.

### Known gaps (roster defects, not guessed)
8 palikas carry no ward count pending roster adjudication (MoFAGA-backed
findings in `data/_stage/wards.json` review): Manang Naraphu/Neshang,
Salyan Dhorchaur, Bajhang Kanda, Udayapur Sunkoshi, Saptari Belhi Chapena,
Nuwakot Meghang, Rasuwa Aamachhodingmo. Lumbini reconciles fully
(109 units, 983 wards); other provinces reconcile modulo their gaps.

## 2.2.0 — 2026-10-12

### Added
- Approximate centroid coordinates: `LocalBody.lat` / `lng` (WGS84,
  nullable) + `geoSource` provenance + `hasCoordinates` getter.
  Coverage 726/753 (96%) from the vendored open-admin-data extract;
  27 remain null (table-only, never fabricated).
- `LocalBodyListX.whereMapped` — only bodies with coordinates.
- `tool/geocode_centroids.dart` — local-first merge with district
  fuzzy-match gate, `data/_stage/geocodes.json` cache, opt-in
  `--geocode-network` Nominatim fallback (1 req/s, custom UA).
- Interactive centroid map in the Data Explorer (Leaflet +
  markercluster over keyless OSM Standard tiles, dark-mode CSS filter).

## 2.1.0 — 2026-10-12

### Added
- Code-first lookups: `getProvinceByIso`, `getProvinceByCbs`,
  `getDistrictByCbs`, `getLocalBodyByCbs`, `getLocalBodiesByProvince`,
  `getLocalBodiesByType`, `getVerifiedLocalBodies`.
- `getProvinceById` now also matches ISO codes (`NP-P3`), so callers can
  use either identifier. `getDistrictsByProvince` /
  `getLocalBodiesByProvince` accept id or ISO.
- `LocalBody.fullPath` (`Name, District, Province`), `isRural`,
  `District.localBodiesByType` / `verifiedLocalBodies`,
  `Province.localBodies` / `localBodyCount`.
- `LocalBodyListX` extension: `sortedByName`, `sortedByFullPath`,
  `whereUrban`, `whereRural`, `whereVerified`, `whereType`.
- `search()` now also matches ISO codes and full paths.

## 2.0.0 — 2026-10-12

### Breaking
- **Schema v2**: All models now include official CBS/NSO codes.
  - `Province` adds `cbsCode` (1–7) and `isoCode` (NP-P1…NP-P7).
  - `District` adds `cbsCode` (3-digit, e.g., 101 for Taplejung, 306 for Kathmandu).
  - `LocalBody` adds `cbsCode` (5-digit PDDPP format) and `cbsCodeVerified` (bool).
  - These fields are non-nullable where the official code is verified (547/753 palikas);
    unverified entries have `cbsCode == null` and `cbsCodeVerified == false`.
- `LocalBody` constructor signature changed: now accepts named parameters
  `cbsCode` and `cbsCodeVerified` (both optional).
- `District` constructor changed: `units` is now `List<LocalBody>` instead of
  `List<(String, LocalBodyType)>`; `cbsCode` is optional.

### Added
- Official CBS codes for 547 palikas (73% verified, doubly-attested by CBS
  local-body CSV and Postal Codes 2025), all 77 districts, and all 7 provinces.
- ISO 3166-2 province codes (NP-P1..NP-P7) matching the federal structure.
- `tool/merge/apply_cbs_codes.dart` to merge staged CBS codes into the dataset.
- `data/nepal_local_levels.json` now includes `cbsCode`/`cbsCodeVerified` at
  all three levels (province, district, local body).

### Changed
- Package version bumped to 2.0.0 per SemVer for breaking schema change.
- `data/nepal_local_levels.json` size increased (~55 KB → ~124 KB) to carry
  the new code fields.
- Generated `lib/src/nepal_data.dart` now embeds CBS codes directly.

### Fixed
- Removed unused `_parsedLocalBodies` cache field from `District`.

## 1.0.0 — 2026-10-09

### Added
- Complete dataset of Nepal's administrative divisions as per the federal
  structure gazetted in 2017 (data as of October 2026): 7 provinces,
  77 districts, 753 local bodies, 6,743 wards.
- `LocalBodyType` enum (metropolitan, sub-metropolitan, municipality,
  rural municipality) with short and full display names.
- `Province`, `District`, `LocalBody`, `ProvinceStats` and `NationalStats` models.
- `NepalAdminApi` query API: province/district/local-body lookups,
  filtered accessors, typed `search()`, and computed national statistics.
- JSON serialization (`toJson`/`fromJson`) on `LocalBody`.
- Golden test suite asserting the official national structure
  (7 / 77 / 753, split 6 / 11 / 276 / 460, 6,743 wards).
