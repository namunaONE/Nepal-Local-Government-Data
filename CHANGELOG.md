# Changelog

All notable changes to this package are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/) and the
package adheres to [Semantic Versioning](https://semver.org/).

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
