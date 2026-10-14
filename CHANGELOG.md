# Changelog

All notable changes to this package are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/) and the
package adheres to [Semantic Versioning](https://semver.org/).

## 2.7.1 — 2026-10-14

The integrity audit. Everything here was found by inspecting the repository
rather than by running it — which is the point.

### Fixed
- **The scheduled drift monitor would have blamed upstream every week.**
  `data/_raw/` is gitignored (≈2.5 MB of CC-BY snapshots), so no clean checkout
  — including every CI checkout — contains the 36 pinned files. `verifyProvenance()`
  fails closed when they are absent, and `provenance-watch` turned any failure
  into a *"[provenance] vendored source drift detected"* issue. It had never
  fired only because the job is `schedule`-only and every run so far was a
  push. `auditProvenance()` now returns a typed `ProvenanceReport` and
  `tool/merge/verify_provenance.dart` exits `0` verified / `2` sources absent /
  `1` genuine drift. The job audits the pinning *contract* on every run and
  hash-verifies only when sources are present.
- **The provenance contract was weaker than it looked.** The manifest is now
  rejected if it contains a duplicate pin or a path that escapes `data/_raw`
  (absolute, `..`, or drive-absolute) — otherwise the manifest is a way to name
  an arbitrary file.
- **Four documentation version claims were stale.** `README.md`, `docs/llms.txt`,
  `docs/llms-full.txt` pinned `^2.3.1` against a 2.7.0 package, and the
  schema.org metadata on the published site still declared version `2.5.0`.
  All corrected.
- **Coverage was measured and then ignored.** CI produced an LCOV report that
  nothing acted on. `tool/check_coverage.dart` now enforces an 85% floor —
  applied to hand-written lines only, because `lib/src/nepal_data.dart` is a
  1,396-line generated literal that reports 100% on import and would drag a
  naive total to a flattering ~98%.

### Added
- `test/provenance_test.dart` (16 tests) — the four statuses exercised against
  fixtures, plus the governance invariant that every vendored source directory
  is documented in `SOURCES.md`.
- `test/docs_drift_test.dart` (7 tests) — install snippets, prose version
  claims, schema.org metadata, the CHANGELOG entry and the as-of date must all
  agree with `pubspec.yaml` and the dataset.
- `test/binding_packaging_test.dart` (9 tests) — every file the Python and
  JavaScript bindings open at runtime must exist *and* be covered by their
  packaging declarations. CI tests the source tree, never the artifact, so a
  missing `data.json` in the sdist would otherwise surface only after install.

### Known gap, unchanged
- **The merge is not reproducible from a clean clone.** All eight merge tools
  gate on `verifyProvenance()`, and the payloads are not in the repository. A
  contributor who clones this repo cannot regenerate the dataset from sources.
  Re-fetching from the URLs in `SOURCES.md` and verifying against the manifest
  would close it.

## 2.7.0 — 2026-10-13

The Flutter release, plus a boundary investigation that ended in a refusal to
ship. No change to the Dart public API.

### Added
- **`packages/nepal_admin_widgets`** — a Flutter companion package: a cascading
  Province → District → Local body picker, bilingual and fully offline.
  - `AdministrativeCascade`, a widget-free `ChangeNotifier` holding the state
    transitions and label rules. It is the part worth testing, so it is
    separately testable and reusable behind any UI.
  - `AdministrativeDropdown`, three dependent dropdowns, each disabled until its
    parent is chosen, with a helper line reporting how many options remain.
  - `LocalBodySearchField`, debounced bilingual search scoped to the cascade,
    every result labelled with its district.
  - `LabelStyle` (`english` / `devanagari` / `both`) with single-script
    fallback, so no label ends in a dangling separator for the 22 local bodies
    with no attested Devanagari name.
  - 58 tests (`flutter test`), run against the real dataset rather than
    fixtures, and a runnable `example/`.
  - CI: a `flutter-widgets` job runs `flutter analyze --fatal-infos`,
    `dart format` and `flutter test`. The widget code is a separate package with
    a path dependency, so the root Dart job does not cover it.
- **`tool/merge/probe_boundaries.dart`** — reconciles the vendored boundary
  GeoJSON against the roster and writes nothing.

### Boundaries: investigated, and deliberately still not shipped
`data/_raw/boundaries/oknp_local_levels.geojson` was reconciled properly rather
than assumed unusable. Two earlier suspicions turned out to be wrong:

- The "777 vs 753" over-count is **not** a roster mismatch. 22 of the 777 are
  national parks and wildlife reserves rather than local bodies; the remaining
  755 is a near-exact match, and **705** match our names outright (562 exactly).
  The source does not appear to be a different administrative vintage — this
  probe disproved that suspicion.
- The residual mismatches are mostly **naming style, not structure**: longer
  official names where we use the short form ("Pokhara Lekhnath" vs "Pokhara"),
  and transliteration variants elsewhere.

What remains is a format defect and a verification gap. **4,477 of 4,478 rings
are unclosed**, violating RFC 7946, and 122 are degenerate — both repairable.
The blocker is that nothing in this repository can confirm the boundaries are
*current*: there is no second geometry source to cross-check against and no
gazette. Publishing a polygon layer verified only for shape validity and name
correspondence would be a weaker claim than every other field here, each of
which carries at least two independent attestations — and this project has
already refused to publish a single-source CBS code rather than label it
honestly. `data/SOURCES.md` records what would unblock it.

### Fixed
- **The Python binding was unimportable.** The generator substituted the bare
  token `DATA_AS_OF`, which also rewrote the constant's own name and its entry
  in `__all__`, emitting `2026-10-13 = meta["dataAsOf"]` — a `SyntaxError`, so
  `import nepal_admin` failed outright and `python -m nepal_admin` could not
  run. Found by the `python-bindings` CI job, the first time the binding was
  ever executed anywhere. The value now has its own non-colliding token
  (`DATA_AS_OF_VALUE`).
- **The bindings verifier was enforcing that bug.** Its check asserted the
  token `DATA_AS_OF` was *absent* from the output — so the clobbering looked
  correct, and the suite reported 135/135 green on a module that could not be
  parsed. Replaced with checks on properties of the output rather than on
  substitution: no digit-leading assignments, the public constant is defined
  and exported, every name `__main__` imports actually exists, triple-quoted
  blocks balance. Re-introducing the bug now fails 3 of 141 checks. These are
  static checks, not a substitute for CI importing the module.
- **Both Flutter jobs failed inside `subosito/flutter-action`.** They passed
  `flutter-version: stable` together with `channel: stable`; those are
  mutually exclusive inputs and `flutter-version` wants a semver.
  `flutter-example` had been failing this way since it was added, so Flutter
  had never once installed on these runners.
- The `python-bindings` job now byte-compiles before importing, so a syntax
  error reports as a syntax error rather than as a bare "cannot import name".

### Changed
- `.pubignore` excludes `packages/`, so the Flutter companion is not bundled
  into the published Dart package.

## 2.6.0 — 2026-10-13

The bindings release. Until now the dataset was only reachable from Dart, which
was a real ceiling: most people who want Nepal's administrative structure reach
for pandas, a spreadsheet, or a JavaScript map. Re-typing 753 rows by hand is
exactly what this project exists to stop.

No change to the Dart public API. The package gains a generated sibling tree.

### Added
- **`tool/generate_bindings.dart`** — emits every non-Dart artifact from the
  one dataset, via a single in-memory projection, so the bindings cannot
  drift apart from each other or from the Dart package.
  - **`bindings/csv/`** — `provinces.csv`, `districts.csv`,
    `local_bodies.csv`. RFC 4180 quoting, LF endings, no BOM. For pandas,
    Excel, R, QGIS, or a merge against a voter register.
  - **`bindings/geojson/`** — centroid `FeatureCollection`s (RFC 7946, WGS84,
    `[lng, lat]`) for all three levels. District and province centroids are
    derived as the mean of their members' mapped centroids and are labelled
    approximate in `centroidMethod`.
  - **`bindings/javascript/`** — npm-ready `nepal-admin-data`: `index.js`
    (zero dependencies), `index.d.ts`, `package.json`, plus `LICENSE` and
    `NOTICE`. Mirrors the Dart API.
  - **`bindings/python/`** — PyPI-ready `nepal-admin-data`: pure standard
    library, `python -m nepal_admin` prints a summary.
  - **`bindings/meta.json`** — version, `dataAsOf`, and coverage counters.
- **`bindings/verify_bindings.cjs`** — 135 assertions that *execute* the
  JavaScript, parse the CSV and GeoJSON, and cross-check every artifact
  against `data/nepal_local_levels.json`. Runs in CI.
- **`test/bindings_parity_test.dart`** — reads the shipped artifacts and
  compares them field by field against the live Dart API, including that the
  JS and Python payloads are byte-identical.
- CI: `bindings/` is drift-checked like every other generated artifact; a
  `python-bindings` job runs the Python package for the first time anywhere;
  the Pages deploy stages `csv/`, `geojson/` and `meta.json` into
  `docs/downloads/` so the site is the download surface.
- `.pubignore` excludes `bindings/` — ~1.7 MB of duplicate JSON would
  otherwise ship inside the Dart package for no Dart consumer.

### Fixed
- **A real bug the verifier caught.** The JavaScript
  `getLocalBodiesByName` and `getLocalBodiesByDistrict` read
  `district.localBodies`, which does not exist on the flat district records —
  both silently returned empty arrays. Both now filter the flat list. This is
  the argument for executing generated code rather than only generating it.

### Notes
- The bindings carry the **dataset's** type vocabulary
  (`metropolitan` | `subMetropolitan` | `municipality` | `ruralMunicipality`),
  not `LocalBodyType.shortName` (`M`, `RM`): `M` is meaningless in a CSV
  column, and these artifacts are read by people who never see the Dart enum.
- Output is byte-stable — fixed ordering, LF, UTF-8 without BOM, **no
  timestamps** — so CI drift is a plain `git diff`.

### Not done, and why
- **The Python binding is generated and reviewed but not executed locally.**
  The machine used for this release has no Python interpreter. It is exercised
  for the first time in the `python-bindings` CI job, which asserts the same
  numbers as the Dart and JavaScript artifacts. This is stated in
  `bindings/README.md` rather than papered over.
- **Boundary polygons.** Only centroids ship. The only vendored geometry
  carries 777 features against the gazetted 753 and is quarantined
  (`data/SOURCES.md` § Boundaries). Centroids now means a polygon layer can
  be added later without changing the bindings' contract.
- **A Flutter widgets package.** Deferred: no Flutter SDK is available on this
  machine, and shipping widget code nothing can compile is exactly the rot the
  `flutter-example` CI job exists to prevent.

## 2.5.0 — 2026-10-13

The bilingual release. For a package about Nepal's own government structure,
the Nepali name of a palika is not a nicety — it is what appears on the
building, in the gazette, and on every form a citizen fills in. It was
absent.

### Added
- **Devanagari names at all three levels.** `Province.nameNe`,
  `District.nameNe`, `LocalBody.nameNe`, plus `nameNeVerified` on each.
  Coverage: **7/7 provinces, 77/77 districts, 731/753 palikas**, of which 450
  are corroborated by two independent sources.
  - Nothing is transliterated. The 22 palikas with no attested Devanagari
    name keep `nameNe == null` and are listed in the CHANGELOG and the test
    suite.
  - `nameNeVerified == false` means the two sources spell the same name
    differently *orthographically* — 262 of them differ only in ब/व, ी/ि, the
    candrabindu, or प्प/प. It does **not** mean the name is wrong. Both
    sources agreed on the entity; they disagree on spelling.
- **Bilingual search.** `search()` now matches both scripts in either
  direction, substring-wise, so `search('भरतपुर')` and `search('Bharatpur')`
  return the same palika, and `search('भारत')` matches a fragment.
- `LocalBody.nameNeOrName` (never null) and `LocalBody.displayBoth`
  (`'Bharatpur · भरतपुर'`); the same pair on `District` and `Province`.
  Bilingual tables and pickers become one line, and `displayBoth` degrades to
  a single script rather than rendering a dangling separator.
- **Administrative attributes**, all **single-source** and documented as such
  (`data/SOURCES.md`):
  - `District.headquarter`, `District.areaSqKm`, `District.website` — 77/77
    districts complete.
  - `Province.capital`, `Province.areaSqKm`, `Province.website` — 7/7.
  - `LocalBody.website`, `email`, `phone` — 371/753, with
    `LocalBody.hasContact`. The remaining 382 keep nulls rather than plausible
    values.
  - `LocalBody.zipCodes` — 474/753, sorted and de-duplicated.
- `District.localBodyByName(name)` — one-district scoped lookup that returns a
  single body or null.
- `tool/merge/attach_bilingual.dart`, `tool/merge/attach_attributes.dart`,
  and per-record evidence in `data/_stage/bilingual.json`.

### Fixed
- Kathmandu's Devanagari name carried a trailing Nepali full stop
  ("काठमाडौं ।") from the upstream roster. `cleanDisplayName` now trims edge
  punctuation from every name; internal spaces are preserved, because
  multi-word names are correct. The danda removal also made Kathmandu
  corroborated (449 → 450).
- abinrimal's `code` column has only four distinct values — it is a type code,
  not an identifier. Keying a "already matched" set on it silently dropped 575
  legitimate Devanagari matches; identity now uses `district_code` + name.
- `attach_attributes` no longer keys on the MoFAGA district name: 12 districts
  spell their Devanagari differently there ("स्याङ्जा" vs "स्याञ्जा",
  "रुपन्देही" vs "रूपन्देही"), which silently lost all of their contact
  details. Matching is now by bare palika name with a uniqueness gate.
- Bare Devanagari palika names are **not** unique nationwide (41 collisions in
  the MoFAGA harvest: many rural municipalities share a name across
  districts). 55 palikas are now skipped rather than given a contact block
  that may belong to a different palika.

### Changed
- The pipeline is now 7 steps. Steps 4 (Devanagari) and 5 (attributes) are
  **order-dependent**: MoFAGA rows carry no codes, so attributes join on the
  Devanagari name. Running them out of order would silently attach nothing to
  731 records.
- The Devanagari name matcher rejects anything beyond normalized-name distance
  2. Distance 3-4 was measured and produced confidently WRONG pairings across
  neighbouring palikas — our "Dhorchaur" taking Bagachour's name, "Sulikot"
  taking Ajirkot's, "Kanda" taking Masta's. A wrong name is far worse than an
  absent one, so the threshold is conservative and the refusals are listed.

### Not done, and why
- **Ward-level records (6,743).** Every vendored source was checked: MoFAGA is
  a 750-row palika table, nepali-geo-pro-max has ~757 palika rows,
  sagautam5 carries ward *counts* only, and open-admin-data's `children_count`
  is empty. No source in `data/_raw/` names individual wards, so publishing
  them would mean inventing 6,743 records. This needs a new source (MoFAGA
  ward rosters, ward-level boundaries, or Election Commission data) fetched
  and pinned first — see `data/SOURCES.md` § "Ward-level records".

## 2.4.0 — 2026-10-13

### Added
- **CBS code confidence tiers.** `CbsCodeConfidence` (`verified` /
  `singleSource` / `unverified`) plus `LocalBody.cbsCodeConfidence`. Code
  coverage rises **547 → 744 of 753 (98.8%)** because a code attested by the
  CBS roster alone is no longer discarded — it is published with an honest
  label instead. `cbsCodeVerified` still means exactly what it did
  (doubly-attested), so existing code behaves identically.
  - `verified` (548) — postal-2025 **and** the CBS harvest name the same
    code for the same entity.
  - `singleSource` (196) — exactly one same-district, same-type row of the
    authoritative CBS roster whose normalized name is within Levenshtein
    distance 2, **or** a pairing forced by elimination inside a district
    whose roster matches the CBS roster type-for-type. Assignment is forced
    to be a bijection, so no two palikas can share a code.
  - `unverified` (9) — no defensible code; `cbsCode` stays null. Documented
    ambiguities, never guesses.
- `getLocalBodiesWithCode()`, `getSingleSourceLocalBodies()`,
  `getUncodedLocalBodies()`, `getLocalBodyByCbsVerified()`.
- `LocalBody.hasCbsCode`, `cbsCodeString` (zero-padded 5-digit PDDPP for
  string joins), `districtCbsCodeString`, `isCodeAndCoordinateMapped`.
- `LocalBodyListX.whereCoded`, `whereDoublyAttested`, `whereSingleSource`,
  `whereUncoded`, `whereCodeAndCoordinateMapped`, `totalWards`, `byCbsCode`
  (code-keyed map for joining against government datasets).
- `getLocalBodiesByName(name, district)` — disambiguates the duplicate names
  that make `search()` ambiguous, without scanning the whole country.
- `getLocalBodyByFullPath()` — resolves `'Bharatpur, Chitwan, Bagmati'`,
  order-insensitively, returning null when the path is ambiguous rather than
  silently picking one.
- `District.fromJson`, `Province.fromJson`, `NationalStats.toJson()`, and
  `==`/`hashCode` on all three models. README previously claimed JSON
  serialization "on all models"; it now actually is.
- `tool/merge/resolve_code_tiers.dart` — the tier resolver, with
  district-prefix and bijection gates. `--dry-run` reports without writing.
- `tool/pipeline.dart` — one command (`dart run tool/pipeline.dart`) runs
  every merge and codegen step in order and aborts on the first failure,
  replacing a hand-run sequence in which a forgotten step failed silently.
- CI: `docs/data.json` is now drift-checked (the website could previously
  disagree with the package); a Flutter job compile-checks
  `example/brand_theme.dart` (the one Dart file nothing ever compiled); a
  weekly scheduled provenance watch re-verifies `data/_raw/` against its
  SHA-256 pins and files an issue on upstream drift; coverage reporting added.

### Changed
- `getLocalBodyByCbs()` now resolves the single-source tier too, so it
reaches 744 of 753 instead of 547. Use `getLocalBodyByCbsVerified()` for
the strict doubly-attested reading.
- The merge tools tolerate more of the CBS harvest's own dialect: the
"Metropolitian" typo and, newly, "Municipaity", "Gaun Palika" and
"Gaunpaika". Previously three rows could not be typed at all, which
silently blocked Gulmi Durbar, Kanaka Sundari and Bhirkot.
- Kanaka Sundari (Jumla) is now doubly-attested at 60402, because its CBS
row stopped being unreadable.
- CBS/alignment gate reports on 750/753 rows (was 747).

### Fixed
- **Two ward totals no longer disagree silently.** `NationalStats.wards`
(6,743) is the declared national figure; `NationalStats.verifiedWards`
(6,697) is what the per-palika rows actually sum to. They differ by 46
because 8 palikas carry no verified count. Both are exposed, along with
`wardGaps` and `unreconciledWards`, and `Province` now offers
`declaredWards` / `verifiedWards` / `unreconciledWards` / `wardsReconcile`.
Previously a caller summing `District.wards` got 6,697 from a package whose
national stat said 6,743 with no indication that anything was missing.
- `tool/generate.dart` now fails loudly on a malformed dataset: a tier that
contradicts the verified flag, a duplicate CBS code, or a code outside its
own district is an error rather than something that compiles.
- The boundary GeoJSON/TopoJSON in `data/_raw/boundaries/` were unpinned, so
the provenance gate failed and **the entire merge pipeline could not run**.
Both are now pinned; geometry remains quarantined from the merge (see
`data/SOURCES.md` §5).

## 2.3.1 — 2026-10-13

### Fixed
- Provenance freshness: `meta.dataAsOf` corrected `2026-10-09` →
`2026-10-13` (snapshot verified through the v2.3.0 ward/geo merges).
- New golden test pins `dataAsOf` to never regress below the last
verification date.
- Website: Brand System v2 page (`brand.html`) linked from all navs and
footers; `llms.txt` / `llms-full.txt` cover the dual-seed theme
(navy `#002C6D` × green `#4FD166`) with the `copyWith` gotcha.

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
